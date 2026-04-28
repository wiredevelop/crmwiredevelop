<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\InteractsWithClientPortalUsers;
use App\Models\ClientCredential;
use App\Models\Project;
use Illuminate\Http\Request;
use Inertia\Inertia;

class ProjectCredentialController extends Controller
{
    use InteractsWithClientPortalUsers;

    public function index(Project $project)
    {
        $this->ensureProjectOwnership($project);

        $project->load('client');

        $credentials = $project->credentials()
            ->latest()
            ->get();

        return Inertia::render('Projects/Credentials', [
            'project' => $project,
            'credentials' => $credentials,
        ]);
    }

    public function store(Request $request, Project $project)
    {
        $this->abortIfClientUser();
        $this->ensureProjectOwnership($project);

        $data = $request->validate([
            'label' => ['required', 'string', 'max:150'],
            'username' => ['nullable', 'string', 'max:255'],
            'password' => ['required', 'string', 'max:65535'],
            'url' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:65535'],
        ]);

        $project->credentials()->create(array_merge($data, [
            'client_id' => $project->client_id,
        ]));

        return back();
    }

    public function destroy(Project $project, ClientCredential $credential)
    {
        $this->abortIfClientUser();
        $this->ensureProjectOwnership($project);

        if ($credential->project_id !== $project->id) {
            abort(404);
        }

        $credential->delete();

        return back();
    }
}
