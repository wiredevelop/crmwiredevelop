<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('interventions')) {
            return;
        }

        if (!Schema::hasColumn('interventions', 'finish_notes')) {
            Schema::table('interventions', function (Blueprint $table) {
                $table->text('finish_notes')->nullable()->after('notes');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('interventions')) {
            return;
        }

        if (Schema::hasColumn('interventions', 'finish_notes')) {
            Schema::table('interventions', function (Blueprint $table) {
                $table->dropColumn('finish_notes');
            });
        }
    }
};
