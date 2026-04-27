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
        'billing_name',
        'billing_email',
        'billing_phone',
        'billing_vat',
        'billing_address',
        'billing_postal_code',
        'billing_city',
        'billing_country',
        'stripe_customer_id',
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

    public function user()
    {
        return $this->hasOne(User::class);
    }
}
