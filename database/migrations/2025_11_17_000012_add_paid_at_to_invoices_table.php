<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('invoices') || Schema::hasColumn('invoices', 'paid_at')) {
            return;
        }

        Schema::table('invoices', function (Blueprint $table) {
            $table->timestamp('paid_at')->nullable()->after('due_at');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('invoices') || !Schema::hasColumn('invoices', 'paid_at')) {
            return;
        }

        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('paid_at');
        });
    }
};
