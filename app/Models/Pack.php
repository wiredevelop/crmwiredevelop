<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Pack extends Model
{
    public $timestamps = false;

    protected $primaryKey = 'product_id';

    public $incrementing = false;

    protected $fillable = [
        'product_id',
        'hours_included',
        'normal_price',
        'pack_price',
        'validity_months',
        'extra_hour_price',
        'featured',
    ];
}
