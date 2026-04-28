<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProductMeta extends Model
{
    protected $table = 'product_meta';

    protected $fillable = [
        'product_id',   // ✅ OBRIGATÓRIO
        'label',
        'key',
        'type',
        'value',
        'show_front',
        'order',
    ];
}
