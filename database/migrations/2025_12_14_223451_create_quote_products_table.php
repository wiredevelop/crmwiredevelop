<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quote_products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quote_id')->constrained()->cascadeOnDelete();

            // referência ao catálogo (opcional, só para tracking)
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();

            $table->string('type'); // product|pack
            $table->string('name');
            $table->string('slug')->nullable();

            $table->text('short_description')->nullable();
            $table->longText('content_html')->nullable();

            // se for product simples (preço fixo)
            $table->decimal('price', 10, 2)->nullable();

            // snapshot dos packs e info fields
            $table->json('pack_items')->nullable();   // [{hours, normal_price, pack_price, validity_months, featured}]
            $table->json('info_fields')->nullable();  // [{type,label,value}]

            $table->integer('order')->default(0);

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quote_products');
    }
};
