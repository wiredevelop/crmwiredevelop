<?php

namespace App\Support;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\PackItem;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;

class WalletPackPurchaseService
{
    public function registerManualPurchase(
        Client $client,
        Product $product,
        PackItem $packItem,
        int $quantity,
    ): array {
        return DB::transaction(function () use ($client, $product, $packItem, $quantity) {
            $seconds = (int) round(((float) ($packItem->hours ?? 0)) * 3600 * $quantity);
            $amount = round((float) ($packItem->pack_price ?? 0) * $quantity, 2);

            $invoice = Invoice::create([
                'client_id' => $client->id,
                'number' => Invoice::generateNumber(),
                'total' => $amount,
                'status' => 'pendente',
                'issued_at' => now(),
                'due_at' => now()->addDay(),
                'paid_at' => null,
                'payment_method' => 'Pagamento manual',
                'payment_account' => 'Aguarda liquidação manual',
            ]);

            $wallet = Wallet::firstOrCreate(
                ['client_id' => $client->id],
                ['balance_seconds' => 0, 'balance_amount' => 0]
            );

            $transaction = WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'purchase',
                'seconds' => $seconds,
                'amount' => $amount,
                'description' => 'Compra manual de pack: '.$this->productLabel($product, $packItem, $quantity),
                'product_id' => $product->id,
                'pack_item_id' => $packItem->id,
                'transaction_at' => now(),
                'to_invoice' => true,
                'invoice_id' => $invoice->id,
                'payment_provider' => 'manual',
                'payment_metadata' => [
                    'status' => 'pending',
                    'payment_mode' => 'manual',
                    'quantity' => $quantity,
                ],
            ]);

            $invoice->items()->create([
                'description' => $this->productLabel($product, $packItem, $quantity).' (Transação #'.$transaction->id.')',
                'quantity' => $quantity,
                'unit_price' => (float) $packItem->pack_price,
                'total' => $amount,
                'source_type' => 'transaction',
                'source_id' => $transaction->id,
            ]);

            $wallet->balance_seconds += $seconds;
            $wallet->balance_amount = (float) $wallet->balance_amount + $amount;
            $wallet->save();

            return compact('wallet', 'transaction', 'invoice');
        });
    }

    public function productLabel(Product $product, PackItem $packItem, int $quantity = 1): string
    {
        $label = $product->name;

        if ($packItem->hours) {
            $label .= ' - '.$packItem->hours.'h';
        }

        if ($quantity > 1) {
            $label .= ' (x'.$quantity.')';
        }

        return $label;
    }
}
