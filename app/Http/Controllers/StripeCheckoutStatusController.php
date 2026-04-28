<?php

namespace App\Http\Controllers;

use App\Support\StripeCheckoutService;
use Illuminate\Http\Request;
use Illuminate\View\View;

class StripeCheckoutStatusController extends Controller
{
    public function success(Request $request, StripeCheckoutService $stripe): View
    {
        if ($request->filled('session_id')) {
            $stripe->syncCheckoutSession($request->string('session_id')->toString());
        }

        return view('stripe-checkout-status', [
            'title' => 'Pagamento concluído',
            'message' => 'O pagamento foi concluído. Já pode voltar à app e atualizar a carteira.',
        ]);
    }

    public function cancel(Request $request, StripeCheckoutService $stripe): View
    {
        if ($request->filled('token')) {
            $stripe->cancelByToken($request->string('token')->toString());
        }

        return view('stripe-checkout-status', [
            'title' => 'Pagamento cancelado',
            'message' => 'O checkout foi cancelado. O documento pendente foi removido e pode voltar à app.',
        ]);
    }
}
