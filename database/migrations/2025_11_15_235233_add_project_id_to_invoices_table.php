<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {

            $table->string('payment_method')->nullable();   // multibanco, mbway, paypal, transferência
            $table->string('payment_account')->nullable();  // conta Wire, PayPal, Revolut, Santander
            $table->timestamp('paid_at')->nullable();       // quando foi pago
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn(['payment_method', 'payment_account', 'paid_at']);
        });
    }
};
