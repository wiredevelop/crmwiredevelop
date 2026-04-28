<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\ClientCredentialObjectResource;
use App\Http\Resources\Api\ClientCredentialResource;
use App\Http\Resources\Api\ClientResource;
use App\Models\Client;
use App\Models\ClientCredential;
use App\Models\ClientCredentialObject;
use App\Support\ClientCredentialObjectTransferManager;
use App\Support\ClientPortalManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ClientApiController extends Controller
{
    use InteractsWithClientPortalUsers;
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $clients = $this->scopeClients(Client::query()->with('user'))
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%'.$request->search.'%'))
            ->when($request->filled('company'), fn ($q) => $q->where('company', 'like', '%'.$request->company.'%'))
            ->when($request->filled('email'), fn ($q) => $q->where('email', 'like', '%'.$request->email.'%'))
            ->when($request->filled('vat'), fn ($q) => $q->where('vat', 'like', '%'.$request->vat.'%'))
            ->orderBy('created_at', 'desc')
            ->paginate((int) $request->integer('per_page', 10))
            ->withQueryString();

        return $this->paginated($request, $clients, ClientResource::collection($clients->getCollection())->resolve(), null, [
            'filters' => $request->only('search', 'company', 'email', 'vat'),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->abortIfClientUser();

        $response = DB::transaction(function () use ($request) {
            $client = Client::create($this->validatedClientData($request));

            $response = [
                'client' => new ClientResource($client),
            ];

            if ($request->boolean('create_portal_user')) {
                [$user, $temporaryPassword] = app(ClientPortalManager::class)->createPortalUser(
                    $client,
                    $request->string('portal_email')->toString(),
                    $request->string('portal_password')->toString(),
                );

                $response['client'] = new ClientResource($client->fresh('user'));
                $response['portal_user'] = new \App\Http\Resources\Api\UserResource($user);
                $response['temporary_password'] = $temporaryPassword;
            }

            return $response;
        });

        return $this->success($response, 'Cliente criado com sucesso.', 201);
    }

    public function show(Client $client): JsonResponse
    {
        $this->ensureClientOwnership($client);

        $client->load([
            'projects' => fn ($query) => $query->where('is_hidden', false)->latest()->take(5),
            'invoices' => fn ($query) => $query->latest()->take(5),
            'wallet.transactions',
            'user',
        ]);

        if (! $this->isClientUser()) {
            $client->load([
                'credentialObjects.project',
                'credentialObjects.credentials' => fn ($query) => $query->latest(),
            ]);
        }

        $payload = [
            'client' => new ClientResource($client),
            'notes' => $this->isClientUser() ? [] : ($client->internal_notes ?? []),
        ];

        if (! $this->isClientUser()) {
            $payload['transfer_targets'] = Client::query()
                ->whereKeyNot($client->id)
                ->orderBy('name')
                ->get(['id', 'name', 'company']);
        }

        return $this->success($payload);
    }

    public function update(Request $request, Client $client): JsonResponse
    {
        $this->abortIfClientUser();

        $client->update($this->validatedClientData($request));

        return $this->success([
            'client' => new ClientResource($client->fresh()),
        ], 'Cliente atualizado com sucesso.');
    }

    public function destroy(Client $client): JsonResponse
    {
        $this->abortIfClientUser();

        DB::transaction(function () use ($client) {
            if ($user = $client->user) {
                $user->tokens()->delete();
                $user->delete();
            }
            $client->delete();
        });

        return $this->success([], 'Cliente removido com sucesso.');
    }

    public function storeNote(Request $request, Client $client): JsonResponse
    {
        $this->abortIfClientUser();

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
        $this->abortIfClientUser();

        $new = $client->replicate();
        $new->name = $new->name.' (Cópia)';
        $new->save();

        return $this->success([
            'client' => new ClientResource($new),
        ], 'Cliente duplicado com sucesso.', 201);
    }

    public function storeCredentialObject(Request $request, Client $client): JsonResponse
    {
        $this->abortIfClientUser();

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
        $this->abortIfClientUser();
        abort_if($object->client_id !== $client->id, 404);

        $object->delete();

        return $this->success([], 'Objeto removido com sucesso.');
    }

    public function exportCredentialObject(Client $client, ClientCredentialObject $object): StreamedResponse
    {
        $this->abortIfClientUser();
        abort_if($object->client_id !== $client->id, 404);

        $credentials = $object->credentials()->latest()->get();
        $filename = 'credenciais_'.$client->id.'_'.$object->id.'.csv';

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
        $this->abortIfClientUser();

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
        $this->abortIfClientUser();
        abort_if($credential->client_id !== $client->id, 404);

        $credential->delete();

        return $this->success([], 'Credencial removida com sucesso.');
    }

    public function storePortalUser(Request $request, Client $client, ClientPortalManager $portalManager): JsonResponse
    {
        $this->abortIfClientUser();

        [$user, $temporaryPassword] = $portalManager->createPortalUser(
            $client,
            $request->string('portal_email')->toString(),
            $request->string('portal_password')->toString(),
        );

        return $this->success([
            'portal_user' => new \App\Http\Resources\Api\UserResource($user),
            'temporary_password' => $temporaryPassword,
        ], 'Acesso do cliente criado com sucesso.', 201);
    }

    public function regenerateTemporaryPassword(Request $request, Client $client, ClientPortalManager $portalManager): JsonResponse
    {
        $this->abortIfClientUser();

        $data = $request->validate([
            'delivery_mode' => ['required', 'in:copy,email'],
        ]);

        [$user, $temporaryPassword] = $portalManager->regenerateTemporaryPassword($client, $data['delivery_mode']);

        return $this->success([
            'portal_user' => new \App\Http\Resources\Api\UserResource($user),
            'temporary_password' => $temporaryPassword,
        ], $data['delivery_mode'] === 'email'
            ? 'Nova senha temporária enviada por email.'
            : 'Nova senha temporária gerada com sucesso.');
    }

    public function transferCredentialObject(
        Request $request,
        Client $client,
        ClientCredentialObject $object,
        ClientCredentialObjectTransferManager $transferManager,
    ): JsonResponse {
        $this->abortIfClientUser();
        abort_if($object->client_id !== $client->id, 404);

        $data = $request->validate([
            'target_client_id' => ['required', 'integer', 'exists:clients,id'],
        ]);

        $targetClient = Client::findOrFail($data['target_client_id']);
        $object = $transferManager->transfer($object, $targetClient);

        return $this->success([
            'object' => new ClientCredentialObjectResource($object->loadMissing('project')),
            'target_client' => new ClientResource($targetClient),
        ], 'Objeto transferido com sucesso.');
    }

    public function promoteCredentialObject(
        Request $request,
        Client $client,
        ClientCredentialObject $object,
        ClientCredentialObjectTransferManager $transferManager,
    ): JsonResponse {
        $this->abortIfClientUser();
        abort_if($object->client_id !== $client->id, 404);

        $clientData = $this->validatedClientData($request);
        $portalData = $request->validate([
            'portal_email' => ['required', 'email', 'max:255'],
            'portal_password' => ['nullable', 'string', 'max:255'],
        ]);

        [$newClient, $user, $temporaryPassword, $transferredObject] = $transferManager->promote(
            $object,
            $clientData,
            $portalData['portal_email'],
            $portalData['portal_password'] ?: null,
        );

        return $this->success([
            'client' => new ClientResource($newClient->loadMissing('user')),
            'portal_user' => new \App\Http\Resources\Api\UserResource($user),
            'temporary_password' => $temporaryPassword,
            'object' => new ClientCredentialObjectResource($transferredObject->loadMissing('project')),
        ], 'Objeto promovido a cliente com sucesso.', 201);
    }

    protected function validatedClientData(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'company' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:255'],
            'vat' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'billing_name' => ['nullable', 'string', 'max:255'],
            'billing_email' => ['nullable', 'email', 'max:255'],
            'billing_phone' => ['nullable', 'string', 'max:255'],
            'billing_vat' => ['nullable', 'string', 'max:255'],
            'billing_address' => ['nullable', 'string', 'max:255'],
            'billing_postal_code' => ['nullable', 'string', 'max:30'],
            'billing_city' => ['nullable', 'string', 'max:255'],
            'billing_country' => ['nullable', 'string', 'max:2'],
            'notes' => ['nullable', 'string'],
            'hourly_rate' => ['nullable', 'numeric', 'min:0'],
        ]);
    }
}
