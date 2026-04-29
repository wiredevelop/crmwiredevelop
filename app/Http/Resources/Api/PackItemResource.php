<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PackItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'hours' => $this->hours,
            'normal_price' => $this->normal_price,
            'pack_price' => $this->pack_price,
            'validity_months' => $this->validity_months,
            'featured' => (bool) $this->featured,
            'order' => $this->order,
        ];
    }
}
