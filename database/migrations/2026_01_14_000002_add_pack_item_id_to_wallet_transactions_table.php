<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('wallet_transactions')) {
            return;
        }

        if (!Schema::hasColumn('wallet_transactions', 'pack_item_id')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->foreignId('pack_item_id')->nullable()->constrained()->nullOnDelete()->after('product_id');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('wallet_transactions')) {
            return;
        }

        if (Schema::hasColumn('wallet_transactions', 'pack_item_id')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->dropConstrainedForeignId('pack_item_id');
            });
        }
    }
};
