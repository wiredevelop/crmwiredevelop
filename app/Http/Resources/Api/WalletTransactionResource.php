<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'wallet_id' => $this->wallet_id,
            'type' => $this->type,
            'seconds' => $this->seconds,
            'amount' => $this->amount,
            'description' => $this->description,
            'product_id' => $this->product_id,
            'pack_item_id' => $this->pack_item_id,
            'intervention_id' => $this->intervention_id,
            'transaction_at' => $this->transaction_at,
            'is_installment' => (bool) $this->is_installment,
            'installment_count' => $this->installment_count,
            'to_invoice' => (bool) $this->to_invoice,
            'invoice_id' => $this->invoice_id,
            'payment_provider' => $this->payment_provider,
            'payment_reference' => $this->payment_reference,
            'payment_metadata' => $this->payment_metadata,
            'product' => $this->when(
                $this->relationLoaded('product') && $this->product,
                fn () => new ProductResource($this->product)
            ),
            'pack_item' => $this->when(
                $this->relationLoaded('packItem') && $this->packItem,
                fn () => new PackItemResource($this->packItem)
            ),
            'intervention' => $this->when(
                $this->relationLoaded('intervention') && $this->intervention,
                fn () => new InterventionResource($this->intervention)
            ),
            'invoice' => $this->when(
                $this->relationLoaded('invoice') && $this->invoice,
                fn () => new InvoiceResource($this->invoice)
            ),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
