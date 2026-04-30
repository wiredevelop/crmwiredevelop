<?php

namespace App\Observers;

use App\Models\Quote;
use App\Support\ActivityNotificationService;

class QuoteObserver
{
    public function created(Quote $quote): void
    {
        app(ActivityNotificationService::class)->notifyQuoteCreated($quote);
    }

    public function updated(Quote $quote): void
    {
        app(ActivityNotificationService::class)->notifyQuoteUpdated($quote);
    }
}
