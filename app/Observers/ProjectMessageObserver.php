<?php

namespace App\Observers;

use App\Models\ProjectMessage;
use App\Support\ActivityNotificationService;

class ProjectMessageObserver
{
    public function created(ProjectMessage $projectMessage): void
    {
        app(ActivityNotificationService::class)->notifyProjectMessageCreated($projectMessage);
    }
}
