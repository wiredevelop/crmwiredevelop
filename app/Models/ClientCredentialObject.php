<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ClientCredentialObject extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_id',
        'project_id',
        'name',
        'notes',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function credentials()
    {
        return $this->hasMany(ClientCredential::class, 'object_id');
    }
}
