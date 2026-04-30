<?php

namespace App\Observers;

use App\Models\Invoice;
use App\Support\ActivityNotificationService;

class InvoiceObserver
{
    public function created(Invoice $invoice): void
    {
        app(ActivityNotificationService::class)->notifyInvoiceCreated($invoice);
    }

    public function updated(Invoice $invoice): void
    {
        app(ActivityNotificationService::class)->notifyInvoiceUpdated($invoice);
    }

    public function deleted(Invoice $invoice): void
    {
        app(ActivityNotificationService::class)->notifyInvoiceDeleted($invoice);
    }
}
