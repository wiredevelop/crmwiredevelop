<?php

namespace App\Observers;

use App\Models\Product;
use App\Support\ActivityNotificationService;

class ProductObserver
{
    public function created(Product $product): void
    {
        app(ActivityNotificationService::class)->notifyProductCreated($product);
    }

    public function updated(Product $product): void
    {
        app(ActivityNotificationService::class)->notifyProductUpdated($product);
    }

    public function deleted(Product $product): void
    {
        app(ActivityNotificationService::class)->notifyProductDeleted($product);
    }
}
