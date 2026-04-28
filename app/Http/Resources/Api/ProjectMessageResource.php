<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProjectMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $currentUserId = $request->user()?->id;

        return [
            'id' => $this->id,
            'project_id' => $this->project_id,
            'user_id' => $this->user_id,
            'sender_role' => $this->sender_role,
            'type' => $this->type,
            'body' => $this->body,
            'meta' => $this->meta,
            'sender_name' => $this->user?->name ?? ($this->sender_role === 'client' ? 'Cliente' : 'WireDevelop'),
            'sender_email' => $this->user?->email,
            'is_current_user' => $currentUserId !== null && (int) $this->user_id === (int) $currentUserId,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
