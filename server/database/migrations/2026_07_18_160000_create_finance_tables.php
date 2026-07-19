<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('credits', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->uuid('sale_id')->nullable()->index();
            $table->string('receipt_number')->nullable()->index();
            $table->string('customer_name');
            $table->string('customer_contact')->nullable();
            $table->decimal('original_amount', 14, 4);
            $table->decimal('balance', 14, 4);
            $table->string('status')->default('unpaid')->index();
            $table->timestamp('due_at')->nullable();
            $table->text('note')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });

        Schema::create('credit_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('credit_id')->index();
            $table->decimal('amount', 14, 4);
            $table->string('method');
            $table->text('note')->nullable();
            $table->timestamp('paid_at');
            $table->timestamps();
        });

        Schema::create('expenses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('category')->index();
            $table->string('description');
            $table->decimal('amount', 14, 4);
            $table->string('payment_method');
            $table->string('vendor')->nullable();
            $table->timestamp('expense_date')->index();
            $table->text('note')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
        Schema::dropIfExists('credit_payments');
        Schema::dropIfExists('credits');
    }
};
