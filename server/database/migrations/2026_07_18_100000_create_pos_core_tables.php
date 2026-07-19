<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('businesses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('currency', 3)->default('PHP');
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->uuid('business_id')->nullable()->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->string('role')->default('cashier');
        });

        Schema::create('branches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->string('name');
            $table->string('code')->nullable();
            $table->string('timezone')->default('Asia/Manila');
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['business_id', 'code']);
        });

        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->string('name');
            $table->string('mode')->default('standalone');
            $table->timestamp('last_seen_at')->nullable();
            $table->json('settings')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->string('name');
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['business_id', 'name']);
        });

        Schema::create('products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('category_id')->nullable()->index();
            $table->string('sku')->nullable();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('selling_price', 14, 4);
            $table->decimal('cost_price', 14, 4)->default(0);
            $table->string('unit')->default('piece');
            $table->decimal('reorder_level', 14, 4)->default(0);
            $table->boolean('allow_negative_stock')->default(false);
            $table->timestamp('client_updated_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['business_id', 'sku']);
        });

        Schema::create('product_barcodes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('product_id')->index();
            $table->string('code');
            $table->string('type')->default('ean13');
            $table->timestamps();
            $table->unique(['product_id', 'code']);
            $table->unique('code');
        });

        Schema::create('inventory_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('branch_id')->index();
            $table->uuid('product_id')->index();
            $table->decimal('quantity', 14, 4)->default(0);
            $table->timestamp('client_updated_at')->nullable();
            $table->timestamps();
            $table->unique(['branch_id', 'product_id']);
        });

        Schema::create('sales', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('cashier_id')->nullable()->index();
            $table->string('receipt_number');
            $table->string('status')->default('completed');
            $table->decimal('gross_amount', 14, 4);
            $table->decimal('discount_amount', 14, 4)->default(0);
            $table->decimal('net_amount', 14, 4);
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['business_id', 'receipt_number']);
        });

        Schema::create('sale_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('sale_id')->index();
            $table->uuid('product_id')->nullable()->index();
            $table->string('product_name');
            $table->string('sku')->nullable();
            $table->decimal('quantity', 14, 4);
            $table->decimal('unit_price', 14, 4);
            $table->decimal('discount_amount', 14, 4)->default(0);
            $table->decimal('line_total', 14, 4);
            $table->timestamps();
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('sale_id')->index();
            $table->string('method');
            $table->decimal('amount', 14, 4);
            $table->string('reference')->nullable();
            $table->timestamps();
        });

        Schema::create('stock_movements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->uuid('product_id')->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('reason');
            $table->decimal('quantity_delta', 14, 4);
            $table->string('source_type')->nullable();
            $table->uuid('source_id')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();
            $table->unique(['source_type', 'source_id', 'product_id', 'reason']);
        });

        Schema::create('sync_operations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('device_id')->index();
            $table->uuid('operation_id');
            $table->string('type');
            $table->string('status')->default('received');
            $table->json('payload');
            $table->text('error')->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
            $table->unique(['business_id', 'operation_id']);
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->uuid('device_id')->nullable()->index();
            $table->string('action');
            $table->string('subject_type');
            $table->string('subject_id');
            $table->json('before')->nullable();
            $table->json('after')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('sync_operations');
        Schema::dropIfExists('stock_movements');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('sale_items');
        Schema::dropIfExists('sales');
        Schema::dropIfExists('inventory_items');
        Schema::dropIfExists('product_barcodes');
        Schema::dropIfExists('products');
        Schema::dropIfExists('categories');
        Schema::dropIfExists('devices');
        Schema::dropIfExists('branches');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['business_id', 'branch_id', 'role']);
        });
        Schema::dropIfExists('businesses');
    }
};
