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
        Schema::table('projects', function (Blueprint $table) {
            // Tipo de projeto (Website, Loja Online, etc.)
            if (!Schema::hasColumn('projects', 'type')) {
                $table->string('type')->after('name');
            }

            // Tecnologias (json)
            if (!Schema::hasColumn('projects', 'technologies')) {
                $table->json('technologies')->nullable()->after('type');
            }

            // Descrição em HTML
            if (!Schema::hasColumn('projects', 'description_html')) {
                $table->longText('description_html')->nullable()->after('technologies');
            }

            // Tags/etiquetas (estado, labels internas)
            if (!Schema::hasColumn('projects', 'tags')) {
                $table->json('tags')->nullable()->after('description_html');
            }

            // Status principal do projeto
            if (!Schema::hasColumn('projects', 'status')) {
                $table->string('status')->default('novo')->after('tags');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            if (Schema::hasColumn('projects', 'status')) {
                $table->dropColumn('status');
            }
            if (Schema::hasColumn('projects', 'tags')) {
                $table->dropColumn('tags');
            }
            if (Schema::hasColumn('projects', 'description_html')) {
                $table->dropColumn('description_html');
            }
            if (Schema::hasColumn('projects', 'technologies')) {
                $table->dropColumn('technologies');
            }
            if (Schema::hasColumn('projects', 'type')) {
                $table->dropColumn('type');
            }
        });
    }
};
