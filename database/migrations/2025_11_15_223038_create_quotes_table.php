<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quotes', function (Blueprint $table) {
            $table->id();

            // Ligação ao projeto
            $table->foreignId('project_id')
                  ->constrained('projects')
                  ->onDelete('cascade'); // se apaga projeto, apaga orçamento

            $table->string('project_type');
            $table->text('technologies')->nullable();
            $table->text('description')->nullable();

            // JSON com lista de funcionalidades e horas
            $table->json('development_items')->nullable();
            $table->integer('development_total_hours')->default(0);

            // Preços
            $table->decimal('price_development', 10, 2)->default(0);
            $table->decimal('price_domain_first_year', 10, 2)->default(0);
            $table->decimal('price_domain_other_years', 10, 2)->default(0);
            $table->decimal('price_hosting_first_year', 10, 2)->default(0);
            $table->decimal('price_hosting_other_years', 10, 2)->default(0);

            // Termos
            $table->longText('terms')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quotes');
    }
};
