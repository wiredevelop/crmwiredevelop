<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TerminalPayment extends Model
{
    protected $fillable = [
        'user_id',
        'payment_intent_id',
        'location_id',
        'currency',
        'gross_amount',
        'fee_amount',
        'net_amount',
        'status',
        'description',
        'charge_id',
        'card_brand',
        'card_last4',
        'payment_method_type',
        'paid_at',
        'metadata',
    ];

    protected $casts = [
        'gross_amount' => 'decimal:2',
        'fee_amount' => 'decimal:2',
        'net_amount' => 'decimal:2',
        'paid_at' => 'datetime',
        'metadata' => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
