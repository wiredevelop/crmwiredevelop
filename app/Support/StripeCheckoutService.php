<?php

namespace App\Support;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\PackItem;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Stripe\Checkout\Session;
use Stripe\Customer;
use Stripe\StripeClient;

class StripeCheckoutService
{
    public function createPendingPackCheckout(
        Client $client,
        Product $product,
        PackItem $packItem,
        int $quantity,
        string $successUrl,
        string $cancelBaseUrl,
        bool $wantsInvoice,
        array $billing = []
    ): array {
        return DB::transaction(function () use ($client, $product, $packItem, $quantity, $successUrl, $cancelBaseUrl, $wantsInvoice, $billing) {
            $this->updateBillingProfile($client, $billing);
            $total = round((float) $packItem->pack_price * $quantity, 2);

            $invoice = Invoice::create([
                'client_id' => $client->id,
                'number' => Invoice::generateNumber(),
                'total' => $total,
                'status' => 'pendente',
                'issued_at' => now(),
                'due_at' => now()->addDay(),
                'paid_at' => null,
                'payment_method' => 'Stripe Checkout',
                'payment_account' => $wantsInvoice ? 'Documento com NIF solicitado' : 'Documento pendente',
            ]);

            $cancelToken = (string) Str::uuid();
            $session = $this->createPackCheckoutSession(
                $client,
                $product,
                $packItem,
                $quantity,
                $successUrl,
                $cancelBaseUrl.(str_contains($cancelBaseUrl, '?') ? '&' : '?').'token='.$cancelToken,
                array_filter([
                    'invoice_id' => (string) $invoice->id,
                    'cancel_token' => $cancelToken,
                    'wants_invoice' => $wantsInvoice ? '1' : '0',
                ])
            );

            $wallet = Wallet::firstOrCreate(
                ['client_id' => $client->id],
                ['balance_seconds' => 0, 'balance_amount' => 0]
            );

            $transaction = WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'purchase',
                'seconds' => 0,
                'amount' => $total,
                'description' => 'Compra Stripe pendente: '.$this->productLabel($product, $packItem),
                'product_id' => $product->id,
                'pack_item_id' => $packItem->id,
                'transaction_at' => now(),
                'to_invoice' => true,
                'invoice_id' => $invoice->id,
                'payment_provider' => 'stripe',
                'payment_reference' => $session->id,
                'payment_metadata' => [
                    'status' => 'pending',
                    'cancel_token' => $cancelToken,
                    'invoice_id' => $invoice->id,
                    'quantity' => $quantity,
                    'wants_invoice' => $wantsInvoice,
                    'billing' => $this->billingSnapshot($client),
                ],
            ]);

            $invoice->items()->create([
                'description' => $this->productLabel($product, $packItem).' (Transação #'.$transaction->id.')',
                'quantity' => $quantity,
                'unit_price' => (float) $packItem->pack_price,
                'total' => $total,
                'source_type' => 'transaction',
                'source_id' => $transaction->id,
            ]);

            return compact('session', 'transaction', 'invoice');
        });
    }

    public function createPackCheckoutSession(
        Client $client,
        Product $product,
        PackItem $packItem,
        int $quantity,
        string $successUrl,
        string $cancelUrl,
        array $metadata = []
    ): Session {
        $stripe = $this->client();
        $customer = $this->ensureCustomer($stripe, $client);
        $unitAmount = (int) round(((float) $packItem->pack_price) * 100);

        return $stripe->checkout->sessions->create([
            'mode' => 'payment',
            'customer' => $customer->id,
            'success_url' => $successUrl,
            'cancel_url' => $cancelUrl,
            'billing_address_collection' => 'required',
            'tax_id_collection' => ['enabled' => true],
            'customer_update' => [
                'name' => 'auto',
                'address' => 'auto',
            ],
            'line_items' => [[
                'quantity' => $quantity,
                'price_data' => [
                    'currency' => 'eur',
                    'unit_amount' => $unitAmount,
                    'product_data' => [
                        'name' => $this->productLabel($product, $packItem),
                        'metadata' => [
                            'client_id' => (string) $client->id,
                            'product_id' => (string) $product->id,
                            'pack_item_id' => (string) $packItem->id,
                        ],
                    ],
                ],
            ]],
            'metadata' => [
                'client_id' => (string) $client->id,
                'product_id' => (string) $product->id,
                'pack_item_id' => (string) $packItem->id,
                'quantity' => (string) $quantity,
                'source' => 'flutter_wallet',
                ...$metadata,
            ],
        ]);
    }

    public function syncPendingForClient(Client $client): void
    {
        $transactions = WalletTransaction::query()
            ->where('payment_provider', 'stripe')
            ->whereHas('wallet', fn ($query) => $query->where('client_id', $client->id))
            ->where('payment_metadata->status', 'pending')
            ->get();

        foreach ($transactions as $transaction) {
            $this->syncPendingTransaction($transaction);
        }
    }

    public function syncCheckoutSession(string $sessionId): void
    {
        $transaction = WalletTransaction::where('payment_reference', $sessionId)->first();
        if ($transaction) {
            $this->syncPendingTransaction($transaction);
        }
    }

    public function cancelByToken(string $token): void
    {
        $transaction = WalletTransaction::query()
            ->where('payment_provider', 'stripe')
            ->where('payment_metadata->cancel_token', $token)
            ->first();

        if (! $transaction) {
            return;
        }

        $this->cleanupPendingTransaction($transaction, true);
    }

    public function handleWebhookSession(array $session, string $eventType): void
    {
        $reference = $session['id'] ?? null;
        if (! is_string($reference) || $reference === '') {
            return;
        }

        $transaction = WalletTransaction::where('payment_reference', $reference)->first();
        if (! $transaction) {
            return;
        }

        if (in_array($eventType, ['checkout.session.completed', 'checkout.session.async_payment_succeeded'], true)
            && ($session['payment_status'] ?? null) === 'paid') {
            $this->markPendingTransactionPaid($transaction, $session);
            return;
        }

        if (in_array($eventType, ['checkout.session.expired', 'checkout.session.async_payment_failed'], true)) {
            $this->cleanupPendingTransaction($transaction, false);
        }
    }

    private function ensureCustomer(StripeClient $stripe, Client $client): Customer
    {
        if ($client->stripe_customer_id) {
            /** @var Customer $customer */
            $customer = $stripe->customers->retrieve($client->stripe_customer_id, []);

            return $customer;
        }

        /** @var Customer $customer */
        $customer = $stripe->customers->create([
            'name' => $client->billing_name ?: $client->name,
            'email' => $client->billing_email ?: $client->email,
            'phone' => $client->billing_phone ?: $client->phone,
            'address' => $this->customerAddress($client),
            'metadata' => [
                'client_id' => (string) $client->id,
                'company' => (string) ($client->company ?? ''),
            ],
        ]);

        $client->forceFill(['stripe_customer_id' => $customer->id])->save();

        return $customer;
    }

    private function customerAddress(Client $client): ?array
    {
        if (! $client->billing_address && ! $client->billing_postal_code && ! $client->billing_city && ! $client->billing_country) {
            return null;
        }

        return [
            'line1' => $client->billing_address,
            'postal_code' => $client->billing_postal_code,
            'city' => $client->billing_city,
            'country' => $client->billing_country,
        ];
    }

    private function productLabel(Product $product, PackItem $packItem): string
    {
        $label = $product->name;
        if ($packItem->hours) {
            $label .= ' - '.$packItem->hours.'h';
        }

        return $label;
    }

    private function syncPendingTransaction(WalletTransaction $transaction): void
    {
        if (! $transaction->payment_reference) {
            return;
        }

        $session = $this->client()->checkout->sessions->retrieve($transaction->payment_reference, []);
        $data = $session->toArray();
        $status = $data['status'] ?? null;
        $paymentStatus = $data['payment_status'] ?? null;

        if ($status === 'complete' && $paymentStatus === 'paid') {
            $this->markPendingTransactionPaid($transaction, $data);
            return;
        }

        if ($status === 'expired') {
            $this->cleanupPendingTransaction($transaction, false);
        }
    }

    private function markPendingTransactionPaid(WalletTransaction $transaction, array $session): void
    {
        $metadata = is_array($transaction->payment_metadata) ? $transaction->payment_metadata : [];
        if (($metadata['status'] ?? null) === 'paid') {
            return;
        }

        $product = Product::find($transaction->product_id);
        $packItem = PackItem::find($transaction->pack_item_id);
        $wallet = $transaction->wallet ?: Wallet::find($transaction->wallet_id);
        $client = $wallet?->client ?: Client::find($wallet?->client_id);

        if (! $product || ! $packItem || ! $wallet || ! $client) {
            return;
        }

        DB::transaction(function () use ($transaction, $session, $metadata, $product, $packItem, $wallet, $client) {
            $quantity = max(1, (int) ($metadata['quantity'] ?? 1));
            $seconds = (int) round(((float) $packItem->hours) * 3600 * $quantity);

            $transaction->seconds = $seconds;
            $transaction->description = 'Compra Stripe: '.$this->productLabel($product, $packItem);
            $transaction->payment_metadata = array_merge($metadata, [
                'status' => 'paid',
                'customer' => $session['customer'] ?? null,
                'payment_intent' => $session['payment_intent'] ?? null,
                'customer_details' => $session['customer_details'] ?? null,
            ]);
            $transaction->save();

            $wallet->balance_seconds += $seconds;
            $wallet->balance_amount = (float) $wallet->balance_amount + (float) $transaction->amount;
            $wallet->save();

            if ($transaction->invoice_id) {
                $invoice = Invoice::with('items')->find($transaction->invoice_id);
                if ($invoice) {
                    $invoice->update([
                        'status' => 'pago',
                        'paid_at' => now(),
                        'payment_method' => 'Stripe Checkout',
                        'payment_account' => (string) ($session['payment_intent'] ?? 'Stripe'),
                    ]);

                    $invoice->items()->updateOrCreate(
                        ['source_type' => 'transaction', 'source_id' => $transaction->id],
                        [
                            'description' => $this->productLabel($product, $packItem).' (Transação #'.$transaction->id.')',
                            'quantity' => $quantity,
                            'unit_price' => (float) $packItem->pack_price,
                            'total' => (float) $transaction->amount,
                        ]
                    );
                }
            }

            $this->syncBillingProfile($client, $session);
        });
    }

    private function cleanupPendingTransaction(WalletTransaction $transaction, bool $expireSession): void
    {
        $metadata = is_array($transaction->payment_metadata) ? $transaction->payment_metadata : [];
        if (($metadata['status'] ?? null) === 'paid') {
            return;
        }

        if ($expireSession && $transaction->payment_reference) {
            $session = $this->client()->checkout->sessions->retrieve($transaction->payment_reference, []);
            if (($session->status ?? null) === 'open') {
                $this->client()->checkout->sessions->expire($transaction->payment_reference, []);
            }
        }

        DB::transaction(function () use ($transaction) {
            if ($transaction->invoice_id) {
                $invoice = Invoice::with('items')->find($transaction->invoice_id);
                if ($invoice) {
                    $invoice->delete();
                }
            }

            $transaction->delete();
        });
    }

    private function updateBillingProfile(Client $client, array $billing): void
    {
        $payload = array_filter([
            'billing_name' => $billing['billing_name'] ?? null,
            'billing_email' => $billing['billing_email'] ?? null,
            'billing_phone' => $billing['billing_phone'] ?? null,
            'billing_vat' => $billing['billing_vat'] ?? null,
            'billing_address' => $billing['billing_address'] ?? null,
            'billing_postal_code' => $billing['billing_postal_code'] ?? null,
            'billing_city' => $billing['billing_city'] ?? null,
            'billing_country' => isset($billing['billing_country'])
                ? strtoupper((string) $billing['billing_country'])
                : null,
        ], fn ($value) => $value !== null && $value !== '');

        if ($payload !== []) {
            $client->forceFill($payload)->save();
        }
    }

    private function syncBillingProfile(Client $client, array $session): void
    {
        $customerDetails = is_array($session['customer_details'] ?? null)
            ? $session['customer_details']
            : [];
        $address = is_array($customerDetails['address'] ?? null)
            ? $customerDetails['address']
            : [];
        $taxIds = is_array($customerDetails['tax_ids'] ?? null)
            ? $customerDetails['tax_ids']
            : [];

        $vat = data_get($taxIds, '0.value')
            ?: data_get($session, 'metadata.billing_vat')
            ?: $client->billing_vat;

        $payload = array_filter([
            'billing_name' => $customerDetails['name'] ?? data_get($session, 'metadata.billing_name'),
            'billing_email' => $customerDetails['email'] ?? data_get($session, 'metadata.billing_email'),
            'billing_phone' => $customerDetails['phone'] ?? data_get($session, 'metadata.billing_phone'),
            'billing_vat' => $vat,
            'billing_address' => $address['line1'] ?? data_get($session, 'metadata.billing_address'),
            'billing_postal_code' => $address['postal_code'] ?? data_get($session, 'metadata.billing_postal_code'),
            'billing_city' => $address['city'] ?? data_get($session, 'metadata.billing_city'),
            'billing_country' => strtoupper((string) ($address['country'] ?? data_get($session, 'metadata.billing_country') ?? $client->billing_country ?? '')),
        ], fn ($value) => $value !== null && $value !== '');

        if ($payload !== []) {
            $client->forceFill($payload)->save();
        }
    }

    private function billingSnapshot(Client $client): array
    {
        return Arr::only($client->toArray(), [
            'billing_name',
            'billing_email',
            'billing_phone',
            'billing_vat',
            'billing_address',
            'billing_postal_code',
            'billing_city',
            'billing_country',
        ]);
    }

    private function client(): StripeClient
    {
        return new StripeClient([
            'api_key' => (string) config('services.stripe.secret_key'),
            'stripe_version' => (string) config('services.stripe.api_version'),
        ]);
    }
}
