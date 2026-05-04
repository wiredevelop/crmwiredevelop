<?php

namespace App\Services;

use App\Models\Client;
use App\Models\Intervention;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\Wallet;
use Illuminate\Support\Facades\Http;

class SparkyService
{
    public function ask(string $question, array $history = []): string
    {
        $context = $this->buildContext();
        $systemPrompt = $this->buildSystemPrompt($context);

        $messages = [];

        foreach ($history as $entry) {
            $messages[] = ['role' => $entry['role'], 'content' => $entry['content']];
        }

        $messages[] = ['role' => 'user', 'content' => $question];

        $response = Http::withHeaders([
            'x-api-key' => config('services.anthropic.key'),
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ])->post('https://api.anthropic.com/v1/messages', [
            'model' => 'claude-haiku-4-5-20251001',
            'max_tokens' => 1024,
            'system' => $systemPrompt,
            'messages' => $messages,
        ]);

        if ($response->failed()) {
            throw new \RuntimeException('Erro ao contactar a API do Sparky: ' . $response->body());
        }

        return $response->json('content.0.text', 'Não consegui obter uma resposta.');
    }

    private function buildContext(): array
    {
        $clients = Client::select('id', 'name', 'company', 'email')->orderBy('name')->get();

        $invoices = Invoice::with('client:id,name,company')
            ->select('id', 'client_id', 'number', 'total', 'status', 'due_at', 'paid_at', 'issued_at')
            ->orderByDesc('issued_at')
            ->limit(300)
            ->get()
            ->map(fn($i) => [
                'numero' => $i->number,
                'cliente' => $i->client?->name ?? '—',
                'total' => number_format($i->total, 2, ',', '.') . '€',
                'estado' => $i->status,
                'vencimento' => $i->due_at?->format('d/m/Y'),
                'pago_em' => $i->paid_at?->format('d/m/Y'),
            ]);

        $projects = Project::with(['client:id,name', 'quote', 'installments'])
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
                    'orcamento' => $baseAmount > 0 ? number_format($baseAmount, 2, ',', '.') . '€' : '—',
                    'parcelas_pagas' => number_format($installmentsTotal + $adjValue, 2, ',', '.') . '€',
                    'valor_em_falta' => $remaining !== null ? number_format($remaining, 2, ',', '.') . '€' : '—',
                ];
            });

        $wallets = Wallet::with('client:id,name')
            ->select('id', 'client_id', 'balance_amount', 'balance_seconds')
            ->get()
            ->map(fn($w) => [
                'cliente' => $w->client?->name ?? '—',
                'saldo_euros' => number_format($w->balance_amount, 2, ',', '.') . '€',
                'saldo_horas' => gmdate('H:i', max(0, $w->balance_seconds)),
            ]);

        $interventions = Intervention::with('client:id,name')
            ->select('id', 'client_id', 'type', 'status', 'total_seconds', 'started_at', 'ended_at')
            ->whereIn('status', ['pending', 'in_progress', 'open'])
            ->orderByDesc('started_at')
            ->limit(100)
            ->get()
            ->map(fn($i) => [
                'cliente' => $i->client?->name ?? '—',
                'tipo' => $i->type,
                'estado' => $i->status,
                'horas' => $i->total_seconds ? gmdate('H:i', $i->total_seconds) : '—',
                'inicio' => $i->started_at?->format('d/m/Y'),
            ]);

        return compact('clients', 'invoices', 'projects', 'wallets', 'interventions');
    }

    private function buildSystemPrompt(array $context): string
    {
        $clientList = $context['clients']->map(fn($c) => "- {$c->name}" . ($c->company ? " ({$c->company})" : '') . ($c->email ? " <{$c->email}>" : ''))->join("\n");

        $invoiceList = collect($context['invoices'])->map(fn($i) =>
            "- Fatura {$i['numero']} | {$i['cliente']} | {$i['total']} | Estado: {$i['estado']} | Vencimento: {$i['vencimento']}"
        )->join("\n");

        $projectList = collect($context['projects'])->map(fn($p) =>
            "- {$p['nome']} | {$p['cliente']} | Tipo: {$p['tipo']} | Estado: {$p['estado']} | Orçamento: {$p['orcamento']} | Já pago: {$p['parcelas_pagas']} | Valor em falta: {$p['valor_em_falta']}"
        )->join("\n");

        $walletList = collect($context['wallets'])->map(fn($w) =>
            "- {$w['cliente']} | Saldo: {$w['saldo_euros']} | Horas: {$w['saldo_horas']}"
        )->join("\n");

        $interventionList = collect($context['interventions'])->map(fn($i) =>
            "- {$i['cliente']} | {$i['tipo']} | Estado: {$i['estado']} | Horas: {$i['horas']}"
        )->join("\n");

        $today = now()->format('d/m/Y');

        return <<<PROMPT
        És o Sparky, o assistente de IA do WireDevelop CRM. Respondes sempre em português europeu.
        És direto, inteligente e útil. Quando te fazem perguntas sobre dados do CRM, respondes com base nos dados abaixo.

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
