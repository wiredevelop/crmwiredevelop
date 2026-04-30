<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientApiController;
use App\Http\Controllers\Api\ClientWalletApiController;
use App\Http\Controllers\Api\CompanyApiController;
use App\Http\Controllers\Api\DashboardApiController;
use App\Http\Controllers\Api\FinanceApiController;
use App\Http\Controllers\Api\InterventionApiController;
use App\Http\Controllers\Api\InvoiceApiController;
use App\Http\Controllers\Api\NotificationDeviceApiController;
use App\Http\Controllers\Api\ObjectPortalApiController;
use App\Http\Controllers\Api\ProductApiController;
use App\Http\Controllers\Api\ProjectApiController;
use App\Http\Controllers\Api\ProjectMessageApiController;
use App\Http\Controllers\Api\QuoteApiController;
use App\Http\Controllers\Api\SettingsApiController;
use App\Http\Controllers\Api\StripeWebhookApiController;
use App\Http\Controllers\Api\StripeTerminalController;
use App\Http\Controllers\Api\WalletApiController;
use App\Http\Controllers\Api\WidgetApiController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->as('api.')->group(function () {
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
    Route::post('/payments/stripe/webhook', StripeWebhookApiController::class);

    Route::get('/quotes/public/{token}', [QuoteApiController::class, 'publicView']);
    Route::get('/quotes/public/{token}/pdf', [QuoteApiController::class, 'publicPdf']);
    Route::middleware('doc.token')->group(function () {
        Route::get('/documents/quotes/{quote}/pdf', [QuoteApiController::class, 'pdf']);
        Route::get('/documents/quotes/{quote}/docx', [QuoteApiController::class, 'docx']);
        Route::get('/documents/invoices/{invoice}/pdf', [InvoiceApiController::class, 'pdf']);
        Route::get('/documents/invoices/{invoice}/download', [InvoiceApiController::class, 'download']);
        Route::get('/documents/products/{product}/pdf', [ProductApiController::class, 'pdf']);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/auth/change-password', [AuthController::class, 'changePassword']);
        Route::post('/notifications/devices', [NotificationDeviceApiController::class, 'store']);
        Route::delete('/notifications/devices', [NotificationDeviceApiController::class, 'destroy']);
    });

    Route::middleware(['auth:sanctum', 'force.password.change'])->group(function () {
        Route::get('/dashboard', [DashboardApiController::class, 'index']);
        Route::get('/widgets/summary', [WidgetApiController::class, 'summary']);
        Route::get('/objects', [ObjectPortalApiController::class, 'index']);
        Route::get('/wallet', [ClientWalletApiController::class, 'show']);
        Route::post('/wallet/checkout', [ClientWalletApiController::class, 'checkout']);
        Route::post('/wallet/checkout/finalize', [ClientWalletApiController::class, 'finalize']);
        Route::post('/wallet/checkout/cancel', [ClientWalletApiController::class, 'cancel']);
        Route::get('/stripe/connection-token', [StripeTerminalController::class, 'connectionToken'])->middleware('admin.only');
        Route::post('/stripe/payment-intent', [StripeTerminalController::class, 'paymentIntent'])->middleware('admin.only');
        Route::post('/stripe/payment-intent/sync', [StripeTerminalController::class, 'sync'])->middleware('admin.only');

        Route::apiResource('clients', ClientApiController::class);
        Route::post('/clients/{client}/notes', [ClientApiController::class, 'storeNote']);
        Route::post('/clients/{client}/duplicate', [ClientApiController::class, 'duplicate']);
        Route::post('/clients/{client}/portal-user', [ClientApiController::class, 'storePortalUser']);
        Route::post('/clients/{client}/temporary-password', [ClientApiController::class, 'regenerateTemporaryPassword']);
        Route::post('/clients/{client}/credential-objects/{object}/transfer', [ClientApiController::class, 'transferCredentialObject']);
        Route::post('/clients/{client}/credential-objects/{object}/promote', [ClientApiController::class, 'promoteCredentialObject']);
        Route::post('/clients/{client}/credential-objects', [ClientApiController::class, 'storeCredentialObject']);
        Route::delete('/clients/{client}/credential-objects/{object}', [ClientApiController::class, 'destroyCredentialObject']);
        Route::get('/clients/{client}/credential-objects/{object}/export', [ClientApiController::class, 'exportCredentialObject']);
        Route::post('/clients/{client}/credentials', [ClientApiController::class, 'storeCredential']);
        Route::delete('/clients/{client}/credentials/{credential}', [ClientApiController::class, 'destroyCredential']);

        Route::get('/projects/options', [ProjectApiController::class, 'options']);
        Route::apiResource('projects', ProjectApiController::class);
        Route::post('/projects/{project}/messages', [ProjectMessageApiController::class, 'store']);
        Route::get('/projects/{project}/credentials', [ProjectApiController::class, 'credentials']);
        Route::post('/projects/{project}/credentials', [ProjectApiController::class, 'storeCredential']);
        Route::delete('/projects/{project}/credentials/{credential}', [ProjectApiController::class, 'destroyCredential']);

        Route::apiResource('products', ProductApiController::class)->middleware('admin.only');
        Route::patch('/products/{product}/payment-methods', [ProductApiController::class, 'updatePaymentMethodsVisibility'])->middleware('admin.only');
        Route::get('/products/{product}/pdf', [ProductApiController::class, 'pdf'])->middleware('admin.only');

        Route::get('/quotes', [QuoteApiController::class, 'index'])->middleware('admin.only');
        Route::get('/quotes/{quote}', [QuoteApiController::class, 'show'])->middleware('admin.only');
        Route::post('/quotes/{quote}/adjudication', [QuoteApiController::class, 'updateAdjudication'])->middleware('admin.only');
        Route::get('/quotes/{quote}/pdf', [QuoteApiController::class, 'pdf']);
        Route::get('/quotes/{quote}/docx', [QuoteApiController::class, 'docx']);

        Route::get('/invoices', [InvoiceApiController::class, 'index']);
        Route::get('/invoices/{invoice}', [InvoiceApiController::class, 'show']);
        Route::put('/invoices/{invoice}', [InvoiceApiController::class, 'update']);
        Route::patch('/invoices/{invoice}', [InvoiceApiController::class, 'update']);
        Route::get('/invoices/{invoice}/pdf', [InvoiceApiController::class, 'pdf']);
        Route::get('/invoices/{invoice}/download', [InvoiceApiController::class, 'download']);
        Route::post('/invoices/{invoice}/paid', [InvoiceApiController::class, 'markPaid']);
        Route::post('/invoices/{invoice}/pending', [InvoiceApiController::class, 'markPending']);
        Route::post('/invoices/{invoice}/uninvoice', [InvoiceApiController::class, 'uninvoice']);

        Route::get('/company', [CompanyApiController::class, 'index'])->middleware('admin.only');
        Route::put('/company', [CompanyApiController::class, 'update'])->middleware('admin.only');
        Route::patch('/company', [CompanyApiController::class, 'update'])->middleware('admin.only');

        Route::get('/settings', [SettingsApiController::class, 'index'])->middleware('admin.only');
        Route::post('/settings/sales-goal', [SettingsApiController::class, 'updateSalesGoal'])->middleware('admin.only');
        Route::post('/settings/ide-toggle', [SettingsApiController::class, 'toggleIde'])->middleware('admin.only');

        Route::get('/finance', [FinanceApiController::class, 'index'])->middleware('admin.only');
        Route::post('/finance/installments', [FinanceApiController::class, 'storeInstallment'])->middleware('admin.only');
        Route::delete('/finance/installments/{installment}', [FinanceApiController::class, 'destroyInstallment'])->middleware('admin.only');
        Route::post('/finance/sales/{type}/{id}/installment', [FinanceApiController::class, 'updateInstallment'])->middleware('admin.only');
        Route::post('/finance/sales/transaction/{id}/to-invoice', [FinanceApiController::class, 'updateToInvoice'])->middleware('admin.only');
        Route::post('/finance/sales/project/{id}/to-invoice', [FinanceApiController::class, 'updateProjectToInvoice'])->middleware('admin.only');
        Route::post('/finance/sales/bulk-invoice', [FinanceApiController::class, 'bulkToInvoice'])->middleware('admin.only');
        Route::post('/finance/sales/bulk-uninvoice', [FinanceApiController::class, 'bulkUninvoice'])->middleware('admin.only');

        Route::get('/interventions', [InterventionApiController::class, 'index'])->middleware('admin.only');
        Route::post('/interventions', [InterventionApiController::class, 'store'])->middleware('admin.only');
        Route::post('/interventions/{intervention}/pause', [InterventionApiController::class, 'pause'])->middleware('admin.only');
        Route::post('/interventions/{intervention}/resume', [InterventionApiController::class, 'resume'])->middleware('admin.only');
        Route::post('/interventions/{intervention}/finish', [InterventionApiController::class, 'finish'])->middleware('admin.only');

        Route::get('/wallets', [WalletApiController::class, 'index'])->middleware('admin.only');
        Route::post('/wallets/transactions', [WalletApiController::class, 'storeTransaction'])->middleware('admin.only');
        Route::delete('/wallets/transactions/{transaction}', [WalletApiController::class, 'destroyTransaction'])->middleware('admin.only');
        Route::post('/wallets/packs', [WalletApiController::class, 'storePack'])->middleware('admin.only');
    });
});
