<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\PackItem;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Stripe\Exception\SignatureVerificationException;
use Stripe\Webhook;

class StripeWebhookApiController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $payload = $request->getContent();
        $signature = (string) $request->header('Stripe-Signature');
        $secret = (string) config('services.stripe.webhook_secret');

        if ($secret === '') {
            abort(500, 'Stripe webhook secret not configured.');
        }

        try {
            $event = Webhook::constructEvent($payload, $signature, $secret);
        } catch (\UnexpectedValueException|SignatureVerificationException) {
            return response()->json(['message' => 'Invalid payload.'], 400);
        }

        if ($event->type === 'checkout.session.completed') {
            /** @var array<string, mixed> $session */
            $session = $event->data->object->toArray();
            $this->handleCheckoutCompleted($session);
        }

        return response()->json(['received' => true]);
    }

    private function handleCheckoutCompleted(array $session): void
    {
        $reference = $session['id'] ?? null;
        if (! is_string($reference) || $reference === '') {
            return;
        }

        if (WalletTransaction::where('payment_reference', $reference)->exists()) {
            return;
        }

        $metadata = is_array($session['metadata'] ?? null) ? $session['metadata'] : [];
        $clientId = (int) ($metadata['client_id'] ?? 0);
        $productId = (int) ($metadata['product_id'] ?? 0);
        $packItemId = (int) ($metadata['pack_item_id'] ?? 0);
        $quantity = max(1, (int) ($metadata['quantity'] ?? 1));

        if (! $clientId || ! $productId || ! $packItemId) {
            return;
        }

        $client = Client::find($clientId);
        $product = Product::find($productId);
        $packItem = PackItem::find($packItemId);

        if (! $client || ! $product || ! $packItem) {
            return;
        }

        DB::transaction(function () use ($session, $client, $product, $packItem, $quantity, $reference) {
            $wallet = Wallet::firstOrCreate(
                ['client_id' => $client->id],
                ['balance_seconds' => 0, 'balance_amount' => 0]
            );

            $seconds = (int) round(((float) $packItem->hours) * 3600 * $quantity);
            $amount = ((float) ($session['amount_total'] ?? 0)) / 100;
            $description = 'Compra Stripe: '.$product->name;
            if ($packItem->hours) {
                $description .= ' - '.$packItem->hours.'h';
            }
            if ($quantity > 1) {
                $description .= ' (x'.$quantity.')';
            }

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'purchase',
                'seconds' => $seconds,
                'amount' => $amount,
                'description' => $description,
                'product_id' => $product->id,
                'pack_item_id' => $packItem->id,
                'transaction_at' => now(),
                'payment_provider' => 'stripe',
                'payment_reference' => $reference,
                'payment_metadata' => [
                    'payment_intent' => $session['payment_intent'] ?? null,
                    'customer' => $session['customer'] ?? null,
                    'customer_details' => $session['customer_details'] ?? null,
                    'source' => $metadata['source'] ?? 'stripe',
                ],
            ]);

            $wallet->balance_seconds += $seconds;
            $wallet->balance_amount = (float) $wallet->balance_amount + $amount;
            $wallet->save();

            $this->syncBillingProfile($client, $session);
        });
    }

    private function syncBillingProfile(Client $client, array $session): void
    {
        $details = is_array($session['customer_details'] ?? null) ? $session['customer_details'] : [];
        $address = is_array($details['address'] ?? null) ? $details['address'] : [];
        $taxIds = is_array($details['tax_ids'] ?? null) ? $details['tax_ids'] : [];
        $firstTaxId = is_array($taxIds[0] ?? null) ? $taxIds[0] : [];

        $line1 = trim((string) ($address['line1'] ?? ''));
        $line2 = trim((string) ($address['line2'] ?? ''));
        $billingAddress = trim($line1.($line2 !== '' ? ', '.$line2 : ''));

        $client->forceFill([
            'stripe_customer_id' => $session['customer'] ?? $client->stripe_customer_id,
            'billing_name' => $details['name'] ?? $client->billing_name,
            'billing_email' => $details['email'] ?? $client->billing_email,
            'billing_phone' => $details['phone'] ?? $client->billing_phone,
            'billing_vat' => $firstTaxId['value'] ?? $client->billing_vat,
            'billing_address' => $billingAddress !== '' ? $billingAddress : $client->billing_address,
            'billing_postal_code' => $address['postal_code'] ?? $client->billing_postal_code,
            'billing_city' => $address['city'] ?? $client->billing_city,
            'billing_country' => $address['country'] ?? $client->billing_country,
        ])->save();
    }
}
