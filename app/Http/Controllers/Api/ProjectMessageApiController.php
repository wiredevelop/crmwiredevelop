<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ProjectMessageResource;
use App\Models\Project;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProjectMessageApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function store(Request $request, Project $project): JsonResponse
    {
        $this->ensureProjectOwnership($project);

        $data = $request->validate([
            'type' => ['nullable', 'in:message,proof_request,proof_submission,status_update'],
            'body' => ['nullable', 'string', 'max:10000'],
            'attachment' => ['nullable', 'array'],
            'attachment.filename' => ['nullable', 'string', 'max:255'],
            'attachment.mime_type' => ['required_with:attachment', 'string', 'max:100'],
            'attachment.content_base64' => ['required_with:attachment', 'string'],
        ]);

        $body = trim((string) ($data['body'] ?? ''));
        $attachment = is_array($data['attachment'] ?? null) ? $data['attachment'] : null;

        if ($body === '' && ! $attachment) {
            return $this->error('Escreve uma mensagem ou anexa uma imagem.', [
                'body' => ['Escreve uma mensagem ou anexa uma imagem.'],
            ], 422);
        }

        $meta = [];
        if ($attachment) {
            $meta['attachment'] = $this->storeAttachment($project, $attachment);
        }

        if ($body === '') {
            $body = match ($data['type'] ?? 'message') {
                'proof_submission' => 'Prova submetida.',
                'proof_request' => $this->isClientUser()
                    ? 'Preciso de prova feedback.'
                    : 'Pedido de prova: por favor partilha atualização, captura de ecrã ou vídeo deste ponto do projeto.',
                default => 'Imagem enviada.',
            };
        }

        $message = $project->messages()->create([
            'user_id' => $request->user()?->id,
            'sender_role' => $this->isClientUser() ? 'client' : 'admin',
            'type' => $data['type'] ?? 'message',
            'body' => $body,
            'meta' => $meta ?: null,
        ]);

        $message->load('user');

        return $this->success([
            'message' => new ProjectMessageResource($message),
        ], 'Mensagem enviada.', 201);
    }

    private function storeAttachment(Project $project, array $attachment): array
    {
        $mimeType = strtolower(trim((string) ($attachment['mime_type'] ?? '')));
        if (! Str::startsWith($mimeType, 'image/')) {
            abort(response()->json([
                'message' => 'Só é permitido anexar imagens.',
                'errors' => [
                    'attachment' => ['Só é permitido anexar imagens.'],
                ],
            ], 422));
        }

        $content = trim((string) ($attachment['content_base64'] ?? ''));
        if (preg_match('/^data:[^;]+;base64,/', $content)) {
            $content = preg_replace('/^data:[^;]+;base64,/', '', $content) ?? $content;
        }

        $binary = base64_decode($content, true);
        if ($binary === false) {
            abort(response()->json([
                'message' => 'A imagem anexada é inválida.',
                'errors' => [
                    'attachment' => ['A imagem anexada é inválida.'],
                ],
            ], 422));
        }

        if (strlen($binary) > (8 * 1024 * 1024)) {
            abort(response()->json([
                'message' => 'A imagem anexada excede o limite de 8 MB.',
                'errors' => [
                    'attachment' => ['A imagem anexada excede o limite de 8 MB.'],
                ],
            ], 422));
        }

        $originalName = trim((string) ($attachment['filename'] ?? 'imagem.jpg'));
        $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
        if ($extension === '') {
            $extension = match ($mimeType) {
                'image/png' => 'png',
                'image/webp' => 'webp',
                'image/gif' => 'gif',
                default => 'jpg',
            };
        }

        $path = sprintf(
            'project-messages/%d/%s.%s',
            $project->id,
            Str::uuid()->toString(),
            $extension
        );

        Storage::disk('public')->put($path, $binary);

        return [
            'kind' => 'image',
            'path' => $path,
            'url' => Storage::disk('public')->url($path),
            'filename' => $originalName,
            'mime_type' => $mimeType,
            'size' => strlen($binary),
        ];
    }
}
