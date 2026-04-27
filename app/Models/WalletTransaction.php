<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WalletTransaction extends Model
{
    protected $fillable = [
        'wallet_id',
        'type',
        'seconds',
        'amount',
        'description',
        'product_id',
        'pack_item_id',
        'intervention_id',
        'transaction_at',
        'is_installment',
        'installment_count',
        'to_invoice',
        'invoice_id',
        'payment_provider',
        'payment_reference',
        'payment_metadata',
    ];

    protected $casts = [
        'seconds' => 'integer',
        'amount' => 'decimal:2',
        'transaction_at' => 'datetime',
        'is_installment' => 'boolean',
        'installment_count' => 'integer',
        'to_invoice' => 'boolean',
        'invoice_id' => 'integer',
        'payment_metadata' => 'array',
    ];

    public function wallet()
    {
        return $this->belongsTo(Wallet::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function packItem()
    {
        return $this->belongsTo(PackItem::class);
    }

    public function intervention()
    {
        return $this->belongsTo(Intervention::class);
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }
}
