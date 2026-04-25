<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class WalletPackController extends Controller
{
    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'client_id' => ['required', 'exists:clients,id'],
            'product_id' => ['required', 'exists:products,id'],
            'pack_item_id' => ['required', 'exists:pack_items,id'],
            'quantity' => ['nullable', 'integer', 'min:1'],
        ]);

        $quantity = $data['quantity'] ?? 1;

        $product = Product::with('packItems')
            ->where('type', 'pack')
            ->findOrFail($data['product_id']);

        $packItem = $product->packItems->firstWhere('id', (int) $data['pack_item_id']);

        if (!$packItem) {
            return back()->with('error', 'Opção de pack inválida.');
        }

        $hours = (float) ($packItem->hours ?? 0);
        $seconds = (int) round($hours * 3600 * $quantity);
        $amount = (float) (($packItem->pack_price ?? 0) * $quantity);

        $wallet = Wallet::firstOrCreate([
            'client_id' => $data['client_id'],
        ], [
            'balance_seconds' => 0,
            'balance_amount' => 0,
        ]);

        $description = 'Compra de pack: ' . $product->name;
        if ($packItem->hours) {
            $description .= ' - ' . $packItem->hours . 'h';
        }
        if ($quantity > 1) {
            $description .= ' (x' . $quantity . ')';
        }

            WalletTransaction::create([
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

        return back()->with('success', 'Pack associado e transação registada.');
    }
}
