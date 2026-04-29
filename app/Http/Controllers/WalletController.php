<?php

namespace App\Http\Controllers;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Support\StripeCheckoutService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class WalletController extends Controller
{
    public function index(Request $request): Response
    {
        if ($request->filled('session_id')) {
            app(StripeCheckoutService::class)->syncCheckoutSession($request->string('session_id')->toString());
        }

        if ($request->filled('token')) {
            app(StripeCheckoutService::class)->cancelByToken($request->string('token')->toString());
        }

        $clients = Client::orderBy('name')->get(['id', 'name', 'company']);
        $selectedClientId = $request->query('client_id');

        if (! $selectedClientId && $clients->isNotEmpty()) {
            $selectedClientId = $clients->first()->id;
        }

        if ($selectedClientId && ! $clients->contains('id', (int) $selectedClientId)) {
            $selectedClientId = null;
        }

        $wallet = null;
        $transactions = [];
        $selectedClient = null;
        $packs = Product::with('packItems')
            ->where('type', 'pack')
            ->where('active', true)
            ->orderBy('name')
            ->get()
            ->map(function ($pack) {
                return [
                    'id' => $pack->id,
                    'name' => $pack->name,
                    'pack_items' => $pack->packItems
                        ->sortBy('order')
                        ->values()
                        ->map(fn ($item) => [
                            'id' => $item->id,
                            'hours' => $item->hours,
                            'normal_price' => $item->normal_price,
                            'pack_price' => $item->pack_price,
                            'validity_months' => $item->validity_months,
                            'featured' => (bool) $item->featured,
                        ])
                        ->toArray(),
                ];
            });

        if ($selectedClientId) {
            $selectedClient = Client::find($selectedClientId);
            $wallet = Wallet::firstOrCreate([
                'client_id' => $selectedClientId,
            ], [
                'balance_seconds' => 0,
                'balance_amount' => 0,
            ]);

            $transactions = WalletTransaction::with([
                'product:id,name',
                'packItem:id,product_id,hours,pack_price,validity_months',
                'intervention:id,type',
                'invoice:id,number,status',
            ])
                ->where('wallet_id', $wallet->id)
                ->orderByDesc('transaction_at')
                ->take(50)
                ->get();
        }

        return Inertia::render('Wallets/Index', [
            'clients' => $clients,
            'selectedClientId' => $selectedClientId,
            'selectedClient' => $selectedClient,
            'wallet' => $wallet,
            'transactions' => $transactions,
            'packs' => $packs,
            'stripeAvailable' => (bool) config('services.stripe.secret_key')
                && (bool) config('services.stripe.public_key'),
        ]);
    }

    public function storeTransaction(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'type' => ['required', 'in:purchase,expense,adjustment'],
            'hours' => ['nullable', 'numeric', 'min:0'],
            'amount' => ['nullable', 'numeric'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $hoursValue = $data['hours'] ?? null;
        $amountValue = $data['amount'] ?? null;

        if (($hoursValue === null || $hoursValue === '') && ($amountValue === null || $amountValue === '')) {
            return back()->withErrors(['hours' => 'Indica horas ou valor.']);
        }

        $seconds = null;
        if ($hoursValue !== null && $hoursValue !== '') {
            $seconds = (int) round(((float) $hoursValue) * 3600);
            if ($data['type'] === 'expense' && $seconds > 0) {
                $seconds = -$seconds;
            }
            if ($data['type'] === 'purchase' && $seconds < 0) {
                $seconds = abs($seconds);
            }
        }

        $amount = null;
        if ($amountValue !== null && $amountValue !== '') {
            $amount = (float) $amountValue;
            if ($data['type'] === 'expense' && $amount > 0) {
                $amount = -$amount;
            }
            if ($data['type'] === 'purchase' && $amount < 0) {
                $amount = abs($amount);
            }
        }

        $wallet = Wallet::firstOrCreate([
            'client_id' => $data['client_id'],
        ], [
            'balance_seconds' => 0,
            'balance_amount' => 0,
        ]);

        WalletTransaction::create([
            'wallet_id' => $wallet->id,
            'type' => $data['type'],
            'seconds' => $seconds,
            'amount' => $amount,
            'description' => $data['description'] ?? null,
            'transaction_at' => now(),
        ]);

        if ($seconds !== null) {
            $wallet->balance_seconds += $seconds;
        }

        if ($amount !== null) {
            $wallet->balance_amount = (float) $wallet->balance_amount + $amount;
        }

        $wallet->save();

        return back()->with('success', 'Transação registada.');
    }

    public function destroyTransaction(
        WalletTransaction $transaction,
        StripeCheckoutService $stripeCheckout
    ): RedirectResponse
    {
        $transaction->load('wallet');

        if ($this->isPendingStripeTransaction($transaction)) {
            $stripeCheckout->cancelPaymentIntent($transaction->payment_reference);

            return back()->with('success', 'Transação pendente cancelada.');
        }

        DB::transaction(function () use ($transaction) {
            if ($transaction->invoice_id) {
                $invoice = Invoice::with('items')->find($transaction->invoice_id);
                if ($invoice) {
                    $invoice->items()
                        ->where('source_type', 'transaction')
                        ->where('source_id', $transaction->id)
                        ->delete();

                    if ($invoice->items()->count() === 0) {
                        $invoice->delete();
                    } else {
                        $invoice->total = (float) $invoice->items()->sum('total');
                        $invoice->save();
                    }
                }
            }

            $wallet = $transaction->wallet;
            if ($wallet) {
                if ($this->transactionAffectsWalletBalance($transaction) && $transaction->seconds !== null) {
                    $wallet->balance_seconds -= (int) $transaction->seconds;
                }

                if ($this->transactionAffectsWalletBalance($transaction) && $transaction->amount !== null) {
                    $wallet->balance_amount = (float) $wallet->balance_amount - (float) $transaction->amount;
                }

                $wallet->save();
            }

            $transaction->delete();
        });

        return back()->with('success', 'Transação removida.');
    }

    private function isPendingStripeTransaction(WalletTransaction $transaction): bool
    {
        $payment = is_array($transaction->payment_metadata) ? $transaction->payment_metadata : [];

        return $transaction->payment_provider === 'stripe'
            && ($payment['status'] ?? null) === 'pending'
            && is_string($transaction->payment_reference)
            && $transaction->payment_reference !== '';
    }

    private function transactionAffectsWalletBalance(WalletTransaction $transaction): bool
    {
        $payment = is_array($transaction->payment_metadata) ? $transaction->payment_metadata : [];

        return ! (
            $transaction->payment_provider === 'stripe'
            && ($payment['status'] ?? null) === 'pending'
        );
    }
}
