<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laragear\WebAuthn\Contracts\WebAuthnAuthenticatable;
// WEB AUTHN
use Laragear\WebAuthn\WebAuthnAuthentication;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements WebAuthnAuthenticatable
{
    use HasApiTokens, HasFactory, Notifiable;
    use WebAuthnAuthentication;

    public const ROLE_ADMIN = 'admin';

    public const ROLE_CLIENT = 'client';

    protected $fillable = [
        'name',
        'email',
        'role',
        'client_id',
        'password',
        'must_change_password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'must_change_password' => 'boolean',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function isAdminUser(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function isClientUser(): bool
    {
        return $this->role === self::ROLE_CLIENT && $this->client_id !== null;
    }
}
