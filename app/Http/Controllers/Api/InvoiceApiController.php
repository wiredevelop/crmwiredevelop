<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\InvoiceResource;
use App\Models\Invoice;
use App\Models\WalletTransaction;
use App\Support\CompanySettings;
use App\Support\StripeCheckoutService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class InvoiceApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        if ($this->isClientUser()) {
            $client = $request->user()?->client;
            if ($client && config('services.stripe.secret_key') && config('services.stripe.public_key')) {
                app(StripeCheckoutService::class)->syncPendingForClient($client);
            }
        }

        $query = $this->scopeByClient(Invoice::with(['client', 'project']));

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

    public function checkout(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'invoice_ids' => ['required', 'array', 'min:1', 'max:50'],
            'invoice_ids.*' => ['required', 'integer', 'distinct'],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);

        if (! config('services.stripe.secret_key') || ! config('services.stripe.public_key')) {
            return $this->error('Checkout Stripe indisponível de momento.', [], 503);
        }

        $invoices = Invoice::query()
            ->where('client_id', $client->id)
            ->whereIn('id', $data['invoice_ids'])
            ->get();

        if ($invoices->count() !== count($data['invoice_ids'])) {
            return $this->error('Existem documentos inválidos na seleção.', [], 422);
        }

        if ($invoices->contains(fn (Invoice $invoice) => $invoice->status !== 'pendente')) {
            return $this->error('Só podes pagar documentos pendentes.', [], 422);
        }

        $successUrl = url('/checkout/stripe/sucesso?source=mobile_app&target=invoices&session_id={CHECKOUT_SESSION_ID}');
        $cancelUrl = url('/checkout/stripe/cancelado?source=mobile_app&target=invoices');

        $checkout = $stripeCheckout->createPendingInvoiceCheckout(
            $client,
            $invoices,
            $successUrl,
            $cancelUrl,
        );

        return $this->success([
            'checkout_session_id' => $checkout['session']->id,
            'checkout_url' => $checkout['session']->url,
            'cancel_token' => $checkout['cancel_token'],
            'invoice_ids' => collect($checkout['invoices'])->pluck('id')->all(),
            'invoice_count' => $checkout['invoice_count'],
            'requested_amount' => $checkout['requested_amount'],
            'surcharge_amount' => $checkout['surcharge_amount'],
            'gross_amount' => $checkout['gross_amount'],
            'currency' => 'eur',
        ], 'Checkout Stripe preparado para os documentos selecionados.');
    }

    public function finalizeCheckout(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'session_id' => ['nullable', 'string', 'max:255'],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);

        $sessionId = $data['session_id'] ?? null;
        if ($sessionId) {
            $stripeCheckout->syncCheckoutSession($sessionId);
        }

        $stripeCheckout->syncPendingForClient($client);

        $invoices = $sessionId
            ? Invoice::query()
                ->where('client_id', $client->id)
                ->where('payment_reference', $sessionId)
                ->get()
            : new Collection();

        $paidCount = $invoices->where('status', 'pago')->count();
        $status = 'missing';
        if ($invoices->isNotEmpty()) {
            $status = $paidCount === $invoices->count() ? 'paid' : 'pending';
        }

        return $this->success([
            'status' => $status,
            'invoice_ids' => $invoices->pluck('id')->all(),
            'paid_count' => $paidCount,
        ], 'Pagamento sincronizado.');
    }

    public function cancelCheckout(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'session_id' => ['nullable', 'string', 'max:255'],
            'cancel_token' => ['nullable', 'string', 'max:255'],
        ]);

        if (! empty($data['cancel_token'])) {
            $stripeCheckout->cancelByToken($data['cancel_token']);
        } elseif (! empty($data['session_id'])) {
            $stripeCheckout->syncCheckoutSession($data['session_id']);
            $invoice = Invoice::query()
                ->where('payment_reference', $data['session_id'])
                ->first();
            if ($invoice) {
                $stripeCheckout->cancelByToken((string) data_get($invoice->payment_metadata, 'cancel_token'));
            }
        }

        return $this->success([], 'Pagamento cancelado e documentos sincronizados.');
    }

    public function show(Invoice $invoice): JsonResponse
    {
        $this->ensureInvoiceOwnership($invoice);

        $relations = [
            'client',
            'project',
            'installments',
            'items.sourceTransaction.product',
            'items.sourceTransaction.packItem',
            'items.sourceTransaction.intervention',
        ];

        if (! $this->isClientUser()) {
            $relations[] = 'items.sourceProject';
        }

        $invoice->load($relations);

        return $this->success([
            'invoice' => new InvoiceResource($invoice),
        ]);
    }

    public function update(Request $request, Invoice $invoice): JsonResponse
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

        return $this->success([
            'invoice' => new InvoiceResource($invoice->fresh(['client', 'project', 'items', 'installments'])),
        ], 'Fatura atualizada.');
    }

    public function pdf(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);

        $invoice->load(['client', 'project.quote', 'walletTransactions.product', 'walletTransactions.packItem', 'walletTransactions.intervention', 'items']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'isPaid' => $invoice->status === 'pago',
            'company' => CompanySettings::get(),
        ])->setPaper('a4');

        return response()->make($pdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Fatura-'.$invoice->number.'.pdf"',
        ]);
    }

    public function download(Invoice $invoice)
    {
        $this->ensureInvoiceOwnership($invoice);

        $invoice->load(['client', 'project', 'walletTransactions.product', 'walletTransactions.packItem', 'walletTransactions.intervention', 'items']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
            'company' => CompanySettings::get(),
        ])->setPaper('a4', 'portrait');

        return response()->make($pdf->stream(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Fatura-'.$invoice->number.'.pdf"',
        ]);
    }

    public function markPaid(Invoice $invoice): JsonResponse
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

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
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

        $invoice->update([
            'status' => 'pendente',
            'paid_at' => null,
            'payment_provider' => null,
            'payment_reference' => null,
            'payment_metadata' => null,
        ]);

        return $this->success([
            'invoice' => new InvoiceResource($invoice->fresh()),
        ], 'Fatura marcada como pendente.');
    }

    public function uninvoice(Invoice $invoice): JsonResponse
    {
        $this->ensureInvoiceOwnership($invoice);
        $this->abortIfClientUser();

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
