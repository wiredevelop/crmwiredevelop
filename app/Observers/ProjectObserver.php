<?php

namespace App\Observers;

use App\Models\Project;
use App\Support\ActivityNotificationService;

class ProjectObserver
{
    public function created(Project $project): void
    {
        app(ActivityNotificationService::class)->notifyProjectCreated($project);
    }

    public function updated(Project $project): void
    {
        app(ActivityNotificationService::class)->notifyProjectUpdated($project);
    }

    public function deleted(Project $project): void
    {
        app(ActivityNotificationService::class)->notifyProjectDeleted($project);
    }
}
