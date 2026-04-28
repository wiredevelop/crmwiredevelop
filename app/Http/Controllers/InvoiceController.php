<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Invoice;
use App\Models\WalletTransaction;
use App\Support\CompanySettings;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class InvoiceController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index(Request $request)
    {
        $query = $this->scopeByClient(Invoice::with(['client', 'project']));

        // FILTROS OPCIONAIS
        if ($request->client) {
            $query->where('client_id', $request->client);
        }

        if ($request->project) {
            $query->where('project_id', $request->project);
        }

        if ($request->status) {
            $query->where('status', $request->status);
        }

        if ($request->issued_from) {
            $query->whereDate('issued_at', '>=', $request->issued_from);
        }

        if ($request->issued_to) {
            $query->whereDate('issued_at', '<=', $request->issued_to);
        }

        // ORDENAR → universal
        $sortable = [
            'number',
            'total',
            'status',
            'issued_at',
            'due_at',
            'paid_at',
        ];

        // colunas relacionadas
        if ($request->sort === 'client') {
            $query->join('clients', 'clients.id', '=', 'invoices.client_id')
                ->select('invoices.*')
                ->orderBy('clients.name', $request->direction ?? 'asc');
        } elseif ($request->sort === 'project') {
            $query->join('projects', 'projects.id', '=', 'invoices.project_id')
                ->select('invoices.*')
                ->orderBy('projects.name', $request->direction ?? 'asc');
        } else {
            // colunas locais
            $sort = $request->sort ?? 'issued_at';
            $direction = $request->direction ?? 'desc';

            if (in_array($sort, $sortable)) {
                $query->orderBy($sort, $direction);
            }
        }

        $invoices = $query->paginate(50)->withQueryString();

        return inertia('Invoices/Index', [
            'invoices' => $invoices,
            'filters' => $request->all(),
            'sort' => $request->sort,
            'direction' => $request->direction,
        ]);
    }

    public function show(Invoice $invoice): Response
    {
        $this->ensureInvoiceOwnership($invoice);

        $invoice->load('client', 'project');

        return Inertia::render('Invoices/Show', [
            'invoice' => $invoice,
        ]);
    }

    public function edit(Invoice $invoice): Response
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        $invoice->load(['client', 'project', 'items']);

        return Inertia::render('Invoices/Edit', [
            'invoice' => $invoice,
            'items' => $invoice->items,
        ]);
    }

    public function update(Request $request, Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        $data = $request->validate([
            'payment_method' => ['nullable', 'string', 'max:255'],
            'payment_account' => ['nullable', 'string', 'max:255'],
            'items' => ['nullable', 'array'],
            'items.*.description' => ['required_with:items', 'string', 'max:255'],
            'items.*.quantity' => ['required_with:items', 'numeric', 'min:0.01'],
            'items.*.unit_price' => ['required_with:items', 'numeric', 'min:0'],
        ]);

        $invoice->update([
            'payment_method' => $data['payment_method'] ?? null,
            'payment_account' => $data['payment_account'] ?? null,
        ]);

        if (array_key_exists('items', $data)) {
            $items = collect($data['items'] ?? [])->map(function ($item) {
                $qty = (float) $item['quantity'];
                $unit = (float) $item['unit_price'];

                return [
                    'description' => $item['description'],
                    'quantity' => $qty,
                    'unit_price' => $unit,
                    'total' => round($qty * $unit, 2),
                ];
            });

            $invoice->items()->delete();
            if ($items->isNotEmpty()) {
                $invoice->items()->createMany($items->toArray());
            }

            $invoice->total = $items->sum('total');
            $invoice->save();
        }

        return back()->with('success', 'Fatura atualizada.');
    }

    public function pdf(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);

        $invoice->load([
            'client',
            'project.quote',
            'walletTransactions.product',
            'walletTransactions.packItem',
            'walletTransactions.intervention',
            'items',
        ]);

        $isPaid = $invoice->status === 'pago';

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'isPaid' => $isPaid,
            'company' => CompanySettings::get(),
        ])->setPaper('a4');

        return response()->make(
            $pdf->output(),
            200,
            [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => 'inline; filename="Fatura-'.$invoice->number.'.pdf"',
            ]
        );
    }

    public function download(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);

        $invoice->load([
            'client',
            'project',
            'walletTransactions.product',
            'walletTransactions.packItem',
            'walletTransactions.intervention',
            'items',
        ]);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'company' => CompanySettings::get(),
        ])->setPaper('a4', 'portrait');

        return response()->make($pdf->stream(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Fatura-'.$invoice->number.'.pdf"',
        ]);
    }

    public function markPaid(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        $invoice->update([
            'status' => 'pago',
            'paid_at' => now(),
        ]);

        return back()->with('success', 'Fatura marcada como paga.');
    }

    public function markPending(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        $invoice->update([
            'status' => 'pendente',
            'paid_at' => null,
        ]);

        return back()->with('success', 'Fatura marcada como pendente.');
    }

    public function uninvoice(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        if ($invoice->status === 'pago') {
            return back()->withErrors([
                'uninvoice' => 'Nao podes desfaturar uma fatura paga.',
            ]);
        }

        DB::transaction(function () use ($invoice) {
            WalletTransaction::where('invoice_id', $invoice->id)
                ->update([
                    'invoice_id' => null,
                    'to_invoice' => false,
                ]);

            $invoice->delete();
        });

        return back()->with('success', 'Fatura removida.');
    }
}
