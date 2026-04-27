<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('wallets')) {
            return;
        }

        if (! Schema::hasColumn('wallets', 'balance_seconds')) {
            Schema::table('wallets', function (Blueprint $table) {
                $table->bigInteger('balance_seconds')->default(0)->after('client_id');
            });
        }

        if (Schema::hasColumn('wallets', 'balance_minutes')) {
            DB::table('wallets')->update([
                'balance_seconds' => DB::raw('balance_minutes * 60'),
            ]);
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('wallets')) {
            return;
        }

        if (Schema::hasColumn('wallets', 'balance_seconds')) {
            Schema::table('wallets', function (Blueprint $table) {
                $table->dropColumn('balance_seconds');
            });
        }
    }
};
