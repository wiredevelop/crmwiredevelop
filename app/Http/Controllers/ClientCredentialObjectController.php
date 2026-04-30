<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Client;
use App\Models\ClientCredentialObject;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ClientCredentialObjectController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function store(Request $request, Client $client)
    {
        $this->abortIfClientUser();
        $this->ensureClientOwnership($client);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $client->credentialObjects()->create($data);

        return back();
    }

    public function destroy(Client $client, ClientCredentialObject $object)
    {
        $this->abortIfClientUser();
        $this->ensureClientOwnership($client);

        if ($object->client_id !== $client->id) {
            abort(404);
        }

        $object->delete();

        return back();
    }

    public function export(Client $client, ClientCredentialObject $object): StreamedResponse
    {
        $this->ensureClientOwnership($client);

        if ($object->client_id !== $client->id) {
            abort(404);
        }

        $credentials = $object->credentials()->latest()->get();
        $filename = 'credenciais_'.$client->id.'_'.$object->id.'.csv';

        return response()->streamDownload(function () use ($client, $object, $credentials) {
            echo "\xEF\xBB\xBF";
            $handle = fopen('php://output', 'w');
            fputcsv($handle, [
                'Cliente',
                'Objeto',
                'Servico',
                'Utilizador',
                'Senha',
                'URL',
                'Notas',
                'Criado em',
            ], ';');

            foreach ($credentials as $credential) {
                fputcsv($handle, [
                    $client->name,
                    $object->name,
                    $credential->label,
                    $credential->username,
                    $credential->password,
                    $credential->url,
                    $credential->notes,
                    $credential->created_at?->toDateTimeString(),
                ], ';');
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }
}
