<?php

namespace App\Http\Controllers;

use App\Support\StripeCheckoutService;
use Illuminate\Http\Request;
use Illuminate\View\View;

class StripeCheckoutStatusController extends Controller
{
    public function success(Request $request, StripeCheckoutService $stripe): View
    {
        $sessionId = $request->string('session_id')->toString();

        if ($request->filled('session_id')) {
            $stripe->syncCheckoutSession($sessionId);
        }

        return view('stripe-checkout-status', [
            'title' => 'Pagamento concluído',
            'message' => 'O pagamento foi concluído. O estado será sincronizado ao regressar à app.',
            'status' => 'success',
            'appUrl' => $this->appRedirectUrl(
                $request,
                'success',
                $sessionId,
                null
            ),
            'fallbackUrl' => $this->fallbackWalletUrl($request, 'success', $sessionId, null),
        ]);
    }

    public function cancel(Request $request, StripeCheckoutService $stripe): View
    {
        $token = $request->string('token')->toString();
        $sessionId = $request->string('session_id')->toString();

        if ($request->filled('token')) {
            $stripe->cancelByToken($token);
        }

        return view('stripe-checkout-status', [
            'title' => 'Pagamento cancelado',
            'message' => 'O checkout foi cancelado. Pode regressar à app.',
            'status' => 'cancel',
            'appUrl' => $this->appRedirectUrl(
                $request,
                'cancel',
                $sessionId,
                $token
            ),
            'fallbackUrl' => $this->fallbackWalletUrl($request, 'cancel', $sessionId, $token),
        ]);
    }

    private function appRedirectUrl(Request $request, string $status, string $sessionId = '', ?string $token = null): ?string
    {
        if ($request->query('source') !== 'mobile_app') {
            return null;
        }

        $query = array_filter([
            'status' => $status,
            'target' => $request->query('target', 'wallet'),
            'session_id' => $sessionId !== '' ? $sessionId : null,
            'token' => $token,
        ], fn ($value) => $value !== null && $value !== '');

        return 'wirecrm://wallet/checkout-return?'.http_build_query($query);
    }

    private function fallbackWalletUrl(Request $request, string $status, string $sessionId = '', ?string $token = null): ?string
    {
        if (! $request->user()?->client) {
            return null;
        }

        if ($request->query('target') === 'invoices') {
            return route('invoices.index', array_filter([
                'stripe_status' => $status,
                'session_id' => $sessionId !== '' ? $sessionId : null,
                'token' => $token,
            ], fn ($value) => $value !== null && $value !== ''));
        }

        return route('wallet.show', array_filter([
            'stripe_status' => $status,
            'session_id' => $sessionId !== '' ? $sessionId : null,
            'token' => $token,
        ], fn ($value) => $value !== null && $value !== ''));
    }
}
