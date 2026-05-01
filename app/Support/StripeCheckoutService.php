<?php

namespace App\Support;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\PackItem;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Support\WalletPackPurchaseService;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Stripe\Checkout\Session;
use Stripe\Customer;
use Stripe\EphemeralKey;
use Stripe\PaymentIntent;
use Stripe\StripeClient;

class StripeCheckoutService
{
    public function __construct(
        private readonly WalletPackPurchaseService $packPurchaseService,
        private readonly StripeTerminalService $stripeTerminalService,
    ) {
    }

    public function createPendingPackPaymentSheet(
        Client $client,
        Product $product,
        PackItem $packItem,
        int $quantity,
        bool $wantsInvoice,
        array $billing = []
    ): array {
        return DB::transaction(function () use ($client, $product, $packItem, $quantity, $wantsInvoice, $billing) {
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
                'payment_method' => 'Stripe Payment Sheet',
                'payment_account' => $wantsInvoice ? 'Documento com NIF solicitado' : 'Documento pendente',
            ]);

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
                'payment_metadata' => [
                    'status' => 'pending',
                    'stripe_type' => 'payment_intent',
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

            $stripe = $this->client();
            $customer = $this->ensureCustomer($stripe, $client);
            /** @var PaymentIntent $paymentIntent */
            $paymentIntent = $stripe->paymentIntents->create([
                'amount' => (int) round($total * 100),
                'currency' => 'eur',
                'customer' => $customer->id,
                'payment_method_types' => ['card'],
                'description' => $this->productLabel($product, $packItem),
                'metadata' => [
                    'client_id' => (string) $client->id,
                    'product_id' => (string) $product->id,
                    'pack_item_id' => (string) $packItem->id,
                    'quantity' => (string) $quantity,
                    'source' => 'flutter_wallet_payment_sheet',
                    'invoice_id' => (string) $invoice->id,
                    'transaction_id' => (string) $transaction->id,
                    'wants_invoice' => $wantsInvoice ? '1' : '0',
                ],
            ]);

            /** @var EphemeralKey $ephemeralKey */
            $ephemeralKey = $stripe->ephemeralKeys->create(
                ['customer' => $customer->id],
                ['stripe_version' => (string) config('services.stripe.api_version')]
            );

            $transaction->payment_reference = $paymentIntent->id;
            $transaction->payment_metadata = array_merge(
                $transaction->payment_metadata ?? [],
                ['payment_intent_id' => $paymentIntent->id]
            );
            $transaction->save();

            return compact('paymentIntent', 'ephemeralKey', 'transaction', 'invoice', 'customer');
        });
    }

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
                    'billing_name' => $client->billing_name ?: $client->name,
                    'billing_email' => $client->billing_email ?: $client->email,
                    'billing_phone' => $client->billing_phone ?: $client->phone,
                    'billing_vat' => $client->billing_vat,
                    'billing_address' => $client->billing_address,
                    'billing_postal_code' => $client->billing_postal_code,
                    'billing_city' => $client->billing_city,
                    'billing_country' => $client->billing_country,
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

    public function createPendingInvoiceCheckout(
        Client $client,
        iterable $invoices,
        string $successUrl,
        string $cancelBaseUrl
    ): array {
        return DB::transaction(function () use ($client, $invoices, $successUrl, $cancelBaseUrl) {
            $invoiceIds = collect($invoices)
                ->map(fn ($invoice) => (int) ($invoice instanceof Invoice ? $invoice->id : $invoice))
                ->filter(fn ($id) => $id > 0)
                ->unique()
                ->values();

            $lockedInvoices = Invoice::query()
                ->where('client_id', $client->id)
                ->whereIn('id', $invoiceIds)
                ->lockForUpdate()
                ->get();

            if ($lockedInvoices->count() !== $invoiceIds->count()) {
                abort(422, 'Existem documentos inválidos na seleção.');
            }

            if ($lockedInvoices->contains(fn (Invoice $invoice) => $invoice->status !== 'pendente')) {
                abort(422, 'Só podes pagar documentos pendentes.');
            }

            if ($lockedInvoices->contains(fn (Invoice $invoice) => data_get($invoice->payment_metadata, 'status') === 'pending')) {
                abort(422, 'Já existe um checkout pendente para pelo menos um dos documentos selecionados.');
            }

            $requestedAmountCents = $lockedInvoices->sum(
                fn (Invoice $invoice) => (int) round(((float) $invoice->total) * 100)
            );

            if ($requestedAmountCents <= 0) {
                abort(422, 'O valor total dos documentos selecionados é inválido.');
            }

            $grossAmountCents = $this->stripeTerminalService->calculateGrossAmountCents($requestedAmountCents);
            $surchargeAmountCents = max(0, $grossAmountCents - $requestedAmountCents);
            $cancelToken = (string) Str::uuid();

            $session = $this->createInvoiceCheckoutSession(
                $client,
                $lockedInvoices,
                $requestedAmountCents,
                $grossAmountCents,
                $surchargeAmountCents,
                $successUrl,
                $cancelBaseUrl.(str_contains($cancelBaseUrl, '?') ? '&' : '?').'token='.$cancelToken,
                ['cancel_token' => $cancelToken],
            );

            $metadata = [
                'status' => 'pending',
                'payment_type' => 'invoice_checkout',
                'cancel_token' => $cancelToken,
                'invoice_ids' => $lockedInvoices->pluck('id')->all(),
                'invoice_count' => $lockedInvoices->count(),
                'requested_amount' => round($requestedAmountCents / 100, 2),
                'gross_amount' => round($grossAmountCents / 100, 2),
                'surcharge_amount' => round($surchargeAmountCents / 100, 2),
                'surcharge_percent' => $this->stripeTerminalService->surchargePercent(),
                'surcharge_fixed' => $this->stripeTerminalService->surchargeFixed(),
            ];

            foreach ($lockedInvoices as $invoice) {
                $invoice->forceFill([
                    'payment_provider' => 'stripe',
                    'payment_reference' => $session->id,
                    'payment_metadata' => $metadata,
                ])->save();
            }

            return [
                'session' => $session,
                'invoices' => $lockedInvoices->fresh(),
                'cancel_token' => $cancelToken,
                'requested_amount' => round($requestedAmountCents / 100, 2),
                'gross_amount' => round($grossAmountCents / 100, 2),
                'surcharge_amount' => round($surchargeAmountCents / 100, 2),
                'invoice_count' => $lockedInvoices->count(),
            ];
        });
    }

    public function createInvoiceCheckoutSession(
        Client $client,
        Collection $invoices,
        int $requestedAmountCents,
        int $grossAmountCents,
        int $surchargeAmountCents,
        string $successUrl,
        string $cancelUrl,
        array $metadata = []
    ): Session {
        $stripe = $this->client();
        $customer = $this->ensureCustomer($stripe, $client);

        $lineItems = $invoices
            ->sortBy('issued_at')
            ->map(function (Invoice $invoice) use ($client) {
                return [
                    'quantity' => 1,
                    'price_data' => [
                        'currency' => 'eur',
                        'unit_amount' => (int) round(((float) $invoice->total) * 100),
                        'product_data' => [
                            'name' => 'Fatura '.$invoice->number,
                            'metadata' => [
                                'client_id' => (string) $client->id,
                                'invoice_id' => (string) $invoice->id,
                                'invoice_number' => (string) $invoice->number,
                            ],
                        ],
                    ],
                ];
            })
            ->values()
            ->all();

        if ($surchargeAmountCents > 0) {
            $lineItems[] = [
                'quantity' => 1,
                'price_data' => [
                    'currency' => 'eur',
                    'unit_amount' => $surchargeAmountCents,
                    'product_data' => [
                        'name' => 'Taxa de pagamento',
                        'description' => 'Sobretaxa configurada no CRM',
                    ],
                ],
            ];
        }

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
            'line_items' => $lineItems,
            'metadata' => [
                'client_id' => (string) $client->id,
                'invoice_ids' => $invoices->pluck('id')->implode(','),
                'invoice_numbers' => $invoices->pluck('number')->implode(','),
                'invoice_count' => (string) $invoices->count(),
                'requested_amount_cents' => (string) $requestedAmountCents,
                'gross_amount_cents' => (string) $grossAmountCents,
                'surcharge_amount_cents' => (string) $surchargeAmountCents,
                'source' => 'flutter_invoices',
                ...$metadata,
            ],
        ]);
    }

    public function syncPendingForClient(Client $client): void
    {
        if (! $this->isConfigured()) {
            return;
        }

        $transactions = WalletTransaction::query()
            ->where('payment_provider', 'stripe')
            ->whereHas('wallet', fn ($query) => $query->where('client_id', $client->id))
            ->where('payment_metadata->status', 'pending')
            ->get();

        foreach ($transactions as $transaction) {
            $this->syncPendingTransaction($transaction);
        }

        $references = Invoice::query()
            ->where('client_id', $client->id)
            ->where('payment_provider', 'stripe')
            ->where('payment_metadata->status', 'pending')
            ->whereNotNull('payment_reference')
            ->pluck('payment_reference')
            ->filter()
            ->unique();

        foreach ($references as $reference) {
            $this->syncPendingInvoiceReference((string) $reference);
        }
    }

    public function syncCheckoutSession(string $sessionId): void
    {
        $transaction = WalletTransaction::where('payment_reference', $sessionId)->first();
        if ($transaction) {
            $this->syncPendingTransaction($transaction);
            return;
        }

        $this->syncPendingInvoiceReference($sessionId);
    }

    public function syncPaymentIntent(string $paymentIntentId): void
    {
        $transaction = WalletTransaction::where('payment_reference', $paymentIntentId)->first();
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
            $this->cleanupPendingInvoicesByToken($token, true);
            return;
        }

        $this->cleanupPendingTransaction($transaction, true);
    }

    public function cancelPaymentIntent(string $paymentIntentId): void
    {
        $transaction = WalletTransaction::query()
            ->where('payment_provider', 'stripe')
            ->where('payment_reference', $paymentIntentId)
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
        if ($transaction) {
            if (in_array($eventType, ['checkout.session.completed', 'checkout.session.async_payment_succeeded'], true)
                && ($session['payment_status'] ?? null) === 'paid') {
                $this->markPendingTransactionPaid($transaction, $session);
                return;
            }

            if (in_array($eventType, ['checkout.session.expired', 'checkout.session.async_payment_failed'], true)) {
                $this->cleanupPendingTransaction($transaction, false);
            }

            return;
        }

        if (in_array($eventType, ['checkout.session.completed', 'checkout.session.async_payment_succeeded'], true)
            && ($session['payment_status'] ?? null) === 'paid') {
            $this->markPendingInvoicesPaidByReference($reference, $session);
            return;
        }

        if (in_array($eventType, ['checkout.session.expired', 'checkout.session.async_payment_failed'], true)) {
            $this->cleanupPendingInvoicesByReference($reference, false);
        }
    }

    public function handleWebhookPaymentIntent(array $paymentIntent, string $eventType): void
    {
        $reference = $paymentIntent['id'] ?? null;
        if (! is_string($reference) || $reference === '') {
            return;
        }

        $transaction = WalletTransaction::where('payment_reference', $reference)->first();
        if (! $transaction) {
            return;
        }

        if ($eventType === 'payment_intent.succeeded' && ($paymentIntent['status'] ?? null) === 'succeeded') {
            $this->markPendingTransactionPaidFromPaymentIntent($transaction, $paymentIntent);
            return;
        }

        if (in_array($eventType, ['payment_intent.payment_failed', 'payment_intent.canceled'], true)) {
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
        return $this->packPurchaseService->productLabel($product, $packItem, 1);
    }

    private function syncPendingTransaction(WalletTransaction $transaction): void
    {
        if (! $transaction->payment_reference) {
            return;
        }

        if (str_starts_with($transaction->payment_reference, 'pi_')) {
            $paymentIntent = $this->client()->paymentIntents->retrieve($transaction->payment_reference, []);
            $data = $paymentIntent->toArray();
            $status = $data['status'] ?? null;

            if ($status === 'succeeded') {
                $this->markPendingTransactionPaidFromPaymentIntent($transaction, $data);
                return;
            }

            if (in_array($status, ['canceled', 'requires_payment_method'], true)) {
                $this->cleanupPendingTransaction($transaction, false);
            }

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

    private function syncPendingInvoiceReference(string $reference): void
    {
        if ($reference === '') {
            return;
        }

        $invoices = $this->pendingInvoicesByReference($reference);
        if ($invoices->isEmpty()) {
            return;
        }

        $session = $this->client()->checkout->sessions->retrieve($reference, []);
        $data = $session->toArray();
        $status = $data['status'] ?? null;
        $paymentStatus = $data['payment_status'] ?? null;

        if ($status === 'complete' && $paymentStatus === 'paid') {
            $this->markPendingInvoicesPaid($invoices, $data);
            return;
        }

        if ($status === 'expired') {
            $this->cleanupPendingInvoices($invoices, false);
        }
    }

    private function markPendingTransactionPaidFromPaymentIntent(WalletTransaction $transaction, array $paymentIntent): void
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

        DB::transaction(function () use ($transaction, $paymentIntent, $metadata, $product, $packItem, $wallet, $client) {
            $quantity = max(1, (int) ($metadata['quantity'] ?? data_get($paymentIntent, 'metadata.quantity', 1)));
            $seconds = (int) round(((float) $packItem->hours) * 3600 * $quantity);
            $billing = $this->billingSnapshot($client);
            $wantsInvoice = ! empty($billing['billing_vat']);

            $transaction->seconds = $seconds;
            $transaction->description = 'Compra Stripe: '.$this->productLabel($product, $packItem);
            $transaction->payment_metadata = array_merge($metadata, [
                'status' => 'paid',
                'wants_invoice' => $wantsInvoice,
                'billing' => $billing,
                'customer' => $paymentIntent['customer'] ?? null,
                'payment_intent' => $paymentIntent['id'] ?? null,
                'last_payment_error' => data_get($paymentIntent, 'last_payment_error.message'),
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
                        'payment_method' => 'Stripe Payment Sheet',
                        'payment_account' => $wantsInvoice
                            ? 'Documento com NIF solicitado'
                            : 'Sem pedido de documento com NIF',
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
        });
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
            $billing = $this->syncBillingProfile($client, $session);
            $wantsInvoice = ! empty($billing['billing_vat']);

            $transaction->seconds = $seconds;
            $transaction->description = 'Compra Stripe: '.$this->productLabel($product, $packItem);
            $transaction->payment_metadata = array_merge($metadata, [
                'status' => 'paid',
                'wants_invoice' => $wantsInvoice,
                'billing' => $billing,
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
                        'payment_account' => $wantsInvoice
                            ? 'Documento com NIF solicitado'
                            : 'Sem pedido de documento com NIF',
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
        });
    }

    private function cleanupPendingTransaction(WalletTransaction $transaction, bool $expireRemoteIntent): void
    {
        $metadata = is_array($transaction->payment_metadata) ? $transaction->payment_metadata : [];
        if (($metadata['status'] ?? null) === 'paid') {
            return;
        }

        if ($expireRemoteIntent && $transaction->payment_reference) {
            if (str_starts_with($transaction->payment_reference, 'pi_')) {
                $intent = $this->client()->paymentIntents->retrieve($transaction->payment_reference, []);
                if (in_array($intent->status ?? null, ['requires_payment_method', 'requires_confirmation', 'requires_action', 'processing'], true)) {
                    $this->client()->paymentIntents->cancel($transaction->payment_reference, []);
                }
            } else {
                $session = $this->client()->checkout->sessions->retrieve($transaction->payment_reference, []);
                if (($session->status ?? null) === 'open') {
                    $this->client()->checkout->sessions->expire($transaction->payment_reference, []);
                }
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

    private function pendingInvoicesByReference(string $reference): Collection
    {
        return Invoice::query()
            ->where('payment_provider', 'stripe')
            ->where('payment_reference', $reference)
            ->where('payment_metadata->status', 'pending')
            ->get();
    }

    private function pendingInvoicesByToken(string $token): Collection
    {
        return Invoice::query()
            ->where('payment_provider', 'stripe')
            ->where('payment_metadata->cancel_token', $token)
            ->where('payment_metadata->status', 'pending')
            ->get();
    }

    private function markPendingInvoicesPaidByReference(string $reference, array $session): void
    {
        $invoices = $this->pendingInvoicesByReference($reference);
        if ($invoices->isEmpty()) {
            return;
        }

        $this->markPendingInvoicesPaid($invoices, $session);
    }

    private function markPendingInvoicesPaid(Collection $invoices, array $session): void
    {
        $firstInvoice = $invoices->first();
        if (! $firstInvoice instanceof Invoice) {
            return;
        }

        $client = Client::find($firstInvoice->client_id);
        if (! $client) {
            return;
        }

        DB::transaction(function () use ($invoices, $session, $client) {
            $billing = $this->syncBillingProfile($client, $session);
            $wantsInvoice = ! empty($billing['billing_vat']);

            foreach ($invoices as $invoice) {
                $metadata = is_array($invoice->payment_metadata) ? $invoice->payment_metadata : [];
                if (($metadata['status'] ?? null) === 'paid') {
                    continue;
                }

                $invoice->forceFill([
                    'status' => 'pago',
                    'paid_at' => now(),
                    'payment_method' => 'Stripe Checkout',
                    'payment_account' => $wantsInvoice
                        ? 'Documento com NIF solicitado'
                        : 'Sem pedido de documento com NIF',
                    'payment_provider' => 'stripe',
                    'payment_reference' => $session['id'] ?? $invoice->payment_reference,
                    'payment_metadata' => array_merge($metadata, [
                        'status' => 'paid',
                        'billing' => $billing,
                        'customer' => $session['customer'] ?? null,
                        'payment_intent' => $session['payment_intent'] ?? null,
                        'customer_details' => $session['customer_details'] ?? null,
                    ]),
                ])->save();
            }
        });
    }

    private function cleanupPendingInvoicesByReference(string $reference, bool $expireRemoteIntent): void
    {
        $invoices = $this->pendingInvoicesByReference($reference);
        if ($invoices->isEmpty()) {
            return;
        }

        $this->cleanupPendingInvoices($invoices, $expireRemoteIntent);
    }

    private function cleanupPendingInvoicesByToken(string $token, bool $expireRemoteIntent): void
    {
        $invoices = $this->pendingInvoicesByToken($token);
        if ($invoices->isEmpty()) {
            return;
        }

        $this->cleanupPendingInvoices($invoices, $expireRemoteIntent);
    }

    private function cleanupPendingInvoices(Collection $invoices, bool $expireRemoteIntent): void
    {
        $firstInvoice = $invoices->first();
        if (! $firstInvoice instanceof Invoice) {
            return;
        }

        $metadata = is_array($firstInvoice->payment_metadata) ? $firstInvoice->payment_metadata : [];
        if (($metadata['status'] ?? null) === 'paid') {
            return;
        }

        $reference = (string) ($firstInvoice->payment_reference ?? '');

        if ($reference !== '') {
            $session = $this->client()->checkout->sessions->retrieve($reference, []);
            if (($session->status ?? null) === 'complete' && ($session->payment_status ?? null) === 'paid') {
                $this->markPendingInvoicesPaid($invoices, $session->toArray());
                return;
            }

            if (! $expireRemoteIntent) {
                $session = null;
            }
        }

        if ($expireRemoteIntent && $reference !== '' && isset($session)) {
            if (($session->status ?? null) === 'open') {
                $this->client()->checkout->sessions->expire($reference, []);
            }
        }

        DB::transaction(function () use ($invoices) {
            foreach ($invoices as $invoice) {
                $invoice->forceFill([
                    'payment_provider' => null,
                    'payment_reference' => null,
                    'payment_metadata' => null,
                ])->save();
            }
        });
    }

    private function updateBillingProfile(Client $client, array $billing): void
    {
        $payload = array_filter([
            'billing_name' => $this->cleanText($billing['billing_name'] ?? null),
            'billing_email' => $this->cleanText($billing['billing_email'] ?? null),
            'billing_phone' => $this->digitsOnly($billing['billing_phone'] ?? null),
            'billing_vat' => $this->digitsOnly($billing['billing_vat'] ?? null),
            'billing_address' => $this->cleanText($billing['billing_address'] ?? null),
            'billing_postal_code' => $this->cleanText($billing['billing_postal_code'] ?? null),
            'billing_city' => $this->cleanText($billing['billing_city'] ?? null),
            'billing_country' => isset($billing['billing_country'])
                ? strtoupper((string) $billing['billing_country'])
                : null,
        ], fn ($value) => $value !== null && $value !== '');

        if ($payload !== []) {
            $client->forceFill($payload)->save();
        }
    }

    private function syncBillingProfile(Client $client, array $session): array
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

        return $this->billingSnapshot($client->fresh());
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

    private function cleanText(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $clean = trim($value);

        return $clean === '' ? null : $clean;
    }

    private function digitsOnly(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $digits = preg_replace('/\D+/', '', $value);

        return $digits === '' ? null : $digits;
    }

    private function client(): StripeClient
    {
        return new StripeClient([
            'api_key' => (string) config('services.stripe.secret_key'),
            'stripe_version' => (string) config('services.stripe.api_version'),
        ]);
    }

    private function isConfigured(): bool
    {
        return trim((string) config('services.stripe.secret_key')) !== '';
    }
}
