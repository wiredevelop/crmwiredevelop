<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Intervention;
use App\Models\Wallet;
use Inertia\Inertia;
use Inertia\Response;

class ClientWalletController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function show(): Response
    {
        abort_unless($this->isClientUser(), 403);

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

        return Inertia::render('Wallet/Show', [
            'wallet' => $wallet,
            'interventions' => $interventions,
        ]);
    }
}
