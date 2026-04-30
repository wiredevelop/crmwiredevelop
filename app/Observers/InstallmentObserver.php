<?php

namespace App\Observers;

use App\Models\Installment;
use App\Support\ActivityNotificationService;

class InstallmentObserver
{
    public function created(Installment $installment): void
    {
        app(ActivityNotificationService::class)->notifyInstallmentCreated($installment);
    }

    public function updated(Installment $installment): void
    {
        app(ActivityNotificationService::class)->notifyInstallmentUpdated($installment);
    }

    public function deleted(Installment $installment): void
    {
        app(ActivityNotificationService::class)->notifyInstallmentDeleted($installment);
    }
}
