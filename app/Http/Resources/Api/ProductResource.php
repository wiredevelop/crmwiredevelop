<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'name' => $this->name,
            'slug' => $this->slug,
            'short_description' => $this->short_description,
            'content_html' => $this->content_html,
            'price' => $this->price,
            'active' => (bool) $this->active,
            'show_payment_methods' => (bool) $this->show_payment_methods,
            'meta' => ProductMetaResource::collection($this->whenLoaded('meta')),
            'pack_items' => PackItemResource::collection($this->whenLoaded('packItems')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
