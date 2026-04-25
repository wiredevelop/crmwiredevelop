<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('clients')) {
            return;
        }

        Schema::table('clients', function (Blueprint $table) {
            if (!Schema::hasColumn('clients', 'internal_notes')) {
                $table->json('internal_notes')->nullable();
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('clients') || !Schema::hasColumn('clients', 'internal_notes')) {
            return;
        }

        Schema::table('clients', function (Blueprint $table) {
            $table->dropColumn('internal_notes');
        });
    }
};
