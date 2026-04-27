<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\InterventionResource;
use App\Http\Resources\Api\WalletResource;
use App\Http\Resources\Api\WalletTransactionResource;
use App\Models\Intervention;
use App\Models\Wallet;
use Illuminate\Http\JsonResponse;

class ClientWalletApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function show(): JsonResponse
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

        return $this->success([
            'wallet' => new WalletResource($wallet),
            'transactions' => WalletTransactionResource::collection($wallet->transactions),
            'interventions' => InterventionResource::collection($interventions),
        ]);
    }
}
