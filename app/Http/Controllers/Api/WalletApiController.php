<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\WalletResource;
use App\Http\Resources\Api\WalletTransactionResource;
use App\Models\Client;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WalletApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $clients = Client::orderBy('name')->get(['id', 'name', 'company']);
        $selectedClientId = $request->query('client_id');

        if (!$selectedClientId && $clients->isNotEmpty()) {
            $selectedClientId = $clients->first()->id;
        }

        if ($selectedClientId && !$clients->contains('id', (int) $selectedClientId)) {
            $selectedClientId = null;
        }

        $wallet = null;
        $transactions = collect();
        $selectedClient = null;
        $packs = Product::with('packItems')
            ->where('type', 'pack')
            ->where('active', true)
            ->orderBy('name')
            ->get()
            ->map(fn ($pack) => [
                'id' => $pack->id,
                'name' => $pack->name,
                'pack_items' => $pack->packItems->sortBy('order')->values()->map(fn ($item) => [
                    'id' => $item->id,
                    'hours' => $item->hours,
                    'normal_price' => $item->normal_price,
                    'pack_price' => $item->pack_price,
                    'validity_months' => $item->validity_months,
                    'featured' => (bool) $item->featured,
                ])->toArray(),
            ]);

        if ($selectedClientId) {
            $selectedClient = Client::find($selectedClientId);
            $wallet = Wallet::firstOrCreate(['client_id' => $selectedClientId], ['balance_seconds' => 0, 'balance_amount' => 0]);
            $wallet->load('client');
            $transactions = WalletTransaction::with(['product:id,name', 'packItem:id,product_id,hours,pack_price,validity_months', 'intervention:id,type', 'invoice:id,number,status'])
                ->where('wallet_id', $wallet->id)
                ->orderByDesc('transaction_at')
                ->take(50)
                ->get();
        }

        return $this->success([
            'clients' => $clients,
            'selected_client_id' => $selectedClientId,
            'selected_client' => $selectedClient,
            'wallet' => $wallet ? new WalletResource($wallet) : null,
            'transactions' => WalletTransactionResource::collection($transactions),
            'packs' => $packs,
        ]);
    }

    public function storeTransaction(Request $request): JsonResponse
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
            return $this->error('Indica horas ou valor.', ['hours' => ['Indica horas ou valor.']], 422);
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

        $wallet = Wallet::firstOrCreate(['client_id' => $data['client_id']], ['balance_seconds' => 0, 'balance_amount' => 0]);

        $transaction = WalletTransaction::create([
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

        return $this->success(['transaction' => new WalletTransactionResource($transaction)], 'Transação registada.', 201);
    }

    public function destroyTransaction(WalletTransaction $transaction): JsonResponse
    {
        $transaction->load('wallet');

        DB::transaction(function () use ($transaction) {
            if ($transaction->invoice_id) {
                $invoice = Invoice::with('items')->find($transaction->invoice_id);
                if ($invoice) {
                    $invoice->items()->where('source_type', 'transaction')->where('source_id', $transaction->id)->delete();

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
                if ($transaction->seconds !== null) {
                    $wallet->balance_seconds -= (int) $transaction->seconds;
                }

                if ($transaction->amount !== null) {
                    $wallet->balance_amount = (float) $wallet->balance_amount - (float) $transaction->amount;
                }

                $wallet->save();
            }

            $transaction->delete();
        });

        return $this->success([], 'Transação removida.');
    }

    public function storePack(Request $request): JsonResponse
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'product_id' => ['required', 'exists:products,id'],
            'pack_item_id' => ['required', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1'],
        ]);

        $quantity = $data['quantity'] ?? 1;
        $product = Product::with('packItems')->where('type', 'pack')->findOrFail($data['product_id']);
        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);

        if (!$packItem) {
            return $this->error('Opção de pack inválida.', [], 422);
        }

        $hours = (float) ($packItem->hours ?? 0);
        $seconds = (int) round($hours * 3600 * $quantity);
        $amount = (float) (($packItem->pack_price ?? 0) * $quantity);

        $wallet = Wallet::firstOrCreate(['client_id' => $data['client_id']], ['balance_seconds' => 0, 'balance_amount' => 0]);
        $description = 'Compra de pack: ' . $product->name;
        if ($packItem->hours) {
            $description .= ' - ' . $packItem->hours . 'h';
        }
        if ($quantity > 1) {
            $description .= ' (x' . $quantity . ')';
        }

        $transaction = WalletTransaction::create([
            'wallet_id' => $wallet->id,
            'type' => 'purchase',
            'seconds' => $seconds,
            'amount' => $amount,
            'description' => $description,
            'product_id' => $product->id,
            'pack_item_id' => $packItem->id,
            'transaction_at' => now(),
        ]);

        $wallet->balance_seconds += $seconds;
        $wallet->balance_amount = (float) $wallet->balance_amount + $amount;
        $wallet->save();

        return $this->success(['transaction' => new WalletTransactionResource($transaction)], 'Pack associado e transação registada.', 201);
    }
}
