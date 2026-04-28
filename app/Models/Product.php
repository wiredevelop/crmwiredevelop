<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Product extends Model
{
    protected $fillable = [
        'type',
        'name',
        'slug',
        'short_description',
        'content_html',
        'price',
        'active',
        'show_payment_methods',
    ];

    protected static function booted()
    {
        static::creating(function ($product) {
            if (! $product->slug) {
                $product->slug = Str::slug($product->name);
            }
        });
    }

    public function meta()
    {
        return $this->hasMany(ProductMeta::class)->orderBy('order');
    }

    public function pack()
    {
        return $this->hasOne(Pack::class);
    }

    public function packItems()
    {
        return $this->hasMany(PackItem::class);
    }
}
