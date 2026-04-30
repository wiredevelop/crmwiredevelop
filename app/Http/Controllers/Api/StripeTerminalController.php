<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Support\StripeTerminalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StripeTerminalController extends Controller
{
    use RespondsWithJson;

    public function connectionToken(StripeTerminalService $terminal): JsonResponse
    {
        if (! $this->hasStripeSecretKey()) {
            return $this->error('Stripe Terminal indisponível: STRIPE_SECRET_KEY em falta.', [], 503);
        }

        $locationId = $terminal->terminalLocationId();

        if (! $locationId) {
            return $this->error('STRIPE_TERMINAL_LOCATION_ID não configurado.', [], 503);
        }

        $token = $terminal->createConnectionToken();

        return $this->success([
            'secret' => $token->secret,
            'location_id' => $locationId,
            'surcharge_percent' => $terminal->surchargePercent(),
            'surcharge_fixed' => $terminal->surchargeFixed(),
        ]);
    }

    public function paymentIntent(Request $request, StripeTerminalService $terminal): JsonResponse
    {
        if (! $this->hasStripeSecretKey()) {
            return $this->error('Stripe Terminal indisponível: STRIPE_SECRET_KEY em falta.', [], 503);
        }

        if (! $terminal->terminalLocationId()) {
            return $this->error('STRIPE_TERMINAL_LOCATION_ID não configurado.', [], 503);
        }

        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'currency' => ['required', 'string', 'size:3'],
            'description' => ['nullable', 'string', 'max:255'],
        ]);

        $created = $terminal->createPaymentIntent(
            $request->user(),
            (int) $data['amount'],
            strtolower((string) $data['currency']),
            $data['description'] ?? null,
        );

        return $this->success([
            'payment_intent_id' => $created['payment_intent']->id,
            'client_secret' => $created['payment_intent']->client_secret,
            'terminal_payment_id' => $created['terminal_payment']->id,
            'requested_amount' => (float) ($data['amount'] / 100),
            'gross_amount' => (float) $created['terminal_payment']->gross_amount,
            'surcharge_amount' => round((float) $created['terminal_payment']->gross_amount - ((int) $data['amount'] / 100), 2),
            'fee_amount' => (float) $created['terminal_payment']->fee_amount,
            'net_amount' => (float) $created['terminal_payment']->net_amount,
            'currency' => $created['terminal_payment']->currency,
        ], 'PaymentIntent Terminal criado.');
    }

    public function sync(Request $request, StripeTerminalService $terminal): JsonResponse
    {
        if (! $this->hasStripeSecretKey()) {
            return $this->error('Stripe Terminal indisponível: STRIPE_SECRET_KEY em falta.', [], 503);
        }

        $data = $request->validate([
            'payment_intent_id' => ['required', 'string', 'max:255'],
        ]);

        $payment = $terminal->syncPaymentIntent($data['payment_intent_id']);
        if (! $payment) {
            return $this->error('Pagamento Terminal não encontrado.', [], 404);
        }

        return $this->success([
            'payment' => [
                'id' => $payment->id,
                'payment_intent_id' => $payment->payment_intent_id,
                'status' => $payment->status,
                'gross_amount' => (float) $payment->gross_amount,
                'fee_amount' => (float) $payment->fee_amount,
                'net_amount' => (float) $payment->net_amount,
                'currency' => $payment->currency,
                'charge_id' => $payment->charge_id,
                'card_brand' => $payment->card_brand,
                'card_last4' => $payment->card_last4,
                'paid_at' => $payment->paid_at?->toIso8601String(),
            ],
        ]);
    }

    private function hasStripeSecretKey(): bool
    {
        return trim((string) config('services.stripe.secret_key')) !== '';
    }
}
