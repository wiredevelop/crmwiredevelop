<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ClientCredentialObjectResource;
use App\Http\Resources\Api\ClientCredentialResource;
use App\Http\Resources\Api\ClientResource;
use App\Models\Client;
use App\Models\ClientCredential;
use App\Models\ClientCredentialObject;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ClientApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $clients = Client::query()
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%' . $request->search . '%'))
            ->when($request->filled('company'), fn ($q) => $q->where('company', 'like', '%' . $request->company . '%'))
            ->when($request->filled('email'), fn ($q) => $q->where('email', 'like', '%' . $request->email . '%'))
            ->when($request->filled('vat'), fn ($q) => $q->where('vat', 'like', '%' . $request->vat . '%'))
            ->orderBy('created_at', 'desc')
            ->paginate((int) $request->integer('per_page', 10))
            ->withQueryString();

        return $this->paginated($request, $clients, ClientResource::collection($clients->getCollection())->resolve(), null, [
            'filters' => $request->only('search', 'company', 'email', 'vat'),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $client = Client::create($this->validatedClientData($request));

        return $this->success([
            'client' => new ClientResource($client),
        ], 'Cliente criado com sucesso.', 201);
    }

    public function show(Client $client): JsonResponse
    {
        $client->load([
            'projects' => fn ($query) => $query->where('is_hidden', false)->latest()->take(5),
            'invoices' => fn ($query) => $query->latest()->take(5),
            'credentialObjects.credentials' => fn ($query) => $query->latest(),
            'wallet.transactions',
        ]);

        return $this->success([
            'client' => new ClientResource($client),
            'notes' => $client->internal_notes ?? [],
        ]);
    }

    public function update(Request $request, Client $client): JsonResponse
    {
        $client->update($this->validatedClientData($request));

        return $this->success([
            'client' => new ClientResource($client->fresh()),
        ], 'Cliente atualizado com sucesso.');
    }

    public function destroy(Client $client): JsonResponse
    {
        $client->delete();

        return $this->success([], 'Cliente removido com sucesso.');
    }

    public function storeNote(Request $request, Client $client): JsonResponse
    {
        $data = $request->validate([
            'note' => ['required', 'string'],
        ]);

        $existing = $client->internal_notes ?? [];
        $existing[] = [
            'text' => $data['note'],
            'created_at' => now()->toDateTimeString(),
        ];

        $client->internal_notes = $existing;
        $client->save();

        return $this->success([
            'notes' => $existing,
        ], 'Nota adicionada com sucesso.');
    }

    public function duplicate(Client $client): JsonResponse
    {
        $new = $client->replicate();
        $new->name = $new->name . ' (Cópia)';
        $new->save();

        return $this->success([
            'client' => new ClientResource($new),
        ], 'Cliente duplicado com sucesso.', 201);
    }

    public function storeCredentialObject(Request $request, Client $client): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $object = $client->credentialObjects()->create($data);

        return $this->success([
            'object' => new ClientCredentialObjectResource($object),
        ], 'Objeto criado com sucesso.', 201);
    }

    public function destroyCredentialObject(Client $client, ClientCredentialObject $object): JsonResponse
    {
        abort_if($object->client_id !== $client->id, 404);

        $object->delete();

        return $this->success([], 'Objeto removido com sucesso.');
    }

    public function exportCredentialObject(Client $client, ClientCredentialObject $object): StreamedResponse
    {
        abort_if($object->client_id !== $client->id, 404);

        $credentials = $object->credentials()->latest()->get();
        $filename = 'credenciais_' . $client->id . '_' . $object->id . '.csv';

        return response()->streamDownload(function () use ($client, $object, $credentials) {
            echo "\xEF\xBB\xBF";
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['Cliente', 'Objeto', 'Servico', 'Utilizador', 'Senha', 'URL', 'Notas', 'Criado em'], ';');

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
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function storeCredential(Request $request, Client $client): JsonResponse
    {
        $data = $request->validate([
            'object_id' => ['required', 'integer'],
            'label' => ['required', 'string', 'max:150'],
            'username' => ['nullable', 'string', 'max:255'],
            'password' => ['required', 'string', 'max:65535'],
            'url' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $client->credentialObjects()->whereKey($data['object_id'])->firstOrFail();
        $credential = $client->credentials()->create($data);

        return $this->success([
            'credential' => new ClientCredentialResource($credential),
        ], 'Credencial criada com sucesso.', 201);
    }

    public function destroyCredential(Client $client, ClientCredential $credential): JsonResponse
    {
        abort_if($credential->client_id !== $client->id, 404);

        $credential->delete();

        return $this->success([], 'Credencial removida com sucesso.');
    }

    private function validatedClientData(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'company' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:255'],
            'vat' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
            'hourly_rate' => ['nullable', 'numeric', 'min:0'],
        ]);
    }
}
