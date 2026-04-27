<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Invoice extends Model
{
    protected $fillable = [
        'project_id',
        'client_id',
        'number',
        'total',
        'status',
        'issued_at',
        'due_at',
        'payment_method',
        'payment_account',
        'paid_at',
        'is_installment',
        'installment_count',
    ];

    protected $casts = [
        'issued_at' => 'datetime',
        'due_at' => 'datetime',
        'paid_at' => 'datetime',
        'is_installment' => 'boolean',
        'installment_count' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function isPaid(): bool
    {
        return $this->status === 'pago';
    }

    public static function generateNumber(): string
    {
        $year = now()->year;

        $last = self::whereYear('created_at', $year)
            ->orderBy('id', 'desc')
            ->first();

        $nextNum = $last && $last->number
            ? (int) substr($last->number, -4) + 1
            : 1;

        return 'WD-'.$year.'-'.str_pad($nextNum, 4, '0', STR_PAD_LEFT);
    }

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function walletTransactions()
    {
        return $this->hasMany(WalletTransaction::class);
    }

    public function items()
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function installments()
    {
        return $this->hasMany(Installment::class);
    }
}
