<?php

namespace App\Support;

use App\Models\TerminalPayment;
use App\Models\User;
use Illuminate\Support\Facades\DB;
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
        $gross = round($amountCents / 100, 2);
        $fee = $this->calculateFee($gross);
        $net = round($gross - $fee, 2);
        $locationId = (string) config('services.stripe.terminal_location_id');

        return DB::transaction(function () use ($user, $amountCents, $currency, $description, $gross, $fee, $net, $locationId) {
            /** @var PaymentIntent $paymentIntent */
            $paymentIntent = $this->client()->paymentIntents->create([
                'amount' => $amountCents,
                'currency' => strtolower($currency),
                'payment_method_types' => ['card_present'],
                'capture_method' => 'automatic',
                'description' => $description ?: 'Pagamento presencial WireDevelop',
                'metadata' => [
                    'source' => 'terminal_tap_to_pay',
                    'created_by_user_id' => (string) $user->id,
                    'location_id' => $locationId,
                ],
            ]);

            $payment = TerminalPayment::create([
                'user_id' => $user->id,
                'payment_intent_id' => $paymentIntent->id,
                'location_id' => $locationId,
                'currency' => strtolower($currency),
                'gross_amount' => $gross,
                'fee_amount' => $fee,
                'net_amount' => $net,
                'status' => 'pending',
                'description' => $description ?: 'Pagamento presencial WireDevelop',
                'metadata' => [
                    'amount_cents' => $amountCents,
                ],
            ]);

            $paymentIntent = $this->client()->paymentIntents->update($paymentIntent->id, [
                'metadata' => [
                    'source' => 'terminal_tap_to_pay',
                    'created_by_user_id' => (string) $user->id,
                    'location_id' => $locationId,
                    'terminal_payment_id' => (string) $payment->id,
                ],
            ]);

            return [
                'payment_intent' => $paymentIntent,
                'terminal_payment' => $payment->fresh(),
                'fee_percent' => $this->feePercent(),
                'fee_fixed' => $this->feeFixed(),
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

        return $this->persistPaymentIntentState($payment, $data);
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

        if (in_array($eventType, ['payment_intent.succeeded', 'payment_intent.payment_failed', 'payment_intent.canceled'], true)) {
            return $this->persistPaymentIntentState($payment, $paymentIntent);
        }

        return $payment;
    }

    public function terminalLocationId(): ?string
    {
        $locationId = trim((string) config('services.stripe.terminal_location_id'));

        return $locationId === '' ? null : $locationId;
    }

    public function feePercent(): float
    {
        return max(0, (float) config('services.stripe.terminal_fee_percent', 0));
    }

    public function feeFixed(): float
    {
        return max(0, (float) config('services.stripe.terminal_fee_fixed', 0));
    }

    private function calculateFee(float $grossAmount): float
    {
        $percentFee = round($grossAmount * ($this->feePercent() / 100), 2);

        return round($percentFee + $this->feeFixed(), 2);
    }

    private function persistPaymentIntentState(TerminalPayment $payment, array $paymentIntent): TerminalPayment
    {
        $status = (string) ($paymentIntent['status'] ?? 'pending');
        $charge = $paymentIntent['charges']['data'][0] ?? null;
        $cardPresent = $charge['payment_method_details']['card_present'] ?? null;

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
            'paid_at' => $status === 'succeeded' ? now() : $payment->paid_at,
            'metadata' => array_merge($payment->metadata ?? [], [
                'stripe_status' => $status,
                'payment_intent' => $paymentIntent,
            ]),
        ])->save();

        return $payment->fresh();
    }

    private function client(): StripeClient
    {
        return new StripeClient([
            'api_key' => (string) config('services.stripe.secret_key'),
            'stripe_version' => (string) config('services.stripe.api_version'),
        ]);
    }
}
