<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('projects') || ! Schema::hasTable('clients')) {
            return;
        }

        $dbName = DB::getDatabaseName();
        $hasFk = DB::table('information_schema.KEY_COLUMN_USAGE')
            ->where('TABLE_SCHEMA', $dbName)
            ->where('TABLE_NAME', 'projects')
            ->where('COLUMN_NAME', 'client_id')
            ->whereNotNull('REFERENCED_TABLE_NAME')
            ->exists();

        if ($hasFk) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            $table->foreign('client_id')
                ->references('id')
                ->on('clients')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('projects')) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            $table->dropForeign(['client_id']);
        });
    }
};
