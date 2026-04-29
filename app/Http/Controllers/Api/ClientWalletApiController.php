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
use App\Support\CompanySettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
        $company = CompanySettings::get();
        $stripeAvailable = (bool) config('services.stripe.secret_key')
            && (bool) config('services.stripe.public_key');

        if ($stripeAvailable) {
            app(StripeCheckoutService::class)->syncPendingForClient($client);
        }

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
            'checkout_method' => in_array($company['client_checkout_method'] ?? null, ['stripe', 'manual'], true)
                ? $company['client_checkout_method']
                : 'stripe',
            'stripe_available' => $stripeAvailable,
            'manual_payment' => [
                'notes' => $company['payment_notes'] ?? '',
                'methods' => is_array($company['payment_methods'] ?? null) ? $company['payment_methods'] : [],
            ],
        ]);
    }

    public function checkout(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'pack_item_id' => ['required', 'integer', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1', 'max:99'],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);

        if (! config('services.stripe.secret_key') || ! config('services.stripe.public_key')) {
            return $this->error('Checkout Stripe indisponível de momento.', [], 503);
        }

        $product = Product::with('packItems')->where('type', 'pack')->findOrFail($data['product_id']);
        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);
        abort_if(! $packItem, 422, 'Opção de pack inválida.');

        $successUrl = url('/checkout/stripe/sucesso?source=mobile_app&target=wallet&session_id={CHECKOUT_SESSION_ID}');
        $cancelUrl = url('/checkout/stripe/cancelado?source=mobile_app&target=wallet');

        $checkout = $stripeCheckout->createPendingPackCheckout(
            $client,
            $product,
            $packItem,
            $data['quantity'] ?? 1,
            $successUrl,
            $cancelUrl,
            false,
            []
        );

        return $this->success([
            'checkout_session_id' => $checkout['session']->id,
            'checkout_url' => $checkout['session']->url,
            'cancel_token' => data_get($checkout['transaction']->payment_metadata, 'cancel_token'),
            'transaction_id' => $checkout['transaction']->id,
            'invoice_id' => $checkout['invoice']->id,
            'amount' => (float) $checkout['invoice']->total,
            'currency' => 'eur',
            'available_payment_methods' => [],
        ], 'Checkout Stripe preparado e documento pendente registado.');
    }

    public function finalize(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'payment_intent_id' => ['nullable', 'string', 'max:255'],
            'session_id' => ['nullable', 'string', 'max:255'],
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);

        $paymentIntentId = $data['payment_intent_id'] ?? null;
        $sessionId = $data['session_id'] ?? null;

        if ($sessionId) {
            $stripeCheckout->syncCheckoutSession($sessionId);
        }

        if ($paymentIntentId) {
            $stripeCheckout->syncPaymentIntent($paymentIntentId);
        }

        $stripeCheckout->syncPendingForClient($client);

        $transaction = null;
        if ($sessionId) {
            $transaction = \App\Models\WalletTransaction::where('payment_reference', $sessionId)->first();
        } elseif ($paymentIntentId) {
            $transaction = \App\Models\WalletTransaction::where('payment_reference', $paymentIntentId)->first();
        }

        return $this->success([
            'status' => data_get($transaction, 'payment_metadata.status', 'missing'),
            'transaction_id' => $transaction?->id,
        ], 'Pagamento sincronizado.');
    }

    public function cancel(Request $request, StripeCheckoutService $stripeCheckout): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $data = $request->validate([
            'payment_intent_id' => ['nullable', 'string', 'max:255'],
            'session_id' => ['nullable', 'string', 'max:255'],
            'cancel_token' => ['nullable', 'string', 'max:255'],
        ]);

        if (! empty($data['cancel_token'])) {
            $stripeCheckout->cancelByToken($data['cancel_token']);
        } elseif (! empty($data['session_id'])) {
            $stripeCheckout->syncCheckoutSession($data['session_id']);
            $transaction = \App\Models\WalletTransaction::where('payment_reference', $data['session_id'])->first();
            if ($transaction) {
                $stripeCheckout->cancelByToken((string) data_get($transaction->payment_metadata, 'cancel_token'));
            }
        } elseif (! empty($data['payment_intent_id'])) {
            $stripeCheckout->cancelPaymentIntent($data['payment_intent_id']);
        }

        return $this->success([], 'Pagamento cancelado e documento removido.');
    }
}
