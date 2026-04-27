<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\Client;
use App\Support\ClientPortalManager;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class ClientController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index(Request $request)
    {
        if ($this->isClientUser()) {
            return redirect()->route('objects.index');
        }

        $clients = $this->scopeClients(Client::query()->with('user'))
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%'.$request->search.'%'))
            ->when($request->filled('company'), fn ($q) => $q->where('company', 'like', '%'.$request->company.'%'))
            ->when($request->filled('email'), fn ($q) => $q->where('email', 'like', '%'.$request->email.'%'))
            ->when($request->filled('vat'), fn ($q) => $q->where('vat', 'like', '%'.$request->vat.'%'))
            ->orderBy('created_at', 'desc')
            ->paginate(10)
            ->withQueryString();

        return Inertia::render('Clients/Index', [
            'clients' => $clients,
            'filters' => $request->only('search', 'company', 'email', 'vat'),
        ]);
    }

    public function create()
    {
        $this->abortIfClientUser();

        return Inertia::render('Clients/Create');
    }

    public function store(Request $request, ClientPortalManager $portalManager): RedirectResponse
    {
        $this->abortIfClientUser();

        $data = $this->validatedClientData($request);
        $createPortalUser = $request->boolean('create_portal_user');

        $client = DB::transaction(function () use ($data, $request, $createPortalUser, $portalManager, &$temporaryPassword, &$portalEmail) {
            $client = Client::create($data);

            if ($createPortalUser) {
                [$user, $temporaryPassword] = $portalManager->createPortalUser(
                    $client,
                    $request->string('portal_email')->toString(),
                    $request->string('portal_password')->toString(),
                );

                $portalEmail = $user->email;
            }

            return $client;
        });

        if ($createPortalUser) {
            return redirect()
                ->route('clients.show', $client)
                ->with('success', 'Cliente e acesso criados com sucesso.')
                ->with('temporaryPassword', $temporaryPassword)
                ->with('temporaryPasswordEmail', $portalEmail)
                ->with('temporaryPasswordClient', $client->name);
        }

        return redirect('/clients');
    }

    public function show(Client $client)
    {
        $this->ensureClientOwnership($client);

        if ($this->isClientUser()) {
            return redirect()->route('objects.index');
        }

        $client->load([
            'projects' => fn ($query) => $query->where('is_hidden', false)->latest()->take(5),
            'invoices' => fn ($query) => $query->latest()->take(5),
            'user',
        ]);

        $projects = $client->projects;
        $invoices = $client->invoices;
        $notes = $this->isClientUser() ? [] : ($client->internal_notes ?? []);
        $credentialObjects = $this->isClientUser()
            ? collect()
            : $client->credentialObjects()
                ->with(['credentials' => function ($query) {
                    $query->latest();
                }])
                ->orderBy('name')
                ->get();

        return Inertia::render('Clients/Show', [
            'client' => $client,
            'projects' => $projects,
            'invoices' => $invoices,
            'notes' => $notes,
            'credentialObjects' => $credentialObjects,
        ]);
    }

    public function edit(Client $client)
    {
        $this->abortIfClientUser();

        return Inertia::render('Clients/Edit', ['client' => $client]);
    }

    public function update(Request $request, Client $client)
    {
        $this->abortIfClientUser();

        $client->update($this->validatedClientData($request));

        return redirect('/clients');
    }

    public function destroy(Client $client)
    {
        $this->abortIfClientUser();

        DB::transaction(function () use ($client) {
            if ($user = $client->user) {
                $user->tokens()->delete();
                $user->delete();
            }
            $client->delete();
        });

        return redirect('/clients');
    }

    public function storeNote(Request $request, Client $client)
    {
        $this->abortIfClientUser();

        $request->validate([
            'note' => 'required',
        ]);

        $existing = $client->internal_notes ?? [];

        $existing[] = [
            'text' => $request->note,
            'created_at' => now()->toDateTimeString(),
        ];

        $client->internal_notes = $existing;
        $client->save();

        return back();
    }

    public function duplicate(Client $client)
    {
        $this->abortIfClientUser();

        $new = $client->replicate();
        $new->name = $new->name.' (Cópia)';
        $new->save();

        return redirect("/clients/{$new->id}/edit");
    }

    public function storePortalUser(Request $request, Client $client, ClientPortalManager $portalManager): RedirectResponse
    {
        $this->abortIfClientUser();

        [$user, $temporaryPassword] = $portalManager->createPortalUser(
            $client,
            $request->string('portal_email')->toString(),
            $request->string('portal_password')->toString(),
        );

        return back()
            ->with('success', 'Acesso do cliente criado com sucesso.')
            ->with('temporaryPassword', $temporaryPassword)
            ->with('temporaryPasswordEmail', $user->email)
            ->with('temporaryPasswordClient', $client->name);
    }

    public function regenerateTemporaryPassword(Request $request, Client $client, ClientPortalManager $portalManager): RedirectResponse
    {
        $this->abortIfClientUser();

        $data = $request->validate([
            'delivery_mode' => ['required', 'in:copy,email'],
        ]);

        [$user, $temporaryPassword] = $portalManager->regenerateTemporaryPassword($client, $data['delivery_mode']);

        return back()
            ->with('success', $data['delivery_mode'] === 'email'
                ? 'Nova senha temporária enviada por email.'
                : 'Nova senha temporária gerada com sucesso.')
            ->with('temporaryPassword', $temporaryPassword)
            ->with('temporaryPasswordEmail', $user->email)
            ->with('temporaryPasswordClient', $client->name);
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
