<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('wallet_transactions')) {
            return;
        }

        if (! Schema::hasColumn('wallet_transactions', 'seconds')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->bigInteger('seconds')->nullable()->after('type');
            });
        }

        if (Schema::hasColumn('wallet_transactions', 'minutes')) {
            DB::table('wallet_transactions')->update([
                'seconds' => DB::raw('minutes * 60'),
            ]);
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('wallet_transactions')) {
            return;
        }

        if (Schema::hasColumn('wallet_transactions', 'seconds')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->dropColumn('seconds');
            });
        }
    }
};
