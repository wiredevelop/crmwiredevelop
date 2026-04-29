<?php

namespace App\Http\Controllers;

use App\Models\Client;
use App\Models\Product;
use App\Support\StripeCheckoutService;
use App\Support\WalletPackPurchaseService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Symfony\Component\HttpFoundation\Response;

class WalletPackController extends Controller
{
    public function store(Request $request, WalletPackPurchaseService $purchaseService): RedirectResponse
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'product_id' => ['required', 'exists:products,id'],
            'pack_item_id' => ['required', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1'],
        ]);

        $quantity = $data['quantity'] ?? 1;

        $product = Product::with('packItems')
            ->where('type', 'pack')
            ->findOrFail($data['product_id']);

        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);

        if (! $packItem) {
            return back()->with('error', 'Opção de pack inválida.');
        }

        $client = Client::findOrFail($data['client_id']);
        $purchaseService->registerManualPurchase($client, $product, $packItem, $quantity);

        return back()->with('success', 'Compra manual registada e documento pendente criado.');
    }

    public function checkoutStripe(Request $request, StripeCheckoutService $stripeCheckout): Response
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'product_id' => ['required', 'exists:products,id'],
            'pack_item_id' => ['required', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1'],
        ]);

        if (! config('services.stripe.secret_key') || ! config('services.stripe.public_key')) {
            return back()->with('error', 'Checkout Stripe indisponível neste servidor.');
        }

        $quantity = $data['quantity'] ?? 1;
        $client = Client::findOrFail($data['client_id']);
        $product = Product::with('packItems')
            ->where('type', 'pack')
            ->findOrFail($data['product_id']);
        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);

        if (! $packItem) {
            return back()->with('error', 'Opção de pack inválida.');
        }

        $successUrl = route('wallets.index', [
            'client_id' => $client->id,
            'stripe_status' => 'success',
        ]);
        $successUrl .= (str_contains($successUrl, '?') ? '&' : '?').'session_id={CHECKOUT_SESSION_ID}';

        $cancelUrl = route('wallets.index', [
            'client_id' => $client->id,
            'stripe_status' => 'cancel',
        ]);

        $checkout = $stripeCheckout->createPendingPackCheckout(
            $client,
            $product,
            $packItem,
            $quantity,
            $successUrl,
            $cancelUrl,
            false,
            []
        );

        return Inertia::location((string) $checkout['session']->url);
    }
}
