<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('projects')) {
            return;
        }

        $columnsToDrop = [
            'price',
            'started_at',
            'due_at',
            'description_html',
            'tags',
            'scope',
            'features',
            'development_plan',
            'budget',
            'pricing_details',
            'terms',
            'attachments',
            'technologies',
            'description',
        ];

        $existingColumns = array_filter($columnsToDrop, fn ($column) => Schema::hasColumn('projects', $column));

        if (! empty($existingColumns)) {
            Schema::table('projects', function (Blueprint $table) use ($existingColumns) {
                $table->dropColumn($existingColumns);
            });
        }

        if (! Schema::hasColumn('projects', 'quote_id')) {
            Schema::table('projects', function (Blueprint $table) {
                $table->unsignedBigInteger('quote_id')->nullable()->after('status');
            });
        }

        if (Schema::hasTable('quotes') && Schema::hasColumn('projects', 'quote_id')) {
            $fkExists = DB::selectOne(
                "select constraint_name from information_schema.key_column_usage where table_schema = database() and table_name = 'projects' and column_name = 'quote_id' and referenced_table_name = 'quotes' limit 1"
            );

            if (! $fkExists) {
                Schema::table('projects', function (Blueprint $table) {
                    $table->foreign('quote_id')
                        ->references('id')
                        ->on('quotes')
                        ->onDelete('cascade');
                });
            }
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('projects')) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            // Repor colunas removidas (versão simplificada)
            if (! Schema::hasColumn('projects', 'price')) {
                $table->decimal('price', 10, 2)->nullable();
            }
            if (! Schema::hasColumn('projects', 'started_at')) {
                $table->timestamp('started_at')->nullable();
            }
            if (! Schema::hasColumn('projects', 'due_at')) {
                $table->timestamp('due_at')->nullable();
            }
            if (! Schema::hasColumn('projects', 'description_html')) {
                $table->text('description_html')->nullable();
            }
            if (! Schema::hasColumn('projects', 'tags')) {
                $table->json('tags')->nullable();
            }
            if (! Schema::hasColumn('projects', 'scope')) {
                $table->json('scope')->nullable();
            }
            if (! Schema::hasColumn('projects', 'features')) {
                $table->json('features')->nullable();
            }
            if (! Schema::hasColumn('projects', 'development_plan')) {
                $table->json('development_plan')->nullable();
            }
            if (! Schema::hasColumn('projects', 'budget')) {
                $table->json('budget')->nullable();
            }
            if (! Schema::hasColumn('projects', 'pricing_details')) {
                $table->json('pricing_details')->nullable();
            }
            if (! Schema::hasColumn('projects', 'terms')) {
                $table->text('terms')->nullable();
            }
            if (! Schema::hasColumn('projects', 'attachments')) {
                $table->json('attachments')->nullable();
            }
            if (! Schema::hasColumn('projects', 'technologies')) {
                $table->string('technologies')->nullable();
            }
            if (! Schema::hasColumn('projects', 'description')) {
                $table->text('description')->nullable();
            }

            if (Schema::hasColumn('projects', 'quote_id')) {
                $table->dropForeign(['quote_id']);
                $table->dropColumn('quote_id');
            }
        });
    }
};
