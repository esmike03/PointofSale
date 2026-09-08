<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_reset_only_the_business_product_catalog_and_preserve_sales(): void
    {
        $businessId = (string) Str::uuid();
        $otherBusinessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $otherProductId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        $now = now();

        DB::table('businesses')->insert([
            ['id' => $businessId, 'name' => 'Reset Store', 'currency' => 'PHP', 'created_at' => $now, 'updated_at' => $now],
            ['id' => $otherBusinessId, 'name' => 'Other Store', 'currency' => 'PHP', 'created_at' => $now, 'updated_at' => $now],
        ]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => $now, 'updated_at' => $now]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => $now, 'updated_at' => $now]);
        DB::table('products')->insert([
            ['id' => $productId, 'business_id' => $businessId, 'name' => 'Coffee', 'selling_price' => 100, 'cost_price' => 50, 'unit' => 'piece', 'created_at' => $now, 'updated_at' => $now],
            ['id' => $otherProductId, 'business_id' => $otherBusinessId, 'name' => 'Other Product', 'selling_price' => 20, 'cost_price' => 10, 'unit' => 'piece', 'created_at' => $now, 'updated_at' => $now],
        ]);
        DB::table('product_barcodes')->insert(['id' => (string) Str::uuid(), 'product_id' => $productId, 'code' => 'RESET-001', 'type' => 'unknown', 'created_at' => $now, 'updated_at' => $now]);
        DB::table('inventory_items')->insert(['id' => (string) Str::uuid(), 'branch_id' => $branchId, 'product_id' => $productId, 'quantity' => 7, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('sales')->insert(['id' => $saleId, 'business_id' => $businessId, 'branch_id' => $branchId, 'device_id' => $deviceId, 'receipt_number' => 'TRX-RESET', 'status' => 'completed', 'gross_amount' => 100, 'discount_amount' => 0, 'net_amount' => 100, 'occurred_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('sale_items')->insert(['id' => (string) Str::uuid(), 'sale_id' => $saleId, 'product_id' => $productId, 'product_name' => 'Coffee', 'quantity' => 1, 'unit_price' => 100, 'discount_amount' => 0, 'line_total' => 100, 'created_at' => $now, 'updated_at' => $now]);

        $owner = User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'business_owner']);
        Sanctum::actingAs($owner);

        $this->deleteJson('/api/products/reset', ['confirmation' => 'wrong'])->assertUnprocessable();

        $response = $this->deleteJson('/api/products/reset', ['confirmation' => 'RESET PRODUCTS'])
            ->assertOk()
            ->assertJsonPath('deleted_products', 1)
            ->assertJsonPath('deleted_inventory_items', 1);

        $resetAt = $response->json('reset_at');
        $this->assertDatabaseMissing('products', ['id' => $productId]);
        $this->assertDatabaseMissing('product_barcodes', ['product_id' => $productId]);
        $this->assertDatabaseMissing('inventory_items', ['product_id' => $productId]);
        $this->assertDatabaseHas('products', ['id' => $otherProductId, 'business_id' => $otherBusinessId]);
        $this->assertDatabaseHas('sales', ['id' => $saleId, 'receipt_number' => 'TRX-RESET']);
        $this->assertDatabaseHas('sale_items', ['sale_id' => $saleId, 'product_name' => 'Coffee']);
        $this->assertDatabaseHas('business_settings', ['business_id' => $businessId, 'key' => 'system.products_reset_at', 'value' => $resetAt]);
        $this->assertDatabaseHas('audit_logs', ['business_id' => $businessId, 'action' => 'products.reset']);

        $this->getJson('/api/sync/pull?scope=products')
            ->assertOk()
            ->assertJsonPath('products_reset_at', $resetAt);

        $refundId = (string) Str::uuid();
        $refundOperation = [
            'operation_id' => (string) Str::uuid(),
            'device_id' => $deviceId,
            'type' => 'sale.refund',
            'payload' => [
                'id' => $refundId,
                'sale_id' => $saleId,
                'refund_number' => 'REF-AFTER-RESET',
                'amount' => 100,
                'method' => 'cash',
                'reason' => 'Returned after catalog reset',
                'occurred_at' => now()->toIso8601String(),
                'items' => [['id' => (string) Str::uuid(), 'product_id' => $productId, 'quantity' => 1, 'amount' => 100]],
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$refundOperation]])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'processed');
        $this->assertDatabaseHas('refunds', ['id' => $refundId, 'sale_id' => $saleId]);
        $this->assertDatabaseMissing('inventory_items', ['product_id' => $productId]);

        $staleProductId = (string) Str::uuid();
        $staleOperation = [
            'operation_id' => (string) Str::uuid(),
            'device_id' => $deviceId,
            'type' => 'product.create',
            'payload' => [
                'id' => $staleProductId,
                'name' => 'Stale Offline Product',
                'selling_price' => 15,
                'updated_at' => Carbon::parse($resetAt)->subMinute()->toIso8601String(),
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$staleOperation]])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'processed')
            ->assertJsonPath('results.0.discarded_after_product_reset', true);
        $this->assertDatabaseMissing('products', ['id' => $staleProductId]);

        $freshProductId = (string) Str::uuid();
        $freshOperation = [
            'operation_id' => (string) Str::uuid(),
            'device_id' => $deviceId,
            'type' => 'product.create',
            'payload' => [
                'id' => $freshProductId,
                'name' => 'Fresh Product',
                'selling_price' => 25,
                'updated_at' => Carbon::parse($resetAt)->addMinute()->toIso8601String(),
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$freshOperation]])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'processed');
        $this->assertDatabaseHas('products', ['id' => $freshProductId, 'business_id' => $businessId]);
    }

    public function test_inventory_staff_cannot_reset_server_products(): void
    {
        $businessId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        $productId = (string) Str::uuid();
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Protected Product', 'selling_price' => 10, 'unit' => 'piece', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'role' => 'inventory_staff']));

        $this->deleteJson('/api/products/reset', ['confirmation' => 'RESET PRODUCTS'])
            ->assertForbidden();

        $this->assertDatabaseHas('products', ['id' => $productId]);
    }
}
