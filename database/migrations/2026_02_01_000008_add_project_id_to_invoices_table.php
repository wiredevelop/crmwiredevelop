<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('invoices')) {
            return;
        }

        if (!Schema::hasColumn('invoices', 'project_id')) {
            Schema::table('invoices', function (Blueprint $table) {
                $table->unsignedBigInteger('project_id')->nullable()->after('client_id');
            });
        }

        if (Schema::hasTable('projects') && Schema::hasColumn('invoices', 'project_id')) {
            $fkExists = DB::selectOne(
                "select constraint_name from information_schema.key_column_usage where table_schema = database() and table_name = 'invoices' and column_name = 'project_id' and referenced_table_name = 'projects' limit 1"
            );

            if (!$fkExists) {
                Schema::table('invoices', function (Blueprint $table) {
                    $table->foreign('project_id')
                          ->references('id')
                          ->on('projects')
                          ->nullOnDelete();
                });
            }
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('invoices') || !Schema::hasColumn('invoices', 'project_id')) {
            return;
        }

        $fkExists = DB::selectOne(
            "select constraint_name from information_schema.key_column_usage where table_schema = database() and table_name = 'invoices' and column_name = 'project_id' and referenced_table_name = 'projects' limit 1"
        );

        if ($fkExists) {
            Schema::table('invoices', function (Blueprint $table) {
                $table->dropForeign(['project_id']);
            });
        }

        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('project_id');
        });
    }
};
