<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Passkey extends Model
{
    protected $table = 'passkeys';

    protected $fillable = [
        'user_id',
        'credential_id',
        'public_key',
        'algorithm',
        'counter',
    ];

    // Associação ao User
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
