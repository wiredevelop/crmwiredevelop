<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InterventionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'client_id' => $this->client_id,
            'type' => $this->type,
            'status' => $this->status,
            'notes' => $this->notes,
            'finish_notes' => $this->finish_notes,
            'is_pack' => (bool) $this->is_pack,
            'hourly_rate' => $this->hourly_rate,
            'started_at' => $this->started_at,
            'paused_at' => $this->paused_at,
            'ended_at' => $this->ended_at,
            'total_paused_seconds' => (int) $this->total_paused_seconds,
            'total_seconds' => (int) $this->total_seconds,
            'client' => $this->when(
                $this->relationLoaded('client') && $this->client,
                fn () => new ClientResource($this->client)
            ),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
