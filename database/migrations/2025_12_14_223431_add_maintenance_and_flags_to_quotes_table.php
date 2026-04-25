<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('quotes', function (Blueprint $table) {
            $table->decimal('price_maintenance_monthly', 10, 2)->nullable()->after('price_development');

            $table->boolean('include_domain')->default(false)->after('price_maintenance_monthly');
            $table->boolean('include_hosting')->default(false)->after('include_domain');
        });
    }

    public function down(): void
    {
        Schema::table('quotes', function (Blueprint $table) {
            $table->dropColumn(['price_maintenance_monthly', 'include_domain', 'include_hosting']);
        });
    }
};
