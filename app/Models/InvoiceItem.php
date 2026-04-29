<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InvoiceItem extends Model
{
    protected $fillable = [
        'invoice_id',
        'description',
        'quantity',
        'unit_price',
        'total',
        'source_type',
        'source_id',
    ];

    protected $casts = [
        'quantity' => 'decimal:2',
        'unit_price' => 'decimal:2',
        'total' => 'decimal:2',
    ];

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function sourceTransaction()
    {
        return $this->belongsTo(WalletTransaction::class, 'source_id');
    }

    public function sourceProject()
    {
        return $this->belongsTo(Project::class, 'source_id');
    }
}
