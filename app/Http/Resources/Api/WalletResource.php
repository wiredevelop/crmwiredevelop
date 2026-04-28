<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'client_id' => $this->client_id,
            'balance_seconds' => (int) $this->balance_seconds,
            'balance_amount' => $this->balance_amount,
            'client' => $this->when(
                $this->relationLoaded('client') && $this->client,
                fn () => new ClientResource($this->client)
            ),
            'transactions' => WalletTransactionResource::collection($this->whenLoaded('transactions')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
