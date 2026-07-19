<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InventoryWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_receiving_transfer_and_stock_count_keep_an_auditable_inventory_ledger(): void
    {
        $businessId = (string) Str::uuid();
        $mainBranchId = (string) Str::uuid();
        $secondBranchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        foreach ([[$mainBranchId, 'Main', 'MAIN'], [$secondBranchId, 'Outlet', 'OUTLET']] as [$id, $name, $code]) {
            DB::table('branches')->insert(['id' => $id, 'business_id' => $businessId, 'name' => $name, 'code' => $code, 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        }
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Rice', 'selling_price' => 60, 'cost_price' => 45, 'unit' => 'kg', 'reorder_level' => 6, 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $mainBranchId, 'role' => 'inventory_staff']));

        $this->postJson('/api/inventory/receive', ['branch_id' => $mainBranchId, 'reference' => 'DR-001', 'items' => [['product_id' => $productId, 'quantity' => 10, 'unit_cost' => 45]]])->assertCreated();
        $this->postJson('/api/inventory/transfer', ['source_branch_id' => $mainBranchId, 'destination_branch_id' => $secondBranchId, 'items' => [['product_id' => $productId, 'quantity' => 3]]])->assertCreated();
        $this->postJson('/api/inventory/count', ['branch_id' => $secondBranchId, 'items' => [['product_id' => $productId, 'counted_quantity' => 5]]])->assertCreated();

        $this->assertDatabaseHas('inventory_items', ['branch_id' => $mainBranchId, 'product_id' => $productId, 'quantity' => 7]);
        $this->assertDatabaseHas('inventory_items', ['branch_id' => $secondBranchId, 'product_id' => $productId, 'quantity' => 5]);
        $this->assertDatabaseCount('stock_movements', 4);
        $this->getJson("/api/inventory/low-stock?branch_id={$secondBranchId}")->assertOk()->assertJsonPath('0.product_id', $productId);
    }
}
