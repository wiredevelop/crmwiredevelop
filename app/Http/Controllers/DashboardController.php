<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Client;
use App\Models\Installment;
use App\Models\Invoice;
use App\Models\Project;
use App\Models\Quote;
use App\Models\Setting;
use App\Models\WalletTransaction;
use Illuminate\Support\Arr;
use Inertia\Inertia;

class DashboardController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index()
    {
        $isClientUser = $this->isClientUser();

        $clientsQuery = $this->scopeClients(Client::query());
        $projectsQuery = $this->scopeByClient(Project::query()->where('is_hidden', false));
        $invoicesQuery = $this->scopeByClient(Invoice::query());

        $stats = [
            'total_clients' => $clientsQuery->count(),
            'active_projects' => (clone $projectsQuery)->where('status', '!=', 'concluido')
                ->where('status', '!=', 'cancelado')
                ->count(),
            'completed_projects' => (clone $projectsQuery)->where('status', 'concluido')->count(),
            'total_invoices' => $invoicesQuery->count(),

            'paid_amount' => (clone $invoicesQuery)->where('status', 'pago')->sum('total'),
            'pending_amount' => (clone $invoicesQuery)->where('status', 'pendente')->sum('total'),
            'invoiced_amount' => (clone $invoicesQuery)->sum('total'),

            'paid_this_month' => (clone $invoicesQuery)->whereMonth('paid_at', now()->month)
                ->whereYear('paid_at', now()->year)
                ->sum('total'),

            'new_clients_month' => (clone $clientsQuery)->whereMonth('created_at', now()->month)->count(),
            'new_projects_month' => (clone $projectsQuery)->whereMonth('created_at', now()->month)->count(),
            'pending_values' => $this->pendingValuesTotal(),
        ];

        $salesGoalValue = Setting::where('key', 'sales_goal_year')->value('value');
        $salesGoal = $salesGoalValue !== null ? (float) $salesGoalValue : null;
        $salesProgress = null;
        $salesAchieved = null;
        $salesBreakdown = null;
        $salesBreakdownDetails = null;

        if (! $isClientUser && $salesGoal && $salesGoal > 0) {
            $paidInvoicesQuery = Invoice::query()
                ->leftJoin('projects', 'projects.id', '=', 'invoices.project_id')
                ->leftJoin('quotes', 'quotes.project_id', '=', 'projects.id')
                ->where('invoices.status', 'pago')
                ->whereYear('invoices.paid_at', now()->year);

            $paidInvoicesAmount = (float) (clone $paidInvoicesQuery)
                ->selectRaw('SUM(CASE WHEN invoices.project_id IS NULL THEN invoices.total ELSE COALESCE(quotes.price_development, 0) END) as total')
                ->value('total');

            $paidInvoicesDetails = (clone $paidInvoicesQuery)
                ->select([
                    'invoices.id',
                    'invoices.number',
                    'invoices.total',
                    'invoices.project_id',
                    'projects.name as project_name',
                    'quotes.price_development as project_development',
                ])
                ->orderByDesc('invoices.paid_at')
                ->get()
                ->map(function ($invoice) {
                    $amount = $invoice->project_id
                        ? (float) ($invoice->project_development ?? 0)
                        : (float) ($invoice->total ?? 0);

                    return [
                        'id' => $invoice->id,
                        'number' => $invoice->number,
                        'project' => $invoice->project_name,
                        'amount' => $amount,
                    ];
                })
                ->toArray();

            $adjudicationsQuery = Quote::query()
                ->join('projects', 'projects.id', '=', 'quotes.project_id')
                ->whereNotIn('projects.status', ['cancelado'])
                ->whereNotNull('quotes.adjudication_percent')
                ->where('quotes.adjudication_percent', '>', 0)
                ->whereYear('quotes.adjudication_paid_at', now()->year);

            $adjudicationsThisYear = (float) (clone $adjudicationsQuery)
                ->selectRaw('SUM(COALESCE(quotes.price_development, 0) * (quotes.adjudication_percent / 100)) as total')
                ->value('total');

            $installmentsQuery = Installment::query()
                ->whereYear('paid_at', now()->year)
                ->whereHas('project', function ($query) {
                    $query->where(function ($subQuery) {
                        $subQuery->whereDoesntHave('invoice')
                            ->orWhereHas('invoice', function ($invoiceQuery) {
                                $invoiceQuery->where('status', '!=', 'pago');
                            });
                    });
                });

            $installmentsThisYear = (float) (clone $installmentsQuery)
                ->selectRaw('SUM(COALESCE(amount, 0)) as total')
                ->value('total');

            $salesAchieved = $paidInvoicesAmount + $adjudicationsThisYear + $installmentsThisYear;
            $salesProgress = min(100, round((($salesAchieved) / $salesGoal) * 100, 1));
            $salesBreakdown = [
                'paid_invoices' => $paidInvoicesAmount,
                'installments' => $installmentsThisYear,
                'adjudications' => $adjudicationsThisYear,
            ];
            $salesBreakdownDetails = [
                'paid_invoices' => $paidInvoicesDetails,
                'installments' => $installmentsQuery
                    ->with(['project:id,name', 'client:id,name'])
                    ->orderByDesc('paid_at')
                    ->get()
                    ->map(fn ($installment) => [
                        'id' => $installment->id,
                        'project' => $installment->project?->name ?? '—',
                        'client' => $installment->client?->name ?? '—',
                        'amount' => (float) ($installment->amount ?? 0),
                        'paid_at' => $installment->paid_at?->toDateString(),
                        'note' => $installment->note,
                    ])
                    ->toArray(),
                'adjudications' => $adjudicationsQuery
                    ->select([
                        'quotes.id',
                        'quotes.project_id',
                        'quotes.price_development',
                        'quotes.adjudication_percent',
                        'quotes.adjudication_paid_at',
                        'projects.name as project_name',
                    ])
                    ->orderByDesc('quotes.adjudication_paid_at')
                    ->get()
                    ->map(function ($quote) {
                        $amount = (float) ($quote->price_development ?? 0) * ((float) ($quote->adjudication_percent ?? 0) / 100);

                        return [
                            'id' => $quote->id,
                            'project' => $quote->project_name,
                            'amount' => $amount,
                            'percent' => (float) ($quote->adjudication_percent ?? 0),
                            'paid_at' => $quote->adjudication_paid_at?->toDateString(),
                        ];
                    })
                    ->toArray(),
            ];
        }

        $sales = $isClientUser ? $this->clientSales() : [];
        $installments = $isClientUser ? $this->clientInstallments() : [];
        $registeredInvoices = $isClientUser
            ? $this->scopeByClient(Invoice::with(['client', 'project']))
                ->orderByDesc('issued_at')
                ->get()
            : [];

        return Inertia::render('Dashboard', [
            'isClientUser' => $isClientUser,
            'stats' => $stats,
            'salesGoal' => $salesGoal,
            'salesProgress' => $salesProgress,
            'salesAchieved' => $salesAchieved,
            'salesBreakdown' => $salesBreakdown,
            'salesBreakdownDetails' => $salesBreakdownDetails,
            'sales' => $sales,
            'installments' => $installments,
            'registeredInvoices' => $registeredInvoices,

            'recentClients' => $this->scopeClients(Client::query())->latest()->take(5)->get(),

            'recentProjects' => $this->scopeByClient(Project::with('client')->where('is_hidden', false))
                ->latest()
                ->take(5)
                ->get(),

            'recentInvoices' => $this->scopeByClient(Invoice::with(['client', 'project']))
                ->latest()
                ->take(5)
                ->get(),

            'pendingInvoices' => $this->scopeByClient(Invoice::with('client'))
                ->where('status', 'pendente')
                ->orderBy('due_at')
                ->take(5)
                ->get(),
        ]);
    }

    private function clientSales(): array
    {
        $projectSales = $this->scopeByClient(Project::with([
            'client:id,name',
            'quote:id,project_id,price_development,price_domain_first_year,price_hosting_first_year,price_maintenance_monthly,include_domain,include_hosting',
            'invoice:id,project_id,total,status,issued_at,created_at',
        ]))
            ->where('status', 'concluido')
            ->orderByDesc('updated_at')
            ->get()
            ->map(function ($project) {
                $invoice = $project->invoice;
                $date = $invoice?->issued_at ?? $project->updated_at;
                $amount = $invoice?->total ?? $this->calculateQuoteTotal($project->quote);

                return [
                    'id' => $project->id,
                    'source' => 'project',
                    'type' => 'Projeto',
                    'client_id' => $project->client_id,
                    'client' => $project->client?->name ?? '—',
                    'description' => $project->name ?? '—',
                    'amount' => (float) $amount,
                    'date' => $date?->toDateString(),
                    'status' => $invoice?->status ?? 'pendente',
                    'invoiced' => (bool) $invoice,
                    'to_invoice' => (bool) $invoice,
                    'invoice_id' => $invoice?->id,
                    'invoice_status' => $invoice?->status,
                    'sort_at' => $date?->timestamp ?? 0,
                ];
            })
            ->toBase();

        $productSales = WalletTransaction::with([
            'wallet.client:id,name',
            'product:id,name,type',
            'packItem:id,hours',
            'intervention:id,type,notes,finish_notes,total_seconds,hourly_rate,is_pack',
            'invoice:id,status',
        ])
            ->whereHas('wallet', fn ($query) => $query->where('client_id', $this->currentClientId()))
            ->where(function ($query) {
                $query->where('type', 'purchase')
                    ->orWhere(function ($subQuery) {
                        $subQuery->where('type', 'usage')
                            ->whereNotNull('intervention_id');
                    });
            })
            ->orderByDesc('transaction_at')
            ->get()
            ->map(function ($transaction) {
                $description = $transaction->description ?? $transaction->product?->name ?? '—';

                if ($transaction->packItem?->hours) {
                    $description .= ' • '.$transaction->packItem->hours.'h';
                }

                return [
                    'id' => $transaction->id,
                    'source' => 'transaction',
                    'type' => $transaction->intervention_id
                        ? 'Intervenção'
                        : ($transaction->product?->type === 'pack' ? 'Pack' : 'Produto'),
                    'client_id' => $transaction->wallet?->client_id,
                    'client' => $transaction->wallet?->client?->name ?? '—',
                    'description' => $description,
                    'amount' => (float) ($transaction->amount ?? 0),
                    'date' => $transaction->transaction_at?->toDateString(),
                    'status' => $transaction->type,
                    'is_installment' => (bool) $transaction->is_installment,
                    'installment_count' => $transaction->installment_count,
                    'to_invoice' => (bool) $transaction->to_invoice,
                    'invoice_id' => $transaction->invoice_id,
                    'invoice_status' => $transaction->invoice?->status,
                    'sort_at' => $transaction->transaction_at?->timestamp ?? 0,
                ];
            })
            ->filter(fn ($item) => (float) ($item['amount'] ?? 0) > 0)
            ->toBase();

        return $projectSales
            ->merge($productSales)
            ->sortByDesc('sort_at')
            ->values()
            ->map(fn ($item) => Arr::except($item, ['sort_at']))
            ->toArray();
    }

    private function clientInstallments(): array
    {
        return $this->scopeByClient(Installment::with(['project:id,name', 'client:id,name', 'invoice:id,number']))
            ->orderByDesc('paid_at')
            ->get()
            ->map(fn ($installment) => [
                'id' => $installment->id,
                'project_id' => $installment->project_id,
                'project' => $installment->project?->name ?? '—',
                'client_id' => $installment->client_id,
                'client' => $installment->client?->name ?? '—',
                'invoice_id' => $installment->invoice_id,
                'invoice' => $installment->invoice?->number ?? '—',
                'amount' => (float) $installment->amount,
                'note' => $installment->note,
                'paid_at' => $installment->paid_at?->toDateString(),
            ])
            ->toArray();
    }

    private function calculateQuoteTotal(?Quote $quote): float
    {
        if (! $quote) {
            return 0;
        }

        return (float) ($quote->price_development ?? 0)
            + (float) ($quote->include_domain ? ($quote->price_domain_first_year ?? 0) : 0)
            + (float) ($quote->include_hosting ? ($quote->price_hosting_first_year ?? 0) : 0)
            + (float) ($quote->price_maintenance_monthly ?? 0);
    }

    private function pendingValuesTotal(): float
    {
        return $this->scopeByClient(Project::with(['quote'])->withSum('installments', 'amount')->where('is_hidden', false))
            ->whereNotIn('status', ['concluido', 'cancelado'])
            ->get()
            ->sum(function (Project $project) {
                $baseAmount = (float) ($project->quote?->price_development ?? 0);
                $adjudicationValue = $baseAmount * ((float) ($project->quote?->adjudication_percent ?? 0) / 100);
                $installmentsTotal = (float) ($project->installments_sum_amount ?? 0);

                return max(0, $baseAmount - $adjudicationValue - $installmentsTotal);
            });
    }
}
