<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            if (! Schema::hasColumn('invoices', 'payment_provider')) {
                $table->string('payment_provider')->nullable()->after('payment_account');
            }

            if (! Schema::hasColumn('invoices', 'payment_reference')) {
                $table->string('payment_reference')->nullable()->after('payment_provider');
            }

            if (! Schema::hasColumn('invoices', 'payment_metadata')) {
                $table->json('payment_metadata')->nullable()->after('payment_reference');
            }
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $drops = [];

            if (Schema::hasColumn('invoices', 'payment_provider')) {
                $drops[] = 'payment_provider';
            }

            if (Schema::hasColumn('invoices', 'payment_reference')) {
                $drops[] = 'payment_reference';
            }

            if (Schema::hasColumn('invoices', 'payment_metadata')) {
                $drops[] = 'payment_metadata';
            }

            if ($drops !== []) {
                $table->dropColumn($drops);
            }
        });
    }
};
