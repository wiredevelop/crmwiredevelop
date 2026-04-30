<?php

namespace App\Observers;

use App\Models\Client;
use App\Support\ActivityNotificationService;

class ClientObserver
{
    public function created(Client $client): void
    {
        app(ActivityNotificationService::class)->notifyClientCreated($client);
    }

    public function updated(Client $client): void
    {
        app(ActivityNotificationService::class)->notifyClientUpdated($client);
    }

    public function deleted(Client $client): void
    {
        app(ActivityNotificationService::class)->notifyClientDeleted($client);
    }
}
