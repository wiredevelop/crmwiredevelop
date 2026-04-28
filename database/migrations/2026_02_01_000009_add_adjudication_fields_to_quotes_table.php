<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('quotes')) {
            return;
        }

        Schema::table('quotes', function (Blueprint $table) {
            if (! Schema::hasColumn('quotes', 'adjudication_percent')) {
                $table->decimal('adjudication_percent', 5, 2)->nullable()->after('price_development');
            }
            if (! Schema::hasColumn('quotes', 'adjudication_paid_at')) {
                $table->date('adjudication_paid_at')->nullable()->after('adjudication_percent');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('quotes')) {
            return;
        }

        Schema::table('quotes', function (Blueprint $table) {
            if (Schema::hasColumn('quotes', 'adjudication_paid_at')) {
                $table->dropColumn('adjudication_paid_at');
            }
            if (Schema::hasColumn('quotes', 'adjudication_percent')) {
                $table->dropColumn('adjudication_percent');
            }
        });
    }
};
