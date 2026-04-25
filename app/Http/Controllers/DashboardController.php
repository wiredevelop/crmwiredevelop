<?php

namespace App\Http\Controllers;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\Installment;
use App\Models\Project;
use App\Models\Quote;
use App\Models\Setting;
use Illuminate\Http\Request;
use Inertia\Inertia;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_clients' => Client::count(),
            'active_projects' => Project::where('status', '!=', 'concluido')
                ->where('status', '!=', 'cancelado')
                ->count(),
            'completed_projects' => Project::where('status', 'concluido')->count(),
            'total_invoices' => Invoice::count(),

            // RECEITAS
            'paid_amount' => Invoice::where('status', 'pago')->sum('total'),
            'pending_amount' => Invoice::where('status', 'pendente')->sum('total'),
            'invoiced_amount' => Invoice::sum('total'),

            // ESTE MÊS
            'paid_this_month' => Invoice::whereMonth('paid_at', now()->month)
                ->whereYear('paid_at', now()->year)
                ->sum('total'),

            'new_clients_month' => Client::whereMonth('created_at', now()->month)->count(),
            'new_projects_month' => Project::whereMonth('created_at', now()->month)->count(),
        ];

        $salesGoalValue = Setting::where('key', 'sales_goal_year')->value('value');
        $salesGoal = $salesGoalValue !== null ? (float) $salesGoalValue : null;
        $salesProgress = null;
        $salesAchieved = null;
        $salesBreakdown = null;
        $salesBreakdownDetails = null;

        if ($salesGoal && $salesGoal > 0) {
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
                    ->map(fn($installment) => [
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

        return Inertia::render('Dashboard', [
            'stats' => $stats,
            'salesGoal' => $salesGoal,
            'salesProgress' => $salesProgress,
            'salesAchieved' => $salesAchieved,
            'salesBreakdown' => $salesBreakdown,
            'salesBreakdownDetails' => $salesBreakdownDetails,

            'recentClients' => Client::latest()->take(5)->get(),

            'recentProjects' => Project::with('client')
                ->latest()
                ->take(5)
                ->get(),

            'recentInvoices' => Invoice::with(['client', 'project'])
                ->latest()
                ->take(5)
                ->get(),

            'pendingInvoices' => Invoice::with('client')
                ->where('status', 'pendente')
                ->orderBy('due_at')
                ->take(5)
                ->get(),
        ]);
    }
}
