<?php

namespace App\Http\Controllers;

use App\Models\Client;
use Illuminate\Http\Request;
use Inertia\Inertia;

class ClientController extends Controller
{
    public function index(Request $request)
    {
        $clients = Client::query()
            ->when($request->filled('search'), fn($q) =>
                $q->where('name', 'like', '%' . $request->search . '%'))
            ->when($request->filled('company'), fn($q) =>
                $q->where('company', 'like', '%' . $request->company . '%'))
            ->when($request->filled('email'), fn($q) =>
                $q->where('email', 'like', '%' . $request->email . '%'))
            ->when($request->filled('vat'), fn($q) =>
                $q->where('vat', 'like', '%' . $request->vat . '%'))
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
        return Inertia::render('Clients/Create');
    }

    public function store(Request $request)
    {
        Client::create($request->all());
        return redirect('/clients');
    }

    public function show(Client $client)
    {
        $client->load(['projects', 'invoices']);

        $projects = $client->projects()
            ->where('is_hidden', false)
            ->latest()
            ->take(5)
            ->get();

        $invoices = $client->invoices()
            ->latest()
            ->take(5)
            ->get();

        $notes = $client->internal_notes ?? [];
        $credentialObjects = $client->credentialObjects()
            ->with(['credentials' => function ($query) {
                $query->latest();
            }])
            ->orderBy('name')
            ->get();

        return Inertia::render('Clients/Show', [
            'client'   => $client,
            'projects' => $projects,
            'invoices' => $invoices,
            'notes'    => $notes,
            'credentialObjects' => $credentialObjects,
        ]);
    }

    public function edit(Client $client)
    {
        return Inertia::render('Clients/Edit', ['client' => $client]);
    }

    public function update(Request $request, Client $client)
    {
        $client->update($request->all());
        return redirect('/clients');
    }

    public function destroy(Client $client)
    {
        $client->delete();
        return redirect('/clients');
    }

    public function storeNote(Request $request, Client $client)
    {
        $request->validate([
            'note' => 'required',
        ]);

        $existing = $client->internal_notes ?? [];

        $existing[] = [
            'text'       => $request->note,
            'created_at' => now()->toDateTimeString(),
        ];

        $client->internal_notes = $existing;
        $client->save();

        return back();
    }

    public function duplicate(Client $client)
    {
        $new = $client->replicate();
        $new->name = $new->name . ' (Cópia)';
        $new->save();

        return redirect("/clients/{$new->id}/edit");
    }
}
