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
        Schema::create('budgets', function (Blueprint $table) {
            $table->id();

            // Orçamento está SEMPRE ligado a um projeto
            $table->foreignId('project_id')
                ->constrained('projects')
                ->cascadeOnDelete();

            // Tipo de projeto (Website, Loja Online, Landing Page, Plugin, Outros...)
            $table->string('type');

            // Tecnologias (PHP, HTML, CSS, JS, WooCommerce, etc.)
            $table->json('technologies')->nullable();

            // Escopo / descrição em HTML (com listas, tabs, etc.)
            $table->longText('description_html')->nullable();

            // Tabela de desenvolvimento (funcionalidade x duração)
            // Ex: [{ "feature": "Landing Page", "hours": 8 }, ...]
            $table->json('development_table')->nullable();

            // Total de horas de desenvolvimento
            $table->integer('development_total_hours')->default(0);

            // Valores (dev / domínio / alojamento 1º ano / restantes anos, etc.)
            // Ex:
            // {
            //   "development": 1200,
            //   "domain_first_year": 97.45,
            //   "domain_next_years": 16.27,
            //   "hosting_first_year": 97.45,
            //   "hosting_next_years": 194.90
            // }
            $table->json('prices')->nullable();

            // Prazos e condições em HTML
            $table->longText('terms_html')->nullable();

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('budgets');
    }
};
