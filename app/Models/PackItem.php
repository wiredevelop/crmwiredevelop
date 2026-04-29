<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PackItem extends Model
{
    protected $fillable = [
        'product_id',
        'hours',
        'normal_price',
        'pack_price',
        'validity_months',
        'featured',
        'order',
    ];

    protected $casts = [
        'featured' => 'boolean',
    ];

    public $timestamps = false;
}
