<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Support\StripeCheckoutService;
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

        if (in_array($event->type, ['checkout.session.completed', 'checkout.session.expired', 'checkout.session.async_payment_failed', 'checkout.session.async_payment_succeeded'], true)) {
            /** @var array<string, mixed> $session */
            $session = $event->data->object->toArray();
            app(StripeCheckoutService::class)->handleWebhookSession($session, $event->type);
        }

        return response()->json(['received' => true]);
    }
}
