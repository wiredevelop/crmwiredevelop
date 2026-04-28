<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (! Schema::hasTable('pack_items') || Schema::hasColumn('pack_items', 'order')) {
            return;
        }

        Schema::table('pack_items', function (Blueprint $table) {
            $table->integer('order')->default(0)->after('featured');
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('pack_items') || ! Schema::hasColumn('pack_items', 'order')) {
            return;
        }

        Schema::table('pack_items', function (Blueprint $table) {
            $table->dropColumn('order');
        });
    }
};
