<?php

namespace App\Providers;

use App\Models\Client;
use App\Models\Installment;
use App\Models\Intervention;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Project;
use App\Models\ProjectMessage;
use App\Models\Quote;
use App\Models\WalletTransaction;
use App\Observers\ClientObserver;
use App\Observers\InstallmentObserver;
use App\Observers\InterventionObserver;
use App\Observers\InvoiceObserver;
use App\Observers\ProductObserver;
use App\Observers\ProjectMessageObserver;
use App\Observers\ProjectObserver;
use App\Observers\QuoteObserver;
use App\Observers\WalletTransactionObserver;
use Illuminate\Support\Facades\Vite;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Vite::prefetch(concurrency: 3);

        Client::observe(ClientObserver::class);
        Project::observe(ProjectObserver::class);
        ProjectMessage::observe(ProjectMessageObserver::class);
        Quote::observe(QuoteObserver::class);
        Invoice::observe(InvoiceObserver::class);
        Installment::observe(InstallmentObserver::class);
        WalletTransaction::observe(WalletTransactionObserver::class);
        Intervention::observe(InterventionObserver::class);
        Product::observe(ProductObserver::class);
    }
}
