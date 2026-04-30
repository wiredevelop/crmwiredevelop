<?php

namespace App\Support;

use App\Models\Setting;
use App\Models\TerminalPayment;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Stripe\BalanceTransaction;
use Stripe\Charge;
use Stripe\PaymentIntent;
use Stripe\StripeClient;
use Stripe\Terminal\ConnectionToken;

class StripeTerminalService
{
    public function createConnectionToken(): ConnectionToken
    {
        return $this->client()->terminal->connectionTokens->create([]);
    }

    public function createPaymentIntent(
        User $user,
        int $amountCents,
        string $currency,
        ?string $description = null
    ): array {
        $grossAmountCents = $this->calculateGrossAmountCents($amountCents);
        $gross = round($grossAmountCents / 100, 2);
        $locationId = (string) config('services.stripe.terminal_location_id');

        return DB::transaction(function () use ($user, $amountCents, $grossAmountCents, $currency, $description, $gross, $locationId) {
            /** @var PaymentIntent $paymentIntent */
            $paymentIntent = $this->client()->paymentIntents->create([
                'amount' => $grossAmountCents,
                'currency' => strtolower($currency),
                'payment_method_types' => ['card_present'],
                'capture_method' => 'automatic',
                'description' => $description ?: 'Pagamento presencial WireDevelop',
                'metadata' => [
                    'source' => 'terminal_tap_to_pay',
                    'created_by_user_id' => (string) $user->id,
                    'location_id' => $locationId,
                    'requested_amount_cents' => (string) $amountCents,
                    'surcharge_percent' => (string) $this->surchargePercent(),
                    'surcharge_fixed' => (string) $this->surchargeFixed(),
                ],
            ]);

            $payment = TerminalPayment::create([
                'user_id' => $user->id,
                'payment_intent_id' => $paymentIntent->id,
                'location_id' => $locationId,
                'currency' => strtolower($currency),
                'gross_amount' => $gross,
                'fee_amount' => 0,
                'net_amount' => 0,
                'status' => 'pending',
                'description' => $description ?: 'Pagamento presencial WireDevelop',
                'metadata' => [
                    'requested_amount_cents' => $amountCents,
                    'gross_amount_cents' => $grossAmountCents,
                    'surcharge_percent' => $this->surchargePercent(),
                    'surcharge_fixed' => $this->surchargeFixed(),
                ],
            ]);

            $paymentIntent = $this->client()->paymentIntents->update($paymentIntent->id, [
                'metadata' => [
                    'source' => 'terminal_tap_to_pay',
                    'created_by_user_id' => (string) $user->id,
                    'location_id' => $locationId,
                    'terminal_payment_id' => (string) $payment->id,
                    'requested_amount_cents' => (string) $amountCents,
                    'surcharge_percent' => (string) $this->surchargePercent(),
                    'surcharge_fixed' => (string) $this->surchargeFixed(),
                ],
            ]);

            return [
                'payment_intent' => $paymentIntent,
                'terminal_payment' => $payment->fresh(),
            ];
        });
    }

    public function syncPaymentIntent(string $paymentIntentId): ?TerminalPayment
    {
        $payment = TerminalPayment::query()
            ->where('payment_intent_id', $paymentIntentId)
            ->first();

        if (! $payment) {
            return null;
        }

        /** @var PaymentIntent $paymentIntent */
        $paymentIntent = $this->client()->paymentIntents->retrieve($paymentIntentId, []);
        $data = $paymentIntent->toArray();
        [$chargeData, $balanceTransactionData] = $this->retrieveChargeAndBalanceTransaction($data);

        return $this->persistPaymentIntentState($payment, $data, $chargeData, $balanceTransactionData);
    }

    public function handleWebhookPaymentIntent(array $paymentIntent, string $eventType): ?TerminalPayment
    {
        if (($paymentIntent['metadata']['source'] ?? null) !== 'terminal_tap_to_pay') {
            return null;
        }

        $payment = TerminalPayment::query()
            ->where('payment_intent_id', $paymentIntent['id'] ?? '')
            ->first();

        if (! $payment) {
            return null;
        }

        [$chargeData, $balanceTransactionData] = $this->retrieveChargeAndBalanceTransaction($paymentIntent);

        if (in_array($eventType, ['payment_intent.succeeded', 'payment_intent.payment_failed', 'payment_intent.canceled'], true)) {
            return $this->persistPaymentIntentState($payment, $paymentIntent, $chargeData, $balanceTransactionData);
        }

        return $payment;
    }

    public function terminalLocationId(): ?string
    {
        $locationId = trim((string) config('services.stripe.terminal_location_id'));

        return $locationId === '' ? null : $locationId;
    }

    public function surchargePercent(): float
    {
        return max(0, (float) Setting::where('key', 'terminal_surcharge_percent')->value('value'));
    }

    public function surchargeFixed(): float
    {
        return max(0, (float) Setting::where('key', 'terminal_surcharge_fixed')->value('value'));
    }

    public function calculateGrossAmountCents(int $requestedAmountCents): int
    {
        if ($requestedAmountCents <= 0) {
            return $requestedAmountCents;
        }

        $requestedAmount = $requestedAmountCents / 100;
        $percent = $this->surchargePercent() / 100;
        $fixed = $this->surchargeFixed();

        if ($percent >= 1) {
            return $requestedAmountCents;
        }

        $gross = ($requestedAmount + $fixed) / max(0.000001, (1 - $percent));

        return (int) ceil($gross * 100);
    }

    private function persistPaymentIntentState(
        TerminalPayment $payment,
        array $paymentIntent,
        ?array $chargeData = null,
        ?array $balanceTransactionData = null
    ): TerminalPayment
    {
        $status = (string) ($paymentIntent['status'] ?? 'pending');
        $charge = $chargeData ?? $paymentIntent['charges']['data'][0] ?? null;
        $cardPresent = $charge['payment_method_details']['card_present'] ?? null;
        $feeAmount = array_key_exists('fee', $balanceTransactionData ?? [])
            ? round(((int) $balanceTransactionData['fee']) / 100, 2)
            : ($status === 'succeeded' ? (float) $payment->fee_amount : 0.0);
        $netAmount = array_key_exists('net', $balanceTransactionData ?? [])
            ? round(((int) $balanceTransactionData['net']) / 100, 2)
            : ($status === 'succeeded'
                ? round(((float) $payment->gross_amount) - $feeAmount, 2)
                : 0.0);

        $payment->forceFill([
            'status' => match ($status) {
                'succeeded' => 'paid',
                'canceled' => 'canceled',
                'requires_payment_method' => 'failed',
                default => $status,
            },
            'charge_id' => $charge['id'] ?? $payment->charge_id,
            'card_brand' => $cardPresent['brand'] ?? $payment->card_brand,
            'card_last4' => $cardPresent['last4'] ?? $payment->card_last4,
            'payment_method_type' => $charge['payment_method_details']['type'] ?? $payment->payment_method_type,
            'fee_amount' => $feeAmount,
            'net_amount' => $netAmount,
            'paid_at' => $status === 'succeeded' ? now() : $payment->paid_at,
            'metadata' => array_merge($payment->metadata ?? [], [
                'stripe_status' => $status,
                'payment_intent' => $paymentIntent,
                'charge' => $charge,
                'balance_transaction' => $balanceTransactionData,
            ]),
        ])->save();

        return $payment->fresh();
    }

    private function retrieveChargeAndBalanceTransaction(array $paymentIntent): array
    {
        $chargeId = (string) ($paymentIntent['latest_charge'] ?? ($paymentIntent['charges']['data'][0]['id'] ?? ''));

        if ($chargeId === '') {
            return [null, null];
        }

        /** @var Charge $charge */
        $charge = $this->client()->charges->retrieve($chargeId, [
            'expand' => ['balance_transaction', 'failure_balance_transaction'],
        ]);

        $balanceTransaction = $charge->balance_transaction;
        if (! $balanceTransaction instanceof BalanceTransaction) {
            $balanceTransaction = $charge->failure_balance_transaction;
        }

        return [
            $charge->toArray(),
            $balanceTransaction instanceof BalanceTransaction ? $balanceTransaction->toArray() : null,
        ];
    }

    private function client(): StripeClient
    {
        return new StripeClient([
            'api_key' => (string) config('services.stripe.secret_key'),
            'stripe_version' => (string) config('services.stripe.api_version'),
        ]);
    }
}
