<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wallet_transactions', function (Blueprint $table) {
            $table->string('payment_provider')->nullable()->after('invoice_id');
            $table->string('payment_reference')->nullable()->after('payment_provider')->unique();
            $table->json('payment_metadata')->nullable()->after('payment_reference');
        });
    }

    public function down(): void
    {
        Schema::table('wallet_transactions', function (Blueprint $table) {
            $table->dropUnique(['payment_reference']);
            $table->dropColumn([
                'payment_provider',
                'payment_reference',
                'payment_metadata',
            ]);
        });
    }
};
