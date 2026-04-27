<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\InterventionResource;
use App\Http\Resources\Api\WalletResource;
use App\Http\Resources\Api\WalletTransactionResource;
use App\Models\Intervention;
use App\Models\Product;
use App\Models\Wallet;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use App\Support\StripeCheckoutService;

class ClientWalletApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function show(): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $client = request()->user()?->client;
        abort_if(! $client, 403);
        app(StripeCheckoutService::class)->syncPendingForClient($client);

        $wallet = Wallet::firstOrCreate(
            ['client_id' => $this->currentClientId()],
            ['balance_seconds' => 0, 'balance_amount' => 0]
        );

        $wallet->load([
            'client',
            'transactions' => fn ($query) => $query
                ->with([
                    'product:id,name',
                    'packItem:id,product_id,hours,pack_price,validity_months',
                    'intervention:id,type,status,notes,finish_notes,is_pack,started_at,ended_at,total_seconds',
                    'invoice:id,number,status',
                ])
                ->orderByDesc('transaction_at'),
        ]);

        $interventions = Intervention::query()
            ->where('client_id', $this->currentClientId())
            ->orderByDesc('started_at')
            ->get();

        $packs = Product::with('packItems')
            ->where('type', 'pack')
            ->where('active', true)
            ->orderBy('name')
            ->get()
            ->map(fn ($pack) => [
                'id' => $pack->id,
                'name' => $pack->name,
                'pack_items' => $pack->packItems->sortBy('order')->values()->map(fn ($item) => [
                    'id' => $item->id,
                    'hours' => $item->hours,
                    'normal_price' => $item->normal_price,
                    'pack_price' => $item->pack_price,
                    'validity_months' => $item->validity_months,
                    'featured' => (bool) $item->featured,
                ])->toArray(),
            ])
            ->values()
            ->toArray();

        return $this->success([
            'wallet' => new WalletResource($wallet),
            'transactions' => WalletTransactionResource::collection($wallet->transactions),
            'interventions' => InterventionResource::collection($interventions),
            'packs' => $packs,
        ]);
    }

    public function checkout(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'pack_item_id' => ['required', 'integer', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1', 'max:99'],
            'wants_invoice' => ['required', 'boolean'],
            'billing_name' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'max:120',
            ],
            'billing_email' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'email',
                'max:160',
            ],
            'billing_phone' => ['nullable', 'string', 'regex:/^[0-9]{9}$/'],
            'billing_vat' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'regex:/^[0-9]{9}$/',
            ],
            'billing_address' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'max:160',
            ],
            'billing_postal_code' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'regex:/^[0-9]{4}-[0-9]{3}$/',
            ],
            'billing_city' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'max:80',
            ],
            'billing_country' => [
                Rule::requiredIf(fn () => (bool) $request->boolean('wants_invoice')),
                'nullable',
                'string',
                'regex:/^[A-Za-z]{2}$/',
            ],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);
        if (! config('services.stripe.secret_key') || ! config('services.stripe.public_key')) {
            return $this->error('Checkout Stripe indisponível de momento.', [], 503);
        }

        $product = Product::with('packItems')->where('type', 'pack')->findOrFail($data['product_id']);
        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);
        abort_if(! $packItem, 422, 'Opção de pack inválida.');

        $checkout = $stripeCheckout->createPendingPackPaymentSheet(
            $client,
            $product,
            $packItem,
            $data['quantity'] ?? 1,
            (bool) $data['wants_invoice'],
            $data
        );

        return $this->success([
            'payment_intent_id' => $checkout['paymentIntent']->id,
            'payment_intent_client_secret' => $checkout['paymentIntent']->client_secret,
            'customer_id' => $checkout['customer']->id,
            'customer_ephemeral_key_secret' => $checkout['ephemeralKey']->secret,
            'transaction_id' => $checkout['transaction']->id,
            'invoice_id' => $checkout['invoice']->id,
            'publishable_key' => config('services.stripe.public_key'),
            'amount' => (float) $checkout['invoice']->total,
            'currency' => 'eur',
        ], 'Pagamento preparado e documento pendente registado.');
    }

    public function finalize(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'payment_intent_id' => ['required', 'string', 'max:255'],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);

        $stripeCheckout->syncPaymentIntent($data['payment_intent_id']);
        $stripeCheckout->syncPendingForClient($client);

        return $this->success([], 'Pagamento sincronizado.');
    }

    public function cancel(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'payment_intent_id' => ['required', 'string', 'max:255'],
        ]);

        $stripeCheckout->cancelPaymentIntent($data['payment_intent_id']);

        return $this->success([], 'Pagamento cancelado e documento removido.');
    }
}
