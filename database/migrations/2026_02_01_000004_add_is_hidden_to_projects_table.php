<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('projects') || Schema::hasColumn('projects', 'is_hidden')) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            $table->boolean('is_hidden')->default(false)->after('status');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('projects') || !Schema::hasColumn('projects', 'is_hidden')) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            $table->dropColumn('is_hidden');
        });
    }
};
