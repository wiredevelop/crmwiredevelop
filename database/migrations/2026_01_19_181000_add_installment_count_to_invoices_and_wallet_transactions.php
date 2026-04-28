<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->unsignedInteger('installment_count')->nullable();
        });

        Schema::table('wallet_transactions', function (Blueprint $table) {
            $table->unsignedInteger('installment_count')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('installment_count');
        });

        Schema::table('wallet_transactions', function (Blueprint $table) {
            $table->dropColumn('installment_count');
        });
    }
};
