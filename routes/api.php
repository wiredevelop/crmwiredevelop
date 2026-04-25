<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientApiController;
use App\Http\Controllers\Api\CompanyApiController;
use App\Http\Controllers\Api\DashboardApiController;
use App\Http\Controllers\Api\FinanceApiController;
use App\Http\Controllers\Api\InvoiceApiController;
use App\Http\Controllers\Api\InterventionApiController;
use App\Http\Controllers\Api\ProductApiController;
use App\Http\Controllers\Api\ProjectApiController;
use App\Http\Controllers\Api\QuoteApiController;
use App\Http\Controllers\Api\SettingsApiController;
use App\Http\Controllers\Api\WalletApiController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->as('api.')->group(function () {
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');

    Route::get('/quotes/public/{token}', [QuoteApiController::class, 'publicView']);
    Route::get('/quotes/public/{token}/pdf', [QuoteApiController::class, 'publicPdf']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/dashboard', [DashboardApiController::class, 'index']);

        Route::apiResource('clients', ClientApiController::class);
        Route::post('/clients/{client}/notes', [ClientApiController::class, 'storeNote']);
        Route::post('/clients/{client}/duplicate', [ClientApiController::class, 'duplicate']);
        Route::post('/clients/{client}/credential-objects', [ClientApiController::class, 'storeCredentialObject']);
        Route::delete('/clients/{client}/credential-objects/{object}', [ClientApiController::class, 'destroyCredentialObject']);
        Route::get('/clients/{client}/credential-objects/{object}/export', [ClientApiController::class, 'exportCredentialObject']);
        Route::post('/clients/{client}/credentials', [ClientApiController::class, 'storeCredential']);
        Route::delete('/clients/{client}/credentials/{credential}', [ClientApiController::class, 'destroyCredential']);

        Route::get('/projects/options', [ProjectApiController::class, 'options']);
        Route::apiResource('projects', ProjectApiController::class);
        Route::get('/projects/{project}/credentials', [ProjectApiController::class, 'credentials']);
        Route::post('/projects/{project}/credentials', [ProjectApiController::class, 'storeCredential']);
        Route::delete('/projects/{project}/credentials/{credential}', [ProjectApiController::class, 'destroyCredential']);

        Route::apiResource('products', ProductApiController::class);
        Route::patch('/products/{product}/payment-methods', [ProductApiController::class, 'updatePaymentMethodsVisibility']);
        Route::get('/products/{product}/pdf', [ProductApiController::class, 'pdf']);

        Route::get('/quotes', [QuoteApiController::class, 'index']);
        Route::get('/quotes/{quote}', [QuoteApiController::class, 'show']);
        Route::post('/quotes/{quote}/adjudication', [QuoteApiController::class, 'updateAdjudication']);
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

        Route::get('/company', [CompanyApiController::class, 'index']);
        Route::put('/company', [CompanyApiController::class, 'update']);
        Route::patch('/company', [CompanyApiController::class, 'update']);

        Route::get('/settings', [SettingsApiController::class, 'index']);
        Route::post('/settings/sales-goal', [SettingsApiController::class, 'updateSalesGoal']);
        Route::post('/settings/ide-toggle', [SettingsApiController::class, 'toggleIde']);

        Route::get('/finance', [FinanceApiController::class, 'index']);
        Route::post('/finance/installments', [FinanceApiController::class, 'storeInstallment']);
        Route::delete('/finance/installments/{installment}', [FinanceApiController::class, 'destroyInstallment']);
        Route::post('/finance/sales/{type}/{id}/installment', [FinanceApiController::class, 'updateInstallment']);
        Route::post('/finance/sales/transaction/{id}/to-invoice', [FinanceApiController::class, 'updateToInvoice']);
        Route::post('/finance/sales/project/{id}/to-invoice', [FinanceApiController::class, 'updateProjectToInvoice']);
        Route::post('/finance/sales/bulk-invoice', [FinanceApiController::class, 'bulkToInvoice']);
        Route::post('/finance/sales/bulk-uninvoice', [FinanceApiController::class, 'bulkUninvoice']);

        Route::get('/interventions', [InterventionApiController::class, 'index']);
        Route::post('/interventions', [InterventionApiController::class, 'store']);
        Route::post('/interventions/{intervention}/pause', [InterventionApiController::class, 'pause']);
        Route::post('/interventions/{intervention}/resume', [InterventionApiController::class, 'resume']);
        Route::post('/interventions/{intervention}/finish', [InterventionApiController::class, 'finish']);

        Route::get('/wallets', [WalletApiController::class, 'index']);
        Route::post('/wallets/transactions', [WalletApiController::class, 'storeTransaction']);
        Route::delete('/wallets/transactions/{transaction}', [WalletApiController::class, 'destroyTransaction']);
        Route::post('/wallets/packs', [WalletApiController::class, 'storePack']);
    });
});
