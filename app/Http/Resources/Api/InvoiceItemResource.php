<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvoiceItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $isClientUser = (bool) $request->user()?->isClientUser();

        return [
            'id' => $this->id,
            'invoice_id' => $this->invoice_id,
            'description' => $this->description,
            'quantity' => $this->quantity,
            'unit_price' => $this->unit_price,
            'total' => $this->total,
            'source_type' => $this->source_type,
            'source_id' => $this->source_id,
            'source_transaction' => $this->when(
                $this->relationLoaded('sourceTransaction') && $this->sourceTransaction,
                fn () => [
                    'id' => $this->sourceTransaction->id,
                    'description' => $this->sourceTransaction->description,
                    'seconds' => $this->sourceTransaction->seconds,
                    'amount' => $isClientUser ? null : $this->sourceTransaction->amount,
                    'product' => ! $isClientUser && $this->sourceTransaction->relationLoaded('product') && $this->sourceTransaction->product
                        ? [
                            'id' => $this->sourceTransaction->product->id,
                            'name' => $this->sourceTransaction->product->name,
                            'type' => $this->sourceTransaction->product->type,
                        ]
                        : null,
                    'pack_item' => ! $isClientUser && $this->sourceTransaction->relationLoaded('packItem') && $this->sourceTransaction->packItem
                        ? [
                            'hours' => $this->sourceTransaction->packItem->hours,
                            'pack_price' => $this->sourceTransaction->packItem->pack_price,
                            'validity_months' => $this->sourceTransaction->packItem->validity_months,
                        ]
                        : null,
                    'intervention' => $this->sourceTransaction->relationLoaded('intervention') && $this->sourceTransaction->intervention
                        ? [
                            'id' => $this->sourceTransaction->intervention->id,
                            'type' => $this->sourceTransaction->intervention->type,
                            'status' => $this->sourceTransaction->intervention->status,
                            'notes' => $this->sourceTransaction->intervention->notes,
                            'finish_notes' => $this->sourceTransaction->intervention->finish_notes,
                            'is_pack' => (bool) $this->sourceTransaction->intervention->is_pack,
                            'hourly_rate' => $isClientUser ? null : $this->sourceTransaction->intervention->hourly_rate,
                            'total_seconds' => (int) $this->sourceTransaction->intervention->total_seconds,
                        ]
                        : null,
                ]
            ),
            'source_project' => $this->when(
                ! $isClientUser
                && $this->source_type === 'project'
                && $this->relationLoaded('sourceProject')
                && $this->sourceProject,
                fn () => [
                    'id' => $this->sourceProject->id,
                    'name' => $this->sourceProject->name,
                    'status' => $this->sourceProject->status,
                    'type' => $this->sourceProject->type,
                ]
            ),
        ];
    }
}
