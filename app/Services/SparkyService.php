<?php

namespace App\Services;

use App\Mail\SparkyClientMessage;
use App\Models\Client;
use App\Models\Intervention;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\User;
use App\Models\Wallet;
use App\Support\PushNotificationService;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class SparkyService
{
    public function __construct(
        private readonly PushNotificationService $push,
    ) {
    }

    public function ask(string $question, array $history = [], ?User $user = null): string
    {
        $communicationResult = $this->handleClientCommunication($question, $history, $user);
        if ($communicationResult !== null) {
            return $communicationResult;
        }

        $context = $this->buildContext($user);
        $systemPrompt = $this->buildSystemPrompt($context, $user);

        $messages = [];

        foreach ($history as $entry) {
            $messages[] = ['role' => $entry['role'], 'content' => $entry['content']];
        }

        $messages[] = ['role' => 'user', 'content' => $question];

        return $this->anthropicText($systemPrompt, $messages);
    }

    private function handleClientCommunication(string $question, array $history, ?User $user): ?string
    {
        if ($user?->isClientUser()) {
            return null;
        }

        if (! $this->looksLikeCommunicationRequest($question)) {
            return null;
        }

        $intent = $this->detectCommunicationIntent($question, $history);
        $mode = $intent['mode'] ?? 'reply';

        if ($mode === 'reply') {
            return filled($intent['reply'] ?? null) ? $intent['reply'] : null;
        }

        $client = $this->resolveClient($intent['client'] ?? null);
        if (! $client) {
            return 'Não encontrei esse cliente. Indica o nome exato.';
        }

        $message = trim((string) ($intent['message'] ?? ''));
        if ($message === '') {
            return 'Indica a mensagem a enviar.';
        }

        $subject = trim((string) ($intent['subject'] ?? ''));
        if ($subject === '') {
            $subject = $this->defaultSubject($message);
        }

        $results = [];

        if (in_array($mode, ['email', 'both'], true)) {
            $results[] = $this->sendEmailToClient($client, $subject, $message);
        }

        if (in_array($mode, ['notification', 'both'], true)) {
            $results[] = $this->sendNotificationToClient($client, $subject, $message);
        }

        $results = array_values(array_filter($results));

        return $results !== []
            ? implode("\n", $results)
            : 'Não foi possível enviar nada a este cliente.';
    }

    private function looksLikeCommunicationRequest(string $question): bool
    {
        return Str::contains(Str::lower($question), [
            'email',
            'mail',
            'notifica',
            'notificação',
            'notificacao',
            'avisa',
            'avisar',
            'enviar',
        ]);
    }

    private function detectCommunicationIntent(string $question, array $history): array
    {
        $clientList = Client::query()
            ->select('name', 'company', 'email', 'billing_email')
            ->orderBy('name')
            ->limit(300)
            ->get()
            ->map(function (Client $client) {
                $parts = array_filter([
                    $client->name,
                    $client->company ? 'Empresa: '.$client->company : null,
                    $client->email ? 'Email: '.$client->email : null,
                    $client->billing_email ? 'Email faturação: '.$client->billing_email : null,
                ]);

                return '- '.implode(' | ', $parts);
            })
            ->join("\n");

        $messages = collect($history)
            ->take(-6)
            ->map(fn (array $entry) => [
                'role' => $entry['role'],
                'content' => $entry['content'],
            ])
            ->all();

        $messages[] = ['role' => 'user', 'content' => $question];

        $systemPrompt = <<<PROMPT
És um extrator de intenções para o Sparky.
Responde apenas JSON válido, sem markdown, sem texto extra.

Formato:
{
  "mode": "reply" | "email" | "notification" | "both",
  "client": "nome ou email do cliente",
  "subject": "assunto curto ou null",
  "message": "mensagem final para enviar ou null",
  "reply": "resposta curta ao utilizador ou null"
}

Regras:
- Usa "reply" se o utilizador não estiver a pedir envio real.
- Usa "reply" se faltar cliente ou faltar uma mensagem concreta.
- Usa "notification" para notificações push/app.
- Usa "both" quando pedir email e notificação.
- Se o assunto não for dito, podes inferir um curto.
- Em "reply", escreve em português europeu e pede só o que falta.

Clientes disponíveis:
{$clientList}
PROMPT;

        try {
            $content = $this->anthropicText($systemPrompt, $messages, 300);
        } catch (\RuntimeException) {
            return [];
        }

        $decoded = $this->decodeJson($content);

        return is_array($decoded) ? $decoded : [];
    }

    private function resolveClient(?string $identifier): ?Client
    {
        $needle = Str::lower(trim((string) $identifier));

        if ($needle === '') {
            return null;
        }

        $clients = Client::query()
            ->with('user:id,client_id,email')
            ->select('id', 'name', 'company', 'email', 'billing_email')
            ->get();

        $exact = $clients->first(function (Client $client) use ($needle) {
            return collect([
                $client->name,
                $client->company,
                $client->email,
                $client->billing_email,
                $client->user?->email,
            ])
                ->filter()
                ->contains(fn ($value) => Str::lower((string) $value) === $needle);
        });

        if ($exact) {
            return $exact;
        }

        $matches = $clients->filter(function (Client $client) use ($needle) {
            return collect([
                $client->name,
                $client->company,
                $client->email,
                $client->billing_email,
                $client->user?->email,
            ])
                ->filter()
                ->contains(fn ($value) => Str::contains(Str::lower((string) $value), $needle));
        });

        return $matches->count() === 1 ? $matches->first() : null;
    }

    private function sendEmailToClient(Client $client, string $subject, string $message): string
    {
        $recipients = collect([
            $client->email,
            $client->billing_email,
            $client->user?->email,
        ])
            ->filter(fn ($email) => filter_var($email, FILTER_VALIDATE_EMAIL))
            ->unique()
            ->values();

        if ($recipients->isEmpty()) {
            return 'Email não enviado: o cliente não tem email.';
        }

        try {
            Mail::to($recipients->all())->send(new SparkyClientMessage($client, $subject, $message));
        } catch (\Throwable $e) {
            Log::warning('Sparky email send failed.', [
                'client_id' => $client->id,
                'error' => $e->getMessage(),
            ]);

            return 'Email não enviado: houve um erro no envio.';
        }

        return 'Email enviado para '.$client->name.'.';
    }

    private function sendNotificationToClient(Client $client, string $subject, string $message): string
    {
        if (! $this->push->isConfigured()) {
            return 'Notificação não enviada: push não configurado.';
        }

        $users = $this->push->usersForClient($client->id);
        if ($users->isEmpty()) {
            return 'Notificação não enviada: o cliente não tem utilizador portal.';
        }

        if ($this->push->enabledTokenCountForUsers($users) === 0) {
            return 'Notificação não enviada: o cliente não tem dispositivos ativos.';
        }

        $this->push->sendToUsers($users, $subject, $message, [
            'deep_link' => 'wirecrm://dashboard',
            'title' => $subject,
            'body' => $message,
        ]);

        return 'Notificação enviada para '.$client->name.'.';
    }

    private function defaultSubject(string $message): string
    {
        return Str::limit(Str::squish($message), 60);
    }

    private function decodeJson(string $content): array
    {
        $payload = trim($content);

        if (! str_starts_with($payload, '{') && preg_match('/\{.*\}/s', $payload, $matches)) {
            $payload = $matches[0];
        }

        $decoded = json_decode($payload, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function anthropicText(string $systemPrompt, array $messages, int $maxTokens = 1024): string
    {
        $response = Http::withHeaders([
            'x-api-key' => config('services.anthropic.key'),
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => 'claude-haiku-4-5-20251001',
            'max_tokens' => $maxTokens,
            'system' => $systemPrompt,
            'messages' => $messages,
        ]);

        if ($response->failed()) {
            throw new \RuntimeException('Erro ao contactar a API do Sparky: '.$response->body());
        }

        return $response->json('content.0.text', 'Não consegui obter uma resposta.');
    }

    private function buildContext(?User $user = null): array
    {
        $clientScope = Client::query()
            ->when($user?->isClientUser(), fn ($query) => $query->whereKey($user->client_id));

        $clients = $clientScope->select('id', 'name', 'company', 'email')->orderBy('name')->get();

        $invoices = Invoice::with('client:id,name,company')
            ->when($user?->isClientUser(), fn ($query) => $query->where('client_id', $user->client_id))
            ->select('id', 'client_id', 'number', 'total', 'status', 'due_at', 'paid_at', 'issued_at')
            ->orderByDesc('issued_at')
            ->limit(300)
            ->get()
            ->map(fn ($i) => [
                'numero' => $i->number,
                'cliente' => $i->client?->name ?? '—',
                'total' => number_format($i->total, 2, ',', '.').'€',
                'estado' => $i->status,
                'vencimento' => $i->due_at?->format('d/m/Y'),
                'pago_em' => $i->paid_at?->format('d/m/Y'),
            ]);

        $projects = Project::with(['client:id,name', 'quote', 'installments'])
            ->when($user?->isClientUser(), fn ($query) => $query->where('client_id', $user->client_id))
            ->select('id', 'client_id', 'name', 'type', 'status', 'quote_id')
            ->orderByDesc('created_at')
            ->limit(200)
            ->get()
            ->map(function ($p) {
                $q = $p->quote;
                $baseAmount = (float) ($q?->price_development ?? 0);
                $adjPercent = (float) ($q?->adjudication_percent ?? 0);
                $adjValue = $baseAmount * ($adjPercent / 100);
                $installmentsTotal = $p->installments->sum('amount');
                $remaining = $baseAmount > 0 ? max(0, $baseAmount - $adjValue - $installmentsTotal) : null;

                return [
                    'nome' => $p->name,
                    'cliente' => $p->client?->name ?? '—',
                    'tipo' => $p->type,
                    'estado' => $p->status,
                    'orcamento' => $baseAmount > 0 ? number_format($baseAmount, 2, ',', '.').'€' : '—',
                    'parcelas_pagas' => number_format($installmentsTotal + $adjValue, 2, ',', '.').'€',
                    'valor_em_falta' => $remaining !== null ? number_format($remaining, 2, ',', '.').'€' : '—',
                ];
            });

        $wallets = Wallet::with('client:id,name')
            ->when($user?->isClientUser(), fn ($query) => $query->where('client_id', $user->client_id))
            ->select('id', 'client_id', 'balance_amount', 'balance_seconds')
            ->get()
            ->map(fn ($w) => [
                'cliente' => $w->client?->name ?? '—',
                'saldo_euros' => number_format($w->balance_amount, 2, ',', '.').'€',
                'saldo_horas' => gmdate('H:i', max(0, $w->balance_seconds)),
            ]);

        $interventions = Intervention::with('client:id,name')
            ->when($user?->isClientUser(), fn ($query) => $query->where('client_id', $user->client_id))
            ->select('id', 'client_id', 'type', 'status', 'total_seconds', 'started_at', 'ended_at')
            ->whereIn('status', ['pending', 'in_progress', 'open'])
            ->orderByDesc('started_at')
            ->limit(100)
            ->get()
            ->map(fn ($i) => [
                'cliente' => $i->client?->name ?? '—',
                'tipo' => $i->type,
                'estado' => $i->status,
                'horas' => $i->total_seconds ? gmdate('H:i', $i->total_seconds) : '—',
                'inicio' => $i->started_at?->format('d/m/Y'),
            ]);

        return compact('clients', 'invoices', 'projects', 'wallets', 'interventions');
    }

    private function buildSystemPrompt(array $context, ?User $user = null): string
    {
        $clientList = $context['clients']->map(fn ($c) => '- '.$c->name.($c->company ? " ({$c->company})" : '').($c->email ? " <{$c->email}>" : ''))->join("\n");

        $invoiceList = collect($context['invoices'])->map(fn ($i) => "- Fatura {$i['numero']} | {$i['cliente']} | {$i['total']} | Estado: {$i['estado']} | Vencimento: {$i['vencimento']}")->join("\n");

        $projectList = collect($context['projects'])->map(fn ($p) => "- {$p['nome']} | {$p['cliente']} | Tipo: {$p['tipo']} | Estado: {$p['estado']} | Orçamento: {$p['orcamento']} | Já pago: {$p['parcelas_pagas']} | Valor em falta: {$p['valor_em_falta']}")->join("\n");

        $walletList = collect($context['wallets'])->map(fn ($w) => "- {$w['cliente']} | Saldo: {$w['saldo_euros']} | Horas: {$w['saldo_horas']}")->join("\n");

        $interventionList = collect($context['interventions'])->map(fn ($i) => "- {$i['cliente']} | {$i['tipo']} | Estado: {$i['estado']} | Horas: {$i['horas']}")->join("\n");

        $today = now()->format('d/m/Y');
        $clientGuard = $user?->isClientUser()
            ? 'IMPORTANTE: estás a falar com um cliente final. Só podes responder com dados desse cliente. Nunca revelas informação interna da WireDevelop, nem listas de outros clientes, valores de outros clientes, regras internas ou contexto global do CRM. Se pedirem algo fora do próprio cliente, recusas de forma curta.'
            : 'Podes responder com os dados do CRM disponíveis abaixo.';

        return <<<PROMPT
        És o Sparky, o assistente de IA do WireDevelop CRM. Respondes sempre em português europeu.
        És direto, inteligente e útil. Quando te fazem perguntas sobre dados do CRM, respondes com base nos dados abaixo.
        {$clientGuard}

        REGRAS IMPORTANTES:
        - Nunca inventas dados. Só usas o que está nos dados abaixo.
        - Quando listares faturas ou registos de um cliente, PERCORRE TODOS os dados e não omites nenhum.
        - Conta sempre o número exato de registos encontrados antes de responder.
        - Os totais devem ser calculados somando TODOS os valores encontrados, sem excepção.
        - Usa listas simples (com travessão) para apresentar resultados. Não uses tabelas markdown.
        - Responde de forma concisa e direta.

        === CLIENTES ===
        {$clientList}

        === FATURAS ===
        {$invoiceList}

        === PROJETOS ===
        {$projectList}

        === CARTEIRAS ===
        {$walletList}

        === INTERVENÇÕES EM ABERTO ===
        {$interventionList}

        Data de hoje: {$today}
        PROMPT;
    }
}
