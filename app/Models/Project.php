<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Project extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_id',
        'name',
        'type',
        'status',
        'technologies',
        'description',
        'quote_id',
        'is_hidden',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'is_hidden' => 'boolean',
    ];

    // 🔗 RELAÇÕES
    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function quote()
    {
        return $this->hasOne(Quote::class);
    }

    public function invoice()
    {
        return $this->hasOne(Invoice::class);
    }

    public function installments()
    {
        return $this->hasMany(Installment::class);
    }

    public function credentials()
    {
        return $this->hasMany(ClientCredential::class);
    }

    public function credentialObject()
    {
        return $this->hasOne(ClientCredentialObject::class);
    }

    public function messages()
    {
        return $this->hasMany(ProjectMessage::class)->latest();
    }
}
