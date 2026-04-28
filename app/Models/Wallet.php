<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Wallet extends Model
{
    protected $fillable = [
        'client_id',
        'balance_seconds',
        'balance_amount',
    ];

    protected $casts = [
        'balance_seconds' => 'integer',
        'balance_amount' => 'decimal:2',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function transactions()
    {
        return $this->hasMany(WalletTransaction::class)->orderByDesc('transaction_at');
    }
}
