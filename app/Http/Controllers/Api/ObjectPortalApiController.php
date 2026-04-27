<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ClientCredentialObjectResource;
use App\Models\Client;
use Illuminate\Http\JsonResponse;

class ObjectPortalApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function index(): JsonResponse
    {
        abort_unless($this->isClientUser(), 403);

        $client = Client::query()
            ->with([
                'credentialObjects' => fn ($query) => $query
                    ->withCount('credentials')
                    ->with([
                        'project:id,client_id,name,status',
                        'credentials' => fn ($credentialQuery) => $credentialQuery->latest(),
                    ])
                    ->orderBy('name'),
            ])
            ->findOrFail($this->currentClientId());

        return $this->success([
            'client' => $client->only(['id', 'name', 'company']),
            'objects' => ClientCredentialObjectResource::collection($client->credentialObjects),
        ]);
    }
}
