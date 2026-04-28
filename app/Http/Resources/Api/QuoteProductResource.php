<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class QuoteProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'quote_id' => $this->quote_id,
            'product_id' => $this->product_id,
            'type' => $this->type,
            'name' => $this->name,
            'slug' => $this->slug,
            'short_description' => $this->short_description,
            'content_html' => $this->content_html,
            'price' => $this->price,
            'pack_items' => $this->pack_items,
            'info_fields' => $this->info_fields,
            'order' => $this->order,
        ];
    }
}
