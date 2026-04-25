<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('pack_items', function (Blueprint $table) {
            if (!Schema::hasColumn('pack_items', 'created_at')) {
                $table->timestamps();
            }
        });
    }

    public function down(): void
    {
        Schema::table('pack_items', function (Blueprint $table) {
            if (Schema::hasColumn('pack_items', 'created_at')) {
                $table->dropTimestamps();
            }
        });
    }
};
