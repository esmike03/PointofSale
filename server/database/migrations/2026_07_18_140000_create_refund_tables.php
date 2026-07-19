<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('refunds', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('sale_id')->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('refund_number');
            $table->decimal('amount', 14, 4);
            $table->string('method');
            $table->text('reason');
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->unique(['business_id', 'refund_number']);
        });

        Schema::create('refund_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('refund_id')->index();
            $table->uuid('sale_item_id')->index();
            $table->uuid('product_id')->index();
            $table->decimal('quantity', 14, 4);
            $table->decimal('amount', 14, 4);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('refund_items');
        Schema::dropIfExists('refunds');
    }
};
