<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProjectResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'client_id' => $this->client_id,
            'name' => $this->name,
            'type' => $this->type,
            'status' => $this->status,
            'is_hidden' => (bool) $this->is_hidden,
            'quote_id' => $this->quote_id,
            'client' => $this->when(
                $this->relationLoaded('client') && $this->client,
                fn () => new ClientResource($this->client)
            ),
            'quote' => $this->when(
                $this->relationLoaded('quote') && $this->quote,
                fn () => new QuoteResource($this->quote)
            ),
            'invoice' => $this->when(
                $this->relationLoaded('invoice') && $this->invoice,
                fn () => new InvoiceResource($this->invoice)
            ),
            'credentials' => ClientCredentialResource::collection($this->whenLoaded('credentials')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
