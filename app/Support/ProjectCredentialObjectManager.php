<?php

namespace App\Support;

use App\Models\ClientCredentialObject;
use App\Models\Project;
use Illuminate\Support\Str;

class ProjectCredentialObjectManager
{
    public function syncForProject(Project $project): ClientCredentialObject
    {
        $object = ClientCredentialObject::query()
            ->where('project_id', $project->id)
            ->first();

        if (! $object) {
            $object = ClientCredentialObject::query()
                ->where('client_id', $project->client_id)
                ->whereNull('project_id')
                ->whereRaw('LOWER(name) = ?', [Str::lower($project->name)])
                ->first();
        }

        if (! $object) {
            $object = new ClientCredentialObject();
        }

        $object->fill([
            'client_id' => $project->client_id,
            'project_id' => $project->id,
            'name' => $project->name,
        ]);
        $object->save();

        return $object;
    }
}
