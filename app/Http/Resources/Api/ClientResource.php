<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'company' => $this->company,
            'email' => $this->email,
            'phone' => $this->phone,
            'vat' => $this->vat,
            'address' => $this->address,
            'billing_name' => $this->billing_name,
            'billing_email' => $this->billing_email,
            'billing_phone' => $this->billing_phone,
            'billing_vat' => $this->billing_vat,
            'billing_address' => $this->billing_address,
            'billing_postal_code' => $this->billing_postal_code,
            'billing_city' => $this->billing_city,
            'billing_country' => $this->billing_country,
            'notes' => $this->notes,
            'internal_notes' => $this->internal_notes,
            'hourly_rate' => $this->hourly_rate,
            'projects' => ProjectResource::collection($this->whenLoaded('projects')),
            'invoices' => InvoiceResource::collection($this->whenLoaded('invoices')),
            'credential_objects' => ClientCredentialObjectResource::collection($this->whenLoaded('credentialObjects')),
            'credentials' => ClientCredentialResource::collection($this->whenLoaded('credentials')),
            'wallet' => $this->when(
                $this->relationLoaded('wallet') && $this->wallet,
                fn () => new WalletResource($this->wallet)
            ),
            'user' => $this->when(
                $this->relationLoaded('user') && $this->user,
                fn () => new UserResource($this->user)
            ),
            'stripe_customer_id' => $this->stripe_customer_id,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
