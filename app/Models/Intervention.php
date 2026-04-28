<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Intervention extends Model
{
    protected $fillable = [
        'client_id',
        'type',
        'status',
        'notes',
        'finish_notes',
        'is_pack',
        'hourly_rate',
        'started_at',
        'paused_at',
        'ended_at',
        'total_paused_seconds',
        'total_seconds',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'paused_at' => 'datetime',
        'ended_at' => 'datetime',
        'is_pack' => 'boolean',
        'hourly_rate' => 'decimal:2',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }
}
