<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table) {
            $table->string('billing_name')->nullable()->after('address');
            $table->string('billing_email')->nullable()->after('billing_name');
            $table->string('billing_phone')->nullable()->after('billing_email');
            $table->string('billing_vat')->nullable()->after('billing_phone');
            $table->string('billing_address')->nullable()->after('billing_vat');
            $table->string('billing_postal_code')->nullable()->after('billing_address');
            $table->string('billing_city')->nullable()->after('billing_postal_code');
            $table->string('billing_country', 2)->nullable()->after('billing_city');
            $table->string('stripe_customer_id')->nullable()->after('billing_country')->index();
        });
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table) {
            $table->dropIndex(['stripe_customer_id']);
            $table->dropColumn([
                'billing_name',
                'billing_email',
                'billing_phone',
                'billing_vat',
                'billing_address',
                'billing_postal_code',
                'billing_city',
                'billing_country',
                'stripe_customer_id',
            ]);
        });
    }
};
