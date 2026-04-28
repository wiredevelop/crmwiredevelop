<?php

use App\Http\Controllers\ClientController;
use App\Http\Controllers\ClientCredentialController;
use App\Http\Controllers\ClientCredentialObjectController;
use App\Http\Controllers\CompanyController;
use App\Http\Controllers\ClientWalletController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\FinanceController;
use App\Http\Controllers\InterventionController;
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\ObjectPortalController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\ProjectCredentialController;
use App\Http\Controllers\QuoteController;
use App\Http\Controllers\StripeCheckoutStatusController;
use App\Http\Controllers\WalletController;
use App\Http\Controllers\WalletPackController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/login');
Route::get('/checkout/stripe/sucesso', [StripeCheckoutStatusController::class, 'success']);
Route::get('/checkout/stripe/cancelado', [StripeCheckoutStatusController::class, 'cancel']);

// DASHBOARD
Route::get('/dashboard', [DashboardController::class, 'index'])
    ->middleware(['auth', 'verified', 'force.password.change'])
    ->name('dashboard');

// ROTAS QUE EXIGEM AUTENTICAÇÃO
Route::middleware(['auth', 'force.password.change'])->group(function () {

    // Profile
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // Clientes
    Route::get('/objects', [ObjectPortalController::class, 'index'])->name('objects.index');
    Route::get('/wallet', [ClientWalletController::class, 'show'])->name('wallet.show');
    Route::resource('clients', ClientController::class);
    Route::post('/clients/{client}/notes', [ClientController::class, 'storeNote'])->name('clients.storeNote');
    Route::post('/clients/{client}/duplicate', [ClientController::class, 'duplicate'])->name('clients.duplicate');
    Route::post('/clients/{client}/portal-user', [ClientController::class, 'storePortalUser'])->name('clients.portalUser.store');
    Route::post('/clients/{client}/temporary-password', [ClientController::class, 'regenerateTemporaryPassword'])->name('clients.temporaryPassword');
    Route::post('/clients/{client}/credential-objects/{object}/transfer', [ClientController::class, 'transferCredentialObject'])
        ->name('clients.credentialObjects.transfer');
    Route::post('/clients/{client}/credential-objects/{object}/promote', [ClientController::class, 'promoteCredentialObject'])
        ->name('clients.credentialObjects.promote');
    Route::post('/clients/{client}/credential-objects', [ClientCredentialObjectController::class, 'store'])
        ->name('clients.credentialObjects.store');
    Route::get('/clients/{client}/credential-objects/{object}/export', [ClientCredentialObjectController::class, 'export'])
        ->name('clients.credentialObjects.export');
    Route::delete('/clients/{client}/credential-objects/{object}', [ClientCredentialObjectController::class, 'destroy'])
        ->name('clients.credentialObjects.destroy');
    Route::post('/clients/{client}/credentials', [ClientCredentialController::class, 'store'])
        ->name('clients.credentials.store');
    Route::delete('/clients/{client}/credentials/{credential}', [ClientCredentialController::class, 'destroy'])
        ->name('clients.credentials.destroy');

    // Projects
    Route::resource('projects', ProjectController::class);
    Route::get('/projects/{project}/credentials', [ProjectCredentialController::class, 'index'])
        ->name('projects.credentials.index');
    Route::post('/projects/{project}/credentials', [ProjectCredentialController::class, 'store'])
        ->name('projects.credentials.store');
    Route::delete('/projects/{project}/credentials/{credential}', [ProjectCredentialController::class, 'destroy'])
        ->name('projects.credentials.destroy');

    // qUOTES
    Route::get('/quotes', [QuoteController::class, 'index'])
        ->middleware('admin.only')
        ->name('quotes.index');

    Route::get('/quotes/{quote}', [QuoteController::class, 'show'])
        ->middleware(['auth', 'admin.only'])
        ->name('quotes.show');

    Route::get('/quotes/{quote}/pdf', [QuoteController::class, 'pdf'])->name('quotes.pdf');
    Route::get('/quotes/{quote}/docx', [QuoteController::class, 'docx'])->name('quotes.docx');
    Route::get('/quotes/{quote}/docx-partner', [QuoteController::class, 'partnerDocx'])->name('quotes.docx.partner');
    Route::post('/quotes/{quote}/adjudication', [QuoteController::class, 'updateAdjudication'])
        ->middleware('admin.only')
        ->name('quotes.adjudication');

    // Ver orçamento público
    Route::get('/q/{token}', [QuoteController::class, 'publicView'])->name('quotes.public');

    // PDF público
    Route::get('/q/{token}/pdf', [QuoteController::class, 'publicPdf'])->name('quotes.public.pdf');

    Route::get('/products/{product}/pdf', [ProductController::class, 'pdf'])->middleware('admin.only')->name('products.pdf');
    Route::patch('/products/{product}/payment-methods', [ProductController::class, 'updatePaymentMethodsVisibility'])
        ->middleware('admin.only')
        ->name('products.paymentMethods');
    Route::resource('products', ProductController::class)->middleware('admin.only');

    // Invoices
    Route::resource('invoices', InvoiceController::class);
    Route::get('/invoices/{invoice}/download', [InvoiceController::class, 'download'])
        ->name('invoices.download');

    Route::get('/invoices/{invoice}/pdf', [InvoiceController::class, 'pdf'])->name('invoices.pdf');
    Route::post('/invoices/{invoice}/paid', [InvoiceController::class, 'markPaid'])->name('invoices.paid');
    Route::post('/invoices/{invoice}/pending', [InvoiceController::class, 'markPending'])->name('invoices.pending');
    Route::post('/invoices/{invoice}/uninvoice', [InvoiceController::class, 'uninvoice'])
        ->name('invoices.uninvoice');

    // Settings
    Route::get('/settings', [\App\Http\Controllers\SettingsController::class, 'index'])
        ->middleware('admin.only')
        ->name('settings.index');
    Route::post('/settings/sales-goal', [\App\Http\Controllers\SettingsController::class, 'updateSalesGoal'])
        ->middleware('admin.only')
        ->name('settings.salesGoal');
    Route::post('/settings/ide-toggle', [\App\Http\Controllers\SettingsController::class, 'toggleIde'])
        ->middleware('admin.only')
        ->name('settings.ide.toggle');

    // Financeiro
    Route::get('/finance', [FinanceController::class, 'index'])
        ->middleware('admin.only')
        ->name('finance.index');
    Route::post('/finance/sales/{type}/{id}/installment', [FinanceController::class, 'updateInstallment'])
        ->middleware('admin.only')
        ->name('finance.sales.installment');
    Route::post('/finance/sales/transaction/{id}/to-invoice', [FinanceController::class, 'updateToInvoice'])
        ->middleware('admin.only')
        ->name('finance.sales.toInvoice');
    Route::post('/finance/sales/project/{id}/to-invoice', [FinanceController::class, 'updateProjectToInvoice'])
        ->middleware('admin.only')
        ->name('finance.sales.projectToInvoice');
    Route::post('/finance/sales/bulk-invoice', [FinanceController::class, 'bulkToInvoice'])
        ->middleware('admin.only')
        ->name('finance.sales.bulkInvoice');
    Route::post('/finance/sales/bulk-uninvoice', [FinanceController::class, 'bulkUninvoice'])
        ->middleware('admin.only')
        ->name('finance.sales.bulkUninvoice');
    Route::post('/finance/installments', [FinanceController::class, 'storeInstallment'])
        ->middleware('admin.only')
        ->name('finance.installments.store');
    Route::delete('/finance/installments/{installment}', [FinanceController::class, 'destroyInstallment'])
        ->middleware('admin.only')
        ->name('finance.installments.destroy');

    // Dados da empresa
    Route::get('/company', [CompanyController::class, 'index'])
        ->middleware('admin.only')
        ->name('company.index');
    Route::post('/company', [CompanyController::class, 'update'])
        ->middleware('admin.only')
        ->name('company.update');

    // Intervenções
    Route::get('/interventions', [InterventionController::class, 'index'])
        ->middleware('admin.only')
        ->name('interventions.index');
    Route::post('/interventions', [InterventionController::class, 'store'])
        ->middleware('admin.only')
        ->name('interventions.store');
    Route::post('/interventions/{intervention}/pause', [InterventionController::class, 'pause'])
        ->middleware('admin.only')
        ->name('interventions.pause');
    Route::post('/interventions/{intervention}/resume', [InterventionController::class, 'resume'])
        ->middleware('admin.only')
        ->name('interventions.resume');
    Route::post('/interventions/{intervention}/finish', [InterventionController::class, 'finish'])
        ->middleware('admin.only')
        ->name('interventions.finish');

    // Carteiras + transações
    Route::get('/wallets', [WalletController::class, 'index'])
        ->middleware('admin.only')
        ->name('wallets.index');
    Route::post('/wallets/transactions', [WalletController::class, 'storeTransaction'])
        ->middleware('admin.only')
        ->name('wallets.transactions.store');
    Route::delete('/wallets/transactions/{transaction}', [WalletController::class, 'destroyTransaction'])
        ->middleware('admin.only')
        ->name('wallets.transactions.destroy');

    // Packs do cliente
    Route::post('/wallets/packs', [WalletPackController::class, 'store'])
        ->middleware('admin.only')
        ->name('wallets.packs.store');
    Route::post('/wallets/packs/stripe', [WalletPackController::class, 'checkoutStripe'])
        ->middleware('admin.only')
        ->name('wallets.packs.stripe');
});

require __DIR__.'/auth.php';
