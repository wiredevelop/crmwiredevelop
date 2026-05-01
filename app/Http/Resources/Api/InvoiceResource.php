<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvoiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'client_id' => $this->client_id,
            'project_id' => $this->project_id,
            'number' => $this->number,
            'total' => $this->total,
            'status' => $this->status,
            'issued_at' => $this->issued_at,
            'due_at' => $this->due_at,
            'payment_method' => $this->payment_method,
            'payment_account' => $this->payment_account,
            'payment_provider' => $this->payment_provider,
            'payment_reference' => $this->payment_reference,
            'payment_metadata' => $this->payment_metadata,
            'paid_at' => $this->paid_at,
            'is_installment' => (bool) $this->is_installment,
            'installment_count' => $this->installment_count,
            'client' => $this->when(
                $this->relationLoaded('client') && $this->client,
                fn () => new ClientResource($this->client)
            ),
            'project' => $this->when(
                $this->relationLoaded('project') && $this->project,
                fn () => new ProjectResource($this->project)
            ),
            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'installments' => InstallmentResource::collection($this->whenLoaded('installments')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
