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
            // FLAGS
            if (! Schema::hasColumn('quotes', 'include_domain')) {
                $table->boolean('include_domain')->default(false)->after('price_development');
            }
            if (! Schema::hasColumn('quotes', 'include_hosting')) {
                $table->boolean('include_hosting')->default(false)->after('include_domain');
            }

            // DOMÍNIO
            if (! Schema::hasColumn('quotes', 'price_domain_first_year')) {
                $table->decimal('price_domain_first_year', 10, 2)->nullable()->after('include_hosting');
            }
            if (! Schema::hasColumn('quotes', 'price_domain_other_years')) {
                $table->decimal('price_domain_other_years', 10, 2)->nullable();
            }

            // ALOJAMENTO
            if (! Schema::hasColumn('quotes', 'price_hosting_first_year')) {
                $table->decimal('price_hosting_first_year', 10, 2)->nullable();
            }
            if (! Schema::hasColumn('quotes', 'price_hosting_other_years')) {
                $table->decimal('price_hosting_other_years', 10, 2)->nullable();
            }

            // VALORES CONSOLIDADOS (PDF)
            if (! Schema::hasColumn('quotes', 'price_domains')) {
                $table->decimal('price_domains', 10, 2)->nullable();
            }
            if (! Schema::hasColumn('quotes', 'price_hosting')) {
                $table->decimal('price_hosting', 10, 2)->nullable();
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('quotes')) {
            return;
        }

        $columns = [
            'include_domain',
            'include_hosting',
            'price_domain_first_year',
            'price_domain_other_years',
            'price_hosting_first_year',
            'price_hosting_other_years',
            'price_domains',
            'price_hosting',
        ];

        $existing = array_values(array_filter($columns, fn ($column) => Schema::hasColumn('quotes', $column)));

        if (! empty($existing)) {
            Schema::table('quotes', function (Blueprint $table) use ($existing) {
                $table->dropColumn($existing);
            });
        }
    }
};
