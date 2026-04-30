<?php

namespace App\Observers;

use App\Models\Intervention;
use App\Support\ActivityNotificationService;

class InterventionObserver
{
    public function created(Intervention $intervention): void
    {
        app(ActivityNotificationService::class)->notifyInterventionCreated($intervention);
    }

    public function updated(Intervention $intervention): void
    {
        app(ActivityNotificationService::class)->notifyInterventionUpdated($intervention);
    }
}
