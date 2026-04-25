<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('packs', function (Blueprint $table) {
            $table->foreignId('product_id')->primary()->constrained()->cascadeOnDelete();
            $table->integer('hours_included');
            $table->decimal('normal_price', 10, 2);
            $table->decimal('pack_price', 10, 2);
            $table->integer('validity_months');
            $table->decimal('extra_hour_price', 10, 2)->default(35);
            $table->boolean('featured')->default(false);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('packs');
    }
};
