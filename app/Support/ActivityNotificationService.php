<?php

namespace App\Support;

use App\Models\Client;
use App\Models\Installment;
use App\Models\Intervention;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Project;
use App\Models\ProjectMessage;
use App\Models\Quote;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class ActivityNotificationService
{
    public function __construct(private readonly PushNotificationService $push)
    {
    }

    public function notifyClientCreated(Client $client): void
    {
        $this->notifyClientStakeholders(
            $client->id,
            'Novo cliente',
            sprintf('Foi criado o cliente %s.', $client->name),
            $this->clientsLink(),
        );
    }

    public function notifyClientUpdated(Client $client): void
    {
        $body = $client->wasChanged('internal_notes')
            ? sprintf('Foi adicionada uma nota ao cliente %s.', $client->name)
            : sprintf('Os dados do cliente %s foram atualizados.', $client->name);

        $this->notifyClientStakeholders(
            $client->id,
            'Cliente atualizado',
            $body,
            $this->clientsLink(),
        );
    }

    public function notifyClientDeleted(Client $client): void
    {
        $this->notifyAdmins(
            'Cliente removido',
            sprintf('O cliente %s foi removido.', $client->name),
            $this->clientsLink(),
        );
    }

    public function notifyProjectCreated(Project $project): void
    {
        $this->notifyClientStakeholders(
            $project->client_id,
            'Novo projeto',
            sprintf('Foi criado o projeto %s.', $project->name),
            $this->projectsLink(),
        );
    }

    public function notifyProjectUpdated(Project $project): void
    {
        $changes = array_diff(array_keys($project->getChanges()), ['updated_at', 'quote_id']);
        if ($changes === []) {
            return;
        }

        $body = $project->wasChanged('status')
            ? sprintf('O projeto %s mudou para %s.', $project->name, $this->statusLabel($project->status))
            : sprintf('O projeto %s foi atualizado.', $project->name);

        $this->notifyClientStakeholders(
            $project->client_id,
            'Projeto atualizado',
            $body,
            $this->projectsLink(),
        );
    }

    public function notifyProjectDeleted(Project $project): void
    {
        $this->notifyClientStakeholders(
            $project->client_id,
            'Projeto removido',
            sprintf('O projeto %s foi removido.', $project->name),
            $this->projectsLink(),
        );
    }

    public function notifyProjectMessageCreated(ProjectMessage $message): void
    {
        $message->loadMissing('project.client');

        [$title, $body] = match ($message->type) {
            'proof_request' => ['Pedido de prova', Str::limit($message->body ?: 'Foi solicitado um comprovativo do projeto.', 120)],
            'proof_submission' => ['Nova prova submetida', Str::limit($message->body ?: 'Foi submetida uma prova no projeto.', 120)],
            'status_update' => ['Atualização de estado', Str::limit($message->body ?: 'O estado do projeto foi atualizado.', 120)],
            default => ['Nova mensagem do projeto', Str::limit($message->body ?: 'Foi enviada uma nova mensagem no projeto.', 120)],
        };

        $this->notifyClientStakeholders(
            $message->project?->client_id,
            $title,
            $body,
            $this->projectsLink(),
        );
    }

    public function notifyQuoteCreated(Quote $quote): void
    {
        $quote->loadMissing('project');
        $this->notifyClientStakeholders(
            $quote->project?->client_id,
            'Novo orçamento',
            sprintf('Foi criado um orçamento para o projeto %s.', $quote->project?->name ?? '—'),
            $this->projectsLink(),
        );
    }

    public function notifyQuoteUpdated(Quote $quote): void
    {
        $quote->loadMissing('project');
        $body = $quote->wasChanged('adjudication_percent') || $quote->wasChanged('adjudication_paid_at')
            ? sprintf('A adjudicação do projeto %s foi atualizada.', $quote->project?->name ?? '—')
            : sprintf('O orçamento do projeto %s foi atualizado.', $quote->project?->name ?? '—');

        $this->notifyClientStakeholders(
            $quote->project?->client_id,
            'Orçamento atualizado',
            $body,
            $this->projectsLink(),
        );
    }

    public function notifyInvoiceCreated(Invoice $invoice): void
    {
        $this->notifyClientStakeholders(
            $invoice->client_id,
            'Nova fatura',
            sprintf('Foi criada a fatura %s.', $invoice->number ?? 'sem número'),
            $this->invoicesLink($invoice->status),
        );
    }

    public function notifyInvoiceUpdated(Invoice $invoice): void
    {
        $body = match (true) {
            $invoice->wasChanged('status') && $invoice->status === 'pago' => sprintf('A fatura %s foi marcada como paga.', $invoice->number ?? 'sem número'),
            $invoice->wasChanged('status') && $invoice->status === 'pendente' => sprintf('A fatura %s ficou pendente.', $invoice->number ?? 'sem número'),
            default => sprintf('A fatura %s foi atualizada.', $invoice->number ?? 'sem número'),
        };

        $this->notifyClientStakeholders(
            $invoice->client_id,
            'Fatura atualizada',
            $body,
            $this->invoicesLink($invoice->status),
        );
    }

    public function notifyInvoiceDeleted(Invoice $invoice): void
    {
        $this->notifyClientStakeholders(
            $invoice->client_id,
            'Fatura removida',
            sprintf('A fatura %s foi removida.', $invoice->number ?? 'sem número'),
            $this->invoicesLink('pendente'),
        );
    }

    public function notifyInstallmentCreated(Installment $installment): void
    {
        $installment->loadMissing('project');

        $this->notifyClientStakeholders(
            $installment->client_id,
            'Parcela registada',
            sprintf('Foi registada uma parcela no projeto %s.', $installment->project?->name ?? '—'),
            $this->invoicesLink('pendente'),
        );
    }

    public function notifyInstallmentUpdated(Installment $installment): void
    {
        $installment->loadMissing('project');

        $this->notifyClientStakeholders(
            $installment->client_id,
            'Parcela atualizada',
            sprintf('Foi atualizada uma parcela no projeto %s.', $installment->project?->name ?? '—'),
            $this->invoicesLink('pendente'),
        );
    }

    public function notifyInstallmentDeleted(Installment $installment): void
    {
        $installment->loadMissing('project');

        $this->notifyClientStakeholders(
            $installment->client_id,
            'Parcela removida',
            sprintf('Foi removida uma parcela do projeto %s.', $installment->project?->name ?? '—'),
            $this->invoicesLink('pendente'),
        );
    }

    public function notifyWalletTransactionCreated(WalletTransaction $transaction): void
    {
        $transaction->loadMissing('wallet.client');

        $this->notifyClientStakeholders(
            $transaction->wallet?->client_id,
            'Movimento de carteira',
            sprintf('Foi registado um novo movimento para %s.', $transaction->wallet?->client?->name ?? 'o cliente'),
            $this->walletLink($transaction->wallet?->client_id),
        );
    }

    public function notifyWalletTransactionUpdated(WalletTransaction $transaction): void
    {
        $transaction->loadMissing('wallet.client');

        $this->notifyClientStakeholders(
            $transaction->wallet?->client_id,
            'Carteira atualizada',
            sprintf('Foi atualizado um movimento da carteira de %s.', $transaction->wallet?->client?->name ?? 'o cliente'),
            $this->walletLink($transaction->wallet?->client_id),
        );
    }

    public function notifyWalletTransactionDeleted(WalletTransaction $transaction): void
    {
        $transaction->loadMissing('wallet.client');

        $this->notifyClientStakeholders(
            $transaction->wallet?->client_id,
            'Movimento removido',
            sprintf('Foi removido um movimento da carteira de %s.', $transaction->wallet?->client?->name ?? 'o cliente'),
            $this->walletLink($transaction->wallet?->client_id),
        );
    }

    public function notifyInterventionCreated(Intervention $intervention): void
    {
        $intervention->loadMissing('client');

        $this->notifyClientStakeholders(
            $intervention->client_id,
            'Nova intervenção',
            sprintf('Foi iniciada uma intervenção %s para %s.', $intervention->type, $intervention->client?->name ?? 'o cliente'),
            $this->walletLink($intervention->client_id),
        );
    }

    public function notifyInterventionUpdated(Intervention $intervention): void
    {
        $intervention->loadMissing('client');

        $body = match ($intervention->status) {
            'paused' => sprintf('A intervenção %s ficou em pausa.', $intervention->type),
            'running' => sprintf('A intervenção %s foi retomada.', $intervention->type),
            'completed' => sprintf('A intervenção %s foi concluída.', $intervention->type),
            default => sprintf('A intervenção %s foi atualizada.', $intervention->type),
        };

        $this->notifyClientStakeholders(
            $intervention->client_id,
            'Intervenção atualizada',
            $body,
            $this->walletLink($intervention->client_id),
        );
    }

    public function notifyProductCreated(Product $product): void
    {
        $this->notifyAdmins(
            'Novo produto',
            sprintf('Foi criado o produto %s.', $product->name),
            $this->moreModuleLink('products'),
        );
    }

    public function notifyProductUpdated(Product $product): void
    {
        $this->notifyAdmins(
            'Produto atualizado',
            sprintf('O produto %s foi atualizado.', $product->name),
            $this->moreModuleLink('products'),
        );
    }

    public function notifyProductDeleted(Product $product): void
    {
        $this->notifyAdmins(
            'Produto removido',
            sprintf('O produto %s foi removido.', $product->name),
            $this->moreModuleLink('products'),
        );
    }

    public function notifyAdminConfigurationChanged(string $title, string $body, string $module = 'settings'): void
    {
        $this->notifyAdmins($title, $body, $this->moreModuleLink($module));
    }

    public function notifyPendingInvoiceReminder(int $clientId, string $clientName, int $count, float $total): void
    {
        $cacheKey = sprintf('notifications:pending-invoices:%d', $clientId);
        if (Cache::has($cacheKey)) {
            return;
        }

        Cache::put($cacheKey, now()->toIso8601String(), now()->addDays(3));

        $title = 'Lembrete de pendentes';
        $body = sprintf(
            '%s tem %d documento(s) pendente(s), no total de %s €.',
            $clientName,
            $count,
            number_format($total, 2, ',', '.'),
        );

        $this->notifyClientStakeholders(
            $clientId,
            $title,
            $body,
            $this->invoicesLink('pendente'),
            false,
        );
    }

    private function notifyClientStakeholders(
        ?int $clientId,
        string $title,
        string $body,
        string $deepLink,
        bool $excludeActor = true,
    ): void {
        $users = $this->push->usersForClientStakeholders(
            $clientId,
            $excludeActor ? $this->actorId() : null,
        );

        $this->push->sendToUsers($users, $title, $body, [
            'deep_link' => $deepLink,
            'title' => $title,
            'body' => $body,
        ]);
    }

    private function notifyAdmins(
        string $title,
        string $body,
        string $deepLink,
        bool $excludeActor = true,
    ): void {
        $users = $this->push->usersForAdmins($excludeActor ? $this->actorId() : null);

        $this->push->sendToUsers($users, $title, $body, [
            'deep_link' => $deepLink,
            'title' => $title,
            'body' => $body,
        ]);
    }

    private function actorId(): ?int
    {
        return Auth::id() ?: request()?->user()?->id;
    }

    private function clientsLink(): string
    {
        return 'wirecrm://clients';
    }

    private function projectsLink(): string
    {
        return 'wirecrm://projects';
    }

    private function invoicesLink(?string $status = null): string
    {
        if (! $status) {
            return 'wirecrm://invoices';
        }

        return 'wirecrm://invoices?status='.urlencode($status);
    }

    private function walletLink(?int $clientId): string
    {
        if (! $clientId) {
            return 'wirecrm://wallet';
        }

        return 'wirecrm://wallets?client_id='.$clientId;
    }

    private function moreModuleLink(string $module): string
    {
        return 'wirecrm://more?module='.$module;
    }

    private function statusLabel(?string $status): string
    {
        return match ($status) {
            'pendente' => 'Pendente',
            'em_execucao' => 'Em execução',
            'concluido' => 'Concluído',
            'cancelado' => 'Cancelado',
            default => $status ?: 'Estado atualizado',
        };
    }
}
