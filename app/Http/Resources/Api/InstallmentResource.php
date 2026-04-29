<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstallmentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'project_id' => $this->project_id,
            'client_id' => $this->client_id,
            'invoice_id' => $this->invoice_id,
            'amount' => $this->amount,
            'note' => $this->note,
            'paid_at' => $this->paid_at,
            'project' => $this->when(
                $this->relationLoaded('project') && $this->project,
                fn () => new ProjectResource($this->project)
            ),
            'client' => $this->when(
                $this->relationLoaded('client') && $this->client,
                fn () => new ClientResource($this->client)
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
