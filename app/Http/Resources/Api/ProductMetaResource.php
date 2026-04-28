<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductMetaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'label' => $this->label,
            'key' => $this->key,
            'type' => $this->type,
            'value' => $this->value,
            'show_front' => (bool) $this->show_front,
            'order' => $this->order,
        ];
    }
}
