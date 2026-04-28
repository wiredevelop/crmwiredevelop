<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class QuoteProduct extends Model
{
    protected $fillable = [
        'quote_id',
        'product_id',
        'type',
        'name',
        'slug',
        'short_description',
        'content_html',
        'price',
        'pack_items',
        'info_fields',
        'order',
    ];

    protected $casts = [
        'pack_items' => 'array',
        'info_fields' => 'array',
    ];

    public function quote()
    {
        return $this->belongsTo(Quote::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
