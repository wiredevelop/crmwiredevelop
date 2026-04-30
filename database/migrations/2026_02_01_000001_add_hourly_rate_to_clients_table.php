<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('clients') || Schema::hasColumn('clients', 'hourly_rate')) {
            return;
        }

        Schema::table('clients', function (Blueprint $table) {
            $table->decimal('hourly_rate', 10, 2)->nullable();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('clients') || ! Schema::hasColumn('clients', 'hourly_rate')) {
            return;
        }

        Schema::table('clients', function (Blueprint $table) {
            $table->dropColumn('hourly_rate');
        });
    }
};
