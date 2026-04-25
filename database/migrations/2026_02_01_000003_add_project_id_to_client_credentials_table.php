<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('client_credentials') || Schema::hasColumn('client_credentials', 'project_id')) {
            return;
        }

        Schema::table('client_credentials', function (Blueprint $table) {
            $table->foreignId('project_id')->nullable()->after('client_id')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('client_credentials') || !Schema::hasColumn('client_credentials', 'project_id')) {
            return;
        }

        Schema::table('client_credentials', function (Blueprint $table) {
            $table->dropConstrainedForeignId('project_id');
        });
    }
};
