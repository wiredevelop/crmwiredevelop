<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\InvoiceResource;
use App\Models\Invoice;
use App\Models\WalletTransaction;
use App\Support\CompanySettings;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InvoiceApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $query = Invoice::with(['client', 'project']);

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

        $sortable = ['number', 'total', 'status', 'issued_at', 'due_at', 'paid_at'];

        if ($request->sort === 'client') {
            $query->join('clients', 'clients.id', '=', 'invoices.client_id')->select('invoices.*')->orderBy('clients.name', $request->direction ?? 'asc');
        } elseif ($request->sort === 'project') {
            $query->join('projects', 'projects.id', '=', 'invoices.project_id')->select('invoices.*')->orderBy('projects.name', $request->direction ?? 'asc');
        } else {
            $sort = $request->sort ?? 'issued_at';
            $direction = $request->direction ?? 'desc';
            if (in_array($sort, $sortable, true)) {
                $query->orderBy($sort, $direction);
            }
        }

        $invoices = $query->paginate((int) $request->integer('per_page', 50))->withQueryString();

        return $this->paginated($request, $invoices, InvoiceResource::collection($invoices->getCollection())->resolve(), null, [
            'filters' => $request->all(),
            'sort' => $request->sort,
            'direction' => $request->direction,
        ]);
    }

    public function show(Invoice $invoice): JsonResponse
    {
        $invoice->load(['client', 'project', 'items', 'installments']);

        return $this->success([
            'invoice' => new InvoiceResource($invoice),
        ]);
    }

    public function update(Request $request, Invoice $invoice): JsonResponse
    {
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

        return $this->success([
            'invoice' => new InvoiceResource($invoice->fresh(['client', 'project', 'items', 'installments'])),
        ], 'Fatura atualizada.');
    }

    public function pdf(Invoice $invoice)
    {
        $invoice->load(['client', 'project.quote', 'walletTransactions.product', 'walletTransactions.packItem', 'walletTransactions.intervention', 'items']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'isPaid' => $invoice->status === 'pago',
            'company' => CompanySettings::get(),
        ])->setPaper('a4');

        return response()->make($pdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Fatura-' . $invoice->number . '.pdf"',
        ]);
    }

    public function download(Invoice $invoice)
    {
        $invoice->load(['client', 'project', 'walletTransactions.product', 'walletTransactions.packItem', 'walletTransactions.intervention', 'items']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'company' => CompanySettings::get(),
        ])->setPaper('a4', 'portrait');

        return response()->make($pdf->stream(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Fatura-' . $invoice->number . '.pdf"',
        ]);
    }

    public function markPaid(Invoice $invoice): JsonResponse
    {
        $invoice->update([
            'status' => 'pago',
            'paid_at' => now(),
        ]);

        return $this->success([
            'invoice' => new InvoiceResource($invoice->fresh()),
        ], 'Fatura marcada como paga.');
    }

    public function markPending(Invoice $invoice): JsonResponse
    {
        $invoice->update([
            'status' => 'pendente',
            'paid_at' => null,
        ]);

        return $this->success([
            'invoice' => new InvoiceResource($invoice->fresh()),
        ], 'Fatura marcada como pendente.');
    }

    public function uninvoice(Invoice $invoice): JsonResponse
    {
        if ($invoice->status === 'pago') {
            return $this->error('Nao podes desfaturar uma fatura paga.', ['uninvoice' => ['Nao podes desfaturar uma fatura paga.']], 422);
        }

        DB::transaction(function () use ($invoice) {
            WalletTransaction::where('invoice_id', $invoice->id)->update([
                'invoice_id' => null,
                'to_invoice' => false,
            ]);

            $invoice->delete();
        });

        return $this->success([], 'Fatura removida.');
    }
}
