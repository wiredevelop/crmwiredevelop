<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Client extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'company',
        'email',
        'phone',
        'vat',
        'address',
        'notes',
        'hourly_rate',
    ];

    protected $casts = [
        'hourly_rate' => 'decimal:2',
    ];

    public function projects()
    {
        return $this->hasMany(Project::class);
    }

    public function invoices()
    {
        return $this->hasMany(Invoice::class);
    }

    public function installments()
    {
        return $this->hasMany(Installment::class);
    }

    public function interventions()
    {
        return $this->hasMany(Intervention::class);
    }

    public function wallet()
    {
        return $this->hasOne(Wallet::class);
    }

    public function credentials()
    {
        return $this->hasMany(ClientCredential::class);
    }

    public function credentialObjects()
    {
        return $this->hasMany(ClientCredentialObject::class);
    }
}
