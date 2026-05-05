<?php

namespace App\Support;

use App\Models\Client;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;

class WalletProductPurchaseService
{
    public function registerManualPurchase(
        Client $client,
        Product $product,
        int $quantity,
    ): array {
        return DB::transaction(function () use ($client, $product, $quantity) {
            $unitPrice = round((float) ($product->price ?? 0), 2);
            $amount = round($unitPrice * $quantity, 2);

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
                'seconds' => null,
                'amount' => $amount,
                'description' => 'Compra manual de produto: '.$this->productLabel($product, $quantity),
                'product_id' => $product->id,
                'transaction_at' => now(),
                'to_invoice' => true,
                'invoice_id' => $invoice->id,
                'payment_provider' => 'manual',
                'payment_metadata' => [
                    'status' => 'pending',
                    'payment_mode' => 'manual',
                    'quantity' => $quantity,
                    'is_monthly_recurring' => (bool) $product->is_monthly_recurring,
                ],
            ]);

            $invoice->items()->create([
                'description' => $this->productLabel($product, $quantity).' (Transação #'.$transaction->id.')',
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'total' => $amount,
                'source_type' => 'transaction',
                'source_id' => $transaction->id,
            ]);

            $wallet->balance_amount = (float) $wallet->balance_amount + $amount;
            $wallet->save();

            return compact('wallet', 'transaction', 'invoice');
        });
    }

    public function productLabel(Product $product, int $quantity = 1): string
    {
        $label = $product->name;

        if ($product->is_monthly_recurring) {
            $label .= ' - mensal';
        }

        if ($quantity > 1) {
            $label .= ' (x'.$quantity.')';
        }

        return $label;
    }
}
