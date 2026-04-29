<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Intervention;
use App\Models\Wallet;
use App\Support\CompanySettings;
use App\Support\StripeCheckoutService;
use Inertia\Inertia;
use Inertia\Response;

class ClientWalletController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function show(): Response
    {
        abort_unless($this->isClientUser(), 403);

        $stripeAvailable = (bool) config('services.stripe.secret_key')
            && (bool) config('services.stripe.public_key');

        if ($stripeAvailable && request()->user()?->client) {
            app(StripeCheckoutService::class)->syncPendingForClient(request()->user()->client);
        }

        $wallet = Wallet::firstOrCreate(
            ['client_id' => $this->currentClientId()],
            ['balance_seconds' => 0, 'balance_amount' => 0]
        );

        $wallet->load([
            'client',
            'transactions' => fn ($query) => $query
                ->with([
                    'product:id,name',
                    'packItem:id,product_id,hours,pack_price,validity_months',
                    'intervention:id,type,status,notes,finish_notes,is_pack,started_at,ended_at,total_seconds',
                    'invoice:id,number,status',
                ])
                ->orderByDesc('transaction_at'),
        ]);

        $interventions = Intervention::query()
            ->where('client_id', $this->currentClientId())
            ->orderByDesc('started_at')
            ->get();
        $company = CompanySettings::get();

        return Inertia::render('Wallet/Show', [
            'wallet' => $wallet,
            'interventions' => $interventions,
            'checkoutMethod' => in_array($company['client_checkout_method'] ?? null, ['stripe', 'manual'], true)
                ? $company['client_checkout_method']
                : 'stripe',
            'stripeAvailable' => $stripeAvailable,
            'manualPayment' => [
                'notes' => $company['payment_notes'] ?? '',
                'methods' => is_array($company['payment_methods'] ?? null) ? $company['payment_methods'] : [],
            ],
        ]);
    }
}
