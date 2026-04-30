<?php

namespace App\Observers;

use App\Models\WalletTransaction;
use App\Support\ActivityNotificationService;

class WalletTransactionObserver
{
    public function created(WalletTransaction $walletTransaction): void
    {
        app(ActivityNotificationService::class)->notifyWalletTransactionCreated($walletTransaction);
    }

    public function updated(WalletTransaction $walletTransaction): void
    {
        app(ActivityNotificationService::class)->notifyWalletTransactionUpdated($walletTransaction);
    }

    public function deleted(WalletTransaction $walletTransaction): void
    {
        app(ActivityNotificationService::class)->notifyWalletTransactionDeleted($walletTransaction);
    }
}
