<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientCredentialObjectResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'client_id' => $this->client_id,
            'project_id' => $this->project_id,
            'name' => $this->name,
            'notes' => $this->notes,
            'credentials_count' => $this->whenCounted('credentials'),
            'project' => $this->when(
                $this->relationLoaded('project') && $this->project,
                fn () => [
                    'id' => $this->project->id,
                    'name' => $this->project->name,
                    'status' => $this->project->status,
                ]
            ),
            'credentials' => ClientCredentialResource::collection($this->whenLoaded('credentials')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
