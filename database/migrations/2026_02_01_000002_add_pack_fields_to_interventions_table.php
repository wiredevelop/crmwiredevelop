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

        Schema::table('interventions', function (Blueprint $table) {
            if (!Schema::hasColumn('interventions', 'is_pack')) {
                $table->boolean('is_pack')->default(true);
            }
            if (!Schema::hasColumn('interventions', 'hourly_rate')) {
                $table->decimal('hourly_rate', 10, 2)->nullable();
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('interventions')) {
            return;
        }

        Schema::table('interventions', function (Blueprint $table) {
            if (Schema::hasColumn('interventions', 'is_pack')) {
                $table->dropColumn('is_pack');
            }
            if (Schema::hasColumn('interventions', 'hourly_rate')) {
                $table->dropColumn('hourly_rate');
            }
        });
    }
};
