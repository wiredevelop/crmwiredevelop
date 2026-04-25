<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ClientCredential extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_id',
        'project_id',
        'object_id',
        'label',
        'username',
        'password',
        'url',
        'notes',
    ];

    protected $casts = [
        'password' => 'encrypted',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function object()
    {
        return $this->belongsTo(ClientCredentialObject::class, 'object_id');
    }
}
