<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            if (! Schema::hasColumn('invoices', 'payment_method')) {
                $table->string('payment_method')->nullable()->after('paid_at');
            }

            if (! Schema::hasColumn('invoices', 'payment_account')) {
                $table->string('payment_account')->nullable()->after('payment_method');
            }
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $drops = [];

            if (Schema::hasColumn('invoices', 'payment_method')) {
                $drops[] = 'payment_method';
            }

            if (Schema::hasColumn('invoices', 'payment_account')) {
                $drops[] = 'payment_account';
            }

            if ($drops !== []) {
                $table->dropColumn($drops);
            }
        });
    }
};
