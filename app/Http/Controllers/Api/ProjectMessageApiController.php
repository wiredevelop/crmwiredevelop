<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ProjectMessageResource;
use App\Models\Project;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProjectMessageApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function store(Request $request, Project $project): JsonResponse
    {
        $this->ensureProjectOwnership($project);

        $data = $request->validate([
            'type' => ['nullable', 'in:message,proof_request,status_update'],
            'body' => ['required', 'string', 'max:10000'],
        ]);

        $message = $project->messages()->create([
            'user_id' => $request->user()?->id,
            'sender_role' => $this->isClientUser() ? 'client' : 'admin',
            'type' => $data['type'] ?? 'message',
            'body' => trim($data['body']),
        ]);

        $message->load('user');

        return $this->success([
            'message' => new ProjectMessageResource($message),
        ], 'Mensagem enviada.', 201);
    }
}
