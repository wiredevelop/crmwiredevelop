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
use App\Support\StripeCheckoutService;

class ClientWalletApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function show(): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

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
        ]);

        $client = $request->user()?->client;
        abort_if(! $client, 403);
        if (! config('services.stripe.secret_key') || ! config('services.stripe.public_key')) {
            return $this->error('Checkout Stripe indisponível de momento.', [], 503);
        }

        $product = Product::with('packItems')->where('type', 'pack')->findOrFail($data['product_id']);
        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);
        abort_if(! $packItem, 422, 'Opção de pack inválida.');

        $baseUrl = rtrim(config('app.url'), '/');
        $successUrl = config('services.stripe.success_url') ?: $baseUrl.'/checkout/stripe/sucesso?session_id={CHECKOUT_SESSION_ID}';
        $cancelUrl = config('services.stripe.cancel_url') ?: $baseUrl.'/checkout/stripe/cancelado';

        $session = $stripeCheckout->createPackCheckoutSession(
            $client,
            $product,
            $packItem,
            $data['quantity'] ?? 1,
            $successUrl,
            $cancelUrl
        );

        return $this->success([
            'checkout_url' => $session->url,
            'checkout_session_id' => $session->id,
            'publishable_key' => config('services.stripe.public_key'),
        ]);
    }
}
