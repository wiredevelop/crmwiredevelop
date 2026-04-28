<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('client_credentials') || Schema::hasColumn('client_credentials', 'object_id')) {
            return;
        }

        Schema::table('client_credentials', function (Blueprint $table) {
            $table->foreignId('object_id')
                ->nullable()
                ->after('client_id')
                ->constrained('client_credential_objects')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('client_credentials') || ! Schema::hasColumn('client_credentials', 'object_id')) {
            return;
        }

        Schema::table('client_credentials', function (Blueprint $table) {
            $table->dropForeign(['object_id']);
            $table->dropColumn('object_id');
        });
    }
};
