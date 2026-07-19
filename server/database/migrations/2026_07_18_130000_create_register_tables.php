<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('register_shifts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('business_id')->index();
            $table->uuid('branch_id')->nullable()->index();
            $table->uuid('device_id')->nullable()->index();
            $table->unsignedBigInteger('cashier_id')->nullable()->index();
            $table->decimal('opening_cash', 14, 4);
            $table->string('status')->default('open');
            $table->timestamp('opened_at');
            $table->timestamp('closed_at')->nullable();
            $table->decimal('expected_cash', 14, 4)->nullable();
            $table->decimal('actual_cash', 14, 4)->nullable();
            $table->decimal('variance', 14, 4)->nullable();
            $table->text('note')->nullable();
            $table->timestamps();
        });
        Schema::create('cash_movements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('register_shift_id')->index();
            $table->string('type');
            $table->decimal('amount', 14, 4);
            $table->text('note')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cash_movements');
        Schema::dropIfExists('register_shifts');
    }
};
