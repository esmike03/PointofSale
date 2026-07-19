<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('tax_category')->default('vatable');
        });
        Schema::table('sales', function (Blueprint $table) {
            $table->string('tax_mode')->default('unregistered');
            $table->decimal('vat_rate', 8, 6)->default(0);
            $table->decimal('vatable_sales', 14, 4)->default(0);
            $table->decimal('vat_amount', 14, 4)->default(0);
            $table->decimal('vat_exempt_sales', 14, 4)->default(0);
            $table->decimal('zero_rated_sales', 14, 4)->default(0);
            $table->json('receipt_profile')->nullable();
        });
        Schema::table('sale_items', function (Blueprint $table) {
            $table->string('tax_category')->default('vatable');
        });
    }

    public function down(): void
    {
        Schema::table('sale_items', fn (Blueprint $table) => $table->dropColumn('tax_category'));
        Schema::table('sales', function (Blueprint $table) {
            $table->dropColumn(['tax_mode', 'vat_rate', 'vatable_sales', 'vat_amount', 'vat_exempt_sales', 'zero_rated_sales', 'receipt_profile']);
        });
        Schema::table('products', fn (Blueprint $table) => $table->dropColumn('tax_category'));
    }
};
