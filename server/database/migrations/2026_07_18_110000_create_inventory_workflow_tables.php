<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('suppliers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->string('name');
            $table->string('contact_name')->nullable();
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->text('address')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['business_id', 'name']);
        });

        Schema::create('stock_receipts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->index();
            $table->uuid('supplier_id')->nullable()->index();
            $table->unsignedBigInteger('received_by')->nullable()->index();
            $table->string('reference')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('received_at');
            $table->timestamps();
        });

        Schema::create('stock_receipt_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('stock_receipt_id')->index();
            $table->uuid('product_id')->index();
            $table->decimal('quantity', 14, 4);
            $table->decimal('unit_cost', 14, 4)->default(0);
            $table->string('batch_number')->nullable();
            $table->date('expires_on')->nullable();
            $table->timestamps();
        });

        Schema::create('stock_transfers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('source_branch_id')->index();
            $table->uuid('destination_branch_id')->index();
            $table->unsignedBigInteger('transferred_by')->nullable()->index();
            $table->string('reference')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('transferred_at');
            $table->timestamps();
        });

        Schema::create('stock_transfer_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('stock_transfer_id')->index();
            $table->uuid('product_id')->index();
            $table->decimal('quantity', 14, 4);
            $table->timestamps();
        });

        Schema::create('stock_counts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->index();
            $table->unsignedBigInteger('counted_by')->nullable()->index();
            $table->string('reference')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('counted_at');
            $table->timestamps();
        });

        Schema::create('stock_count_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('stock_count_id')->index();
            $table->uuid('product_id')->index();
            $table->decimal('expected_quantity', 14, 4);
            $table->decimal('counted_quantity', 14, 4);
            $table->decimal('quantity_delta', 14, 4);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_count_items');
        Schema::dropIfExists('stock_counts');
        Schema::dropIfExists('stock_transfer_items');
        Schema::dropIfExists('stock_transfers');
        Schema::dropIfExists('stock_receipt_items');
        Schema::dropIfExists('stock_receipts');
        Schema::dropIfExists('suppliers');
    }
};
