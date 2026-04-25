<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
    {
        Schema::table('projects', function (Blueprint $table) {
            $table->string('type')->nullable(); // Website, Loja, Rebranding, Plugin
            $table->text('scope')->nullable(); // Escopo do projeto
            $table->json('features')->nullable(); // Lista de funcionalidades
            $table->json('development_plan')->nullable(); // lista de tarefas com duração
            $table->decimal('budget', 10, 2)->nullable(); // valor total
            $table->json('pricing_details')->nullable(); // alojamento, domínio, etc.
            $table->json('terms')->nullable(); // Prazo, garantia, condições
            $table->json('attachments')->nullable(); // PDFs, imagens
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            //
        });
    }
};
