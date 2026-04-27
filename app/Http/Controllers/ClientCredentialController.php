<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Client;
use App\Models\ClientCredential;
use Illuminate\Http\Request;

class ClientCredentialController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function store(Request $request, Client $client)
    {
        $this->abortIfClientUser();
        $this->ensureClientOwnership($client);

        $data = $request->validate([
            'object_id' => ['required', 'integer'],
            'label' => ['required', 'string', 'max:150'],
            'username' => ['nullable', 'string', 'max:255'],
            'password' => ['required', 'string', 'max:65535'],
            'url' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $client->credentialObjects()
            ->whereKey($data['object_id'])
            ->firstOrFail();

        $client->credentials()->create($data);

        return back();
    }

    public function destroy(Client $client, ClientCredential $credential)
    {
        $this->abortIfClientUser();
        $this->ensureClientOwnership($client);

        if ($credential->client_id !== $client->id) {
            abort(404);
        }

        $credential->delete();

        return back();
    }
}
