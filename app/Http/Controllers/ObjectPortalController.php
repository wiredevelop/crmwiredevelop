<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Client;
use Inertia\Inertia;
use Inertia\Response;

class ObjectPortalController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index(): Response
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

        return Inertia::render('Objects/Index', [
            'client' => $client->only(['id', 'name', 'company']),
            'objects' => $client->credentialObjects,
        ]);
    }
}
