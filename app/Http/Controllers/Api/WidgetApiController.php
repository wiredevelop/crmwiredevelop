<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\ClientCredentialObject;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\Wallet;
use Illuminate\Http\JsonResponse;

class WidgetApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function summary(): JsonResponse
    {
        return $this->success([
            'role' => $this->isClientUser() ? 'client' : 'admin',
            'stats' => $this->statsSummary(),
            'billing' => $this->billingSummary(),
            'wallets' => $this->walletSummary(),
            'more_modules' => $this->moreModules(),
        ]);
    }

    private function statsSummary(): array
    {
        $activeProjectsQuery = $this->scopeByClient(
            Project::query()
                ->where('is_hidden', false)
                ->whereNotIn('status', ['concluido', 'cancelado'])
        );

        $activeProjects = (clone $activeProjectsQuery)->count();

        if ($this->isClientUser()) {
            return [
                [
                    'id' => 'client_objects',
                    'label' => 'Objetos',
                    'value' => $this->scopeByClient(ClientCredentialObject::query())->count(),
                    'deep_link' => 'wirecrm://objects',
                ],
                [
                    'id' => 'active_projects',
                    'label' => 'Projetos ativos',
                    'value' => $activeProjects,
                    'deep_link' => 'wirecrm://projects',
                ],
                [
                    'id' => 'documents',
                    'label' => 'Documentos',
                    'value' => $this->scopeByClient(Invoice::query())->count(),
                    'deep_link' => 'wirecrm://invoices',
                ],
            ];
        }

        $activeClients = (clone $activeProjectsQuery)
            ->distinct('client_id')
            ->count('client_id');

        return [
            [
                'id' => 'active_clients',
                'label' => 'Clientes ativos',
                'value' => $activeClients,
                'deep_link' => 'wirecrm://clients',
            ],
            [
                'id' => 'active_projects',
                'label' => 'Projetos ativos',
                'value' => $activeProjects,
                'deep_link' => 'wirecrm://projects',
            ],
        ];
    }

    private function billingSummary(): array
    {
        $baseQuery = $this->scopeByClient(Invoice::query());
        $statuses = [
            ['id' => 'paid', 'label' => 'Pago', 'status' => 'pago'],
            ['id' => 'pending', 'label' => 'Pendente', 'status' => 'pendente'],
        ];

        $items = collect($statuses)->map(function (array $status) use ($baseQuery) {
            $countQuery = clone $baseQuery;
            $countQuery->where('status', $status['status']);
            $amountQuery = clone $baseQuery;
            $amountQuery->where('status', $status['status']);

            return [
                'id' => $status['id'],
                'label' => $status['label'],
                'status' => $status['status'],
                'count' => $countQuery->count(),
                'amount' => (float) $amountQuery->sum('total'),
                'deep_link' => 'wirecrm://invoices?status='.$status['status'],
            ];
        })->values();

        $totalsCountQuery = clone $baseQuery;
        $totalsAmountQuery = clone $baseQuery;

        $items->push([
            'id' => 'all',
            'label' => 'Total',
            'status' => 'all',
            'count' => $totalsCountQuery->count(),
            'amount' => (float) $totalsAmountQuery->sum('total'),
            'deep_link' => 'wirecrm://invoices',
        ]);

        return $items->all();
    }

    private function walletSummary(): array
    {
        if ($this->isClientUser()) {
            $wallet = Wallet::firstOrCreate(
                ['client_id' => $this->currentClientId()],
                ['balance_seconds' => 0, 'balance_amount' => 0]
            );
            $wallet->loadMissing('client:id,name,company');

            return [
                'mode' => 'single',
                'items' => [$this->walletItem(
                    clientId: (int) $wallet->client_id,
                    clientName: $wallet->client?->name ?? 'Cliente',
                    company: $wallet->client?->company,
                    balanceSeconds: (int) $wallet->balance_seconds,
                    balanceAmount: (float) $wallet->balance_amount,
                    deepLink: 'wirecrm://wallet',
                )],
            ];
        }

        $clients = Client::query()
            ->leftJoin('wallets', 'wallets.client_id', '=', 'clients.id')
            ->orderBy('clients.name')
            ->get([
                'clients.id',
                'clients.name',
                'clients.company',
                'wallets.balance_seconds',
                'wallets.balance_amount',
            ]);

        return [
            'mode' => 'collection',
            'items' => $clients->map(fn ($client) => $this->walletItem(
                clientId: (int) $client->id,
                clientName: (string) $client->name,
                company: $client->company ? (string) $client->company : null,
                balanceSeconds: (int) ($client->balance_seconds ?? 0),
                balanceAmount: (float) ($client->balance_amount ?? 0),
                deepLink: 'wirecrm://wallets?client_id='.$client->id,
            ))->values()->all(),
        ];
    }

    private function moreModules(): array
    {
        $modules = $this->isClientUser()
            ? [
                ['id' => 'wallet', 'label' => 'Carteira'],
                ['id' => 'security', 'label' => 'Segurança'],
                ['id' => 'documents', 'label' => 'Documentos'],
            ]
            : [
                ['id' => 'quotes', 'label' => 'Orçamentos'],
                ['id' => 'products', 'label' => 'Produtos / Packs'],
                ['id' => 'documents', 'label' => 'Documentos'],
                ['id' => 'finance', 'label' => 'Financeiro'],
                ['id' => 'terminal', 'label' => 'Terminal'],
                ['id' => 'interventions', 'label' => 'Intervenções'],
                ['id' => 'wallets', 'label' => 'Carteiras'],
                ['id' => 'company', 'label' => 'Empresa'],
                ['id' => 'settings', 'label' => 'Definições'],
                ['id' => 'security', 'label' => 'Segurança'],
            ];

        return collect($modules)->map(fn (array $module) => [
            ...$module,
            'deep_link' => 'wirecrm://more?module='.$module['id'],
        ])->values()->all();
    }

    private function walletItem(
        int $clientId,
        string $clientName,
        ?string $company,
        int $balanceSeconds,
        float $balanceAmount,
        string $deepLink,
    ): array {
        return [
            'client_id' => $clientId,
            'client_name' => $clientName,
            'company' => $company,
            'balance_seconds' => $balanceSeconds,
            'balance_amount' => $balanceAmount,
            'deep_link' => $deepLink,
        ];
    }
}
