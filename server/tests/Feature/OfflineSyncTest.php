<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OfflineSyncTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_retried_offline_sale_is_processed_once(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        $operationId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Coffee', 'selling_price' => 100, 'cost_price' => 50, 'unit' => 'piece', 'allow_negative_stock' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        $user = User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId]);
        Sanctum::actingAs($user);
        $operation = [
            'operation_id' => $operationId,
            'device_id' => $deviceId,
            'type' => 'sale.create',
            'payload' => [
                'id' => $saleId, 'branch_id' => $branchId, 'receipt_number' => 'TRX-001', 'receipt_name' => 'Maria Santos', 'gross_amount' => 100, 'net_amount' => 100,
                'occurred_at' => now()->toIso8601String(),
                'items' => [['product_id' => $productId, 'quantity' => 1, 'unit_price' => 100, 'line_total' => 100]],
                'payments' => [['method' => 'cash', 'amount' => 100]],
            ],
        ];

        $this->postJson('/api/sync/push', ['operations' => [$operation]])->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->postJson('/api/sync/push', ['operations' => [$operation]])->assertOk()->assertJsonPath('results.0.status', 'already_processed');

        $this->assertDatabaseCount('sales', 1);
        $this->assertDatabaseHas('sales', ['id' => $saleId, 'receipt_number' => 'TRX-001', 'receipt_name' => 'Maria Santos']);
        $this->getJson('/api/sales/receipt/TRX-001')->assertOk()
            ->assertJsonPath('sale.receipt_name', 'Maria Santos')
            ->assertJsonPath('items.0.product_id', $productId)
            ->assertJsonPath('payments.0.method', 'cash');
        $this->assertDatabaseCount('stock_movements', 1);
        $this->assertDatabaseHas('inventory_items', ['branch_id' => $branchId, 'product_id' => $productId, 'quantity' => -1]);
    }

    public function test_public_registration_is_disabled_by_default(): void
    {
        $this->postJson('/api/auth/register', [
            'business_name' => 'Test Store', 'name' => 'Owner', 'email' => 'owner@example.com', 'password' => 'password123',
        ])->assertForbidden();
    }

    public function test_product_archive_and_restore_sync_to_soft_delete_state(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Seasonal Item', 'selling_price' => 100, 'cost_price' => 50, 'unit' => 'piece', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'inventory_staff']));

        $archive = ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'product.archive', 'payload' => ['id' => $productId, 'updated_at' => now()->toIso8601String()]];
        $this->postJson('/api/sync/push', ['operations' => [$archive]])->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->assertNotNull(DB::table('products')->where('id', $productId)->value('deleted_at'));

        $restore = ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'product.restore', 'payload' => ['id' => $productId, 'updated_at' => now()->toIso8601String()]];
        $this->postJson('/api/sync/push', ['operations' => [$restore]])->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->assertNull(DB::table('products')->where('id', $productId)->value('deleted_at'));
        $this->assertDatabaseCount('audit_logs', 2);
    }

    public function test_product_delete_preserves_completed_sale_history(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $protectedId = (string) Str::uuid();
        $unusedId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert([
            ['id' => $protectedId, 'business_id' => $businessId, 'name' => 'Historical Product', 'selling_price' => 50, 'cost_price' => 20, 'unit' => 'piece', 'deleted_at' => now(), 'created_at' => now(), 'updated_at' => now()],
            ['id' => $unusedId, 'business_id' => $businessId, 'name' => 'Unused Product', 'selling_price' => 10, 'cost_price' => 5, 'unit' => 'piece', 'deleted_at' => now(), 'created_at' => now(), 'updated_at' => now()],
        ]);
        DB::table('sales')->insert(['id' => $saleId, 'business_id' => $businessId, 'branch_id' => $branchId, 'device_id' => $deviceId, 'receipt_number' => 'TRX-PROTECTED', 'status' => 'completed', 'gross_amount' => 50, 'discount_amount' => 0, 'net_amount' => 50, 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('sale_items')->insert(['id' => (string) Str::uuid(), 'sale_id' => $saleId, 'product_id' => $protectedId, 'product_name' => 'Historical Product', 'quantity' => 1, 'unit_price' => 50, 'discount_amount' => 0, 'line_total' => 50, 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'inventory_staff']));

        $protectedDelete = ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'product.delete', 'payload' => ['id' => $protectedId, 'updated_at' => now()->toIso8601String()]];
        $this->postJson('/api/sync/push', ['operations' => [$protectedDelete]])
            ->assertOk()->assertJsonPath('results.0.status', 'failed')
            ->assertJsonPath('results.0.error', 'This product is referenced by completed sales and cannot be permanently deleted. Keep it archived to preserve business records.');
        $this->assertDatabaseHas('products', ['id' => $protectedId]);
        $this->assertDatabaseHas('sale_items', ['sale_id' => $saleId, 'product_id' => $protectedId]);

        $unusedDelete = ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'product.delete', 'payload' => ['id' => $unusedId, 'updated_at' => now()->toIso8601String()]];
        $this->postJson('/api/sync/push', ['operations' => [$unusedDelete]])
            ->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->assertDatabaseMissing('products', ['id' => $unusedId]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'product.deleted', 'subject_id' => $unusedId]);
    }

    public function test_vat_sale_recalculates_and_preserves_invoice_breakdown(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'VATable Item', 'selling_price' => 112, 'cost_price' => 50, 'unit' => 'piece', 'tax_category' => 'vatable', 'allow_negative_stock' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId]));
        $operation = [
            'operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'sale.create',
            'payload' => [
                'id' => $saleId, 'receipt_number' => 'TRX-VAT-001', 'gross_amount' => 112, 'net_amount' => 112,
                'tax_mode' => 'vat', 'vat_rate' => .12,
                'receipt_profile' => ['store_name' => 'Sample Store', 'tin' => '123-456-789-000'],
                'items' => [['product_id' => $productId, 'quantity' => 1, 'unit_price' => 112, 'line_total' => 112]],
                'payments' => [['method' => 'cash', 'amount' => 112]],
            ],
        ];

        $this->postJson('/api/sync/push', ['operations' => [$operation]])
            ->assertOk()->assertJsonPath('results.0.status', 'processed');
        $sale = DB::table('sales')->where('id', $saleId)->first();
        $this->assertEqualsWithDelta(100, (float) $sale->vatable_sales, .001);
        $this->assertEqualsWithDelta(12, (float) $sale->vat_amount, .001);
        $this->assertDatabaseHas('sale_items', ['sale_id' => $saleId, 'tax_category' => 'vatable']);
        $this->getJson('/api/sales/receipt/TRX-VAT-001')->assertOk()
            ->assertJsonPath('sale.tax_mode', 'vat')
            ->assertJsonPath('sale.receipt_profile.store_name', 'Sample Store');
    }

    public function test_partial_refund_is_idempotent_and_restores_inventory(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        $refundId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Coffee', 'selling_price' => 100, 'cost_price' => 50, 'unit' => 'piece', 'allow_negative_stock' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'cashier']));

        $saleOperation = [
            'operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'sale.create',
            'payload' => [
                'id' => $saleId, 'branch_id' => $branchId, 'receipt_number' => 'TRX-RETURN-001',
                'gross_amount' => 200, 'discount_amount' => 20, 'net_amount' => 180, 'occurred_at' => now()->toIso8601String(),
                'items' => [['product_id' => $productId, 'quantity' => 2, 'unit_price' => 100, 'line_total' => 200]],
                'payments' => [['method' => 'cash', 'amount' => 180]],
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$saleOperation]])->assertOk()->assertJsonPath('results.0.status', 'processed');

        $refundOperation = [
            'operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'sale.refund',
            'payload' => [
                'id' => $refundId, 'sale_id' => $saleId, 'refund_number' => 'REF-001', 'amount' => 90,
                'method' => 'cash', 'reason' => 'Damaged item', 'occurred_at' => now()->toIso8601String(),
                'items' => [['id' => (string) Str::uuid(), 'product_id' => $productId, 'quantity' => 1, 'amount' => 90]],
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$refundOperation]])->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->postJson('/api/sync/push', ['operations' => [$refundOperation]])->assertOk()->assertJsonPath('results.0.status', 'already_processed');

        $this->assertDatabaseCount('refunds', 1);
        $this->assertDatabaseCount('refund_items', 1);
        $this->assertDatabaseHas('inventory_items', ['branch_id' => $branchId, 'product_id' => $productId, 'quantity' => -1]);
        $this->assertDatabaseHas('stock_movements', ['source_type' => 'refund', 'source_id' => $refundId, 'reason' => 'return', 'quantity_delta' => 1]);
    }

    public function test_offline_register_shift_syncs_cash_movements_and_variance(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $shiftId = (string) Str::uuid();
        $movementId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId]));
        $openedAt = now()->subHour()->toIso8601String();
        $operations = [
            ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'register.open', 'payload' => ['id' => $shiftId, 'opening_cash' => 100, 'opened_at' => $openedAt]],
            ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'register.cash_movement', 'payload' => ['id' => $movementId, 'shift_id' => $shiftId, 'type' => 'cash_in', 'amount' => 20, 'occurred_at' => now()->toIso8601String()]],
            ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'register.close', 'payload' => ['id' => $shiftId, 'actual_cash' => 125, 'closed_at' => now()->toIso8601String()]],
        ];

        $this->postJson('/api/sync/push', ['operations' => $operations])->assertOk()
            ->assertJsonPath('results.0.status', 'processed')->assertJsonPath('results.1.status', 'processed')->assertJsonPath('results.2.status', 'processed');

        $this->assertDatabaseHas('register_shifts', ['id' => $shiftId, 'status' => 'closed', 'expected_cash' => 120, 'actual_cash' => 125, 'variance' => 5]);
        $this->assertDatabaseHas('cash_movements', ['id' => $movementId, 'type' => 'cash_in', 'amount' => 20]);
    }

    public function test_credit_settlement_and_operating_expense_sync_across_devices(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        $productId = (string) Str::uuid();
        $deviceId = (string) Str::uuid();
        $saleId = (string) Str::uuid();
        $creditId = (string) Str::uuid();
        $paymentId = (string) Str::uuid();
        $expenseId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('products')->insert(['id' => $productId, 'business_id' => $businessId, 'name' => 'Rice', 'selling_price' => 250, 'cost_price' => 180, 'unit' => 'piece', 'allow_negative_stock' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('devices')->insert(['id' => $deviceId, 'business_id' => $businessId, 'branch_id' => $branchId, 'name' => 'Counter 1', 'mode' => 'hosted', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'cashier']));

        $sale = [
            'operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'sale.create',
            'payload' => [
                'id' => $saleId, 'receipt_number' => 'TRX-CREDIT-1', 'gross_amount' => 250, 'net_amount' => 250,
                'items' => [['product_id' => $productId, 'quantity' => 1, 'unit_price' => 250, 'line_total' => 250]],
                'payments' => [['method' => 'credit', 'amount' => 250]],
                'credit' => ['id' => $creditId, 'customer_name' => 'Juan Dela Cruz', 'original_amount' => 250],
            ],
        ];
        $this->postJson('/api/sync/push', ['operations' => [$sale]])
            ->assertOk()->assertJsonPath('results.0.status', 'processed');
        $this->assertDatabaseHas('credits', ['id' => $creditId, 'sale_id' => $saleId, 'status' => 'unpaid', 'balance' => 250]);

        $operations = [
            ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'credit.payment', 'payload' => ['id' => $paymentId, 'credit_id' => $creditId, 'amount' => 250, 'method' => 'cash', 'paid_at' => now()->toIso8601String()]],
            ['operation_id' => (string) Str::uuid(), 'device_id' => $deviceId, 'type' => 'expense.create', 'payload' => ['id' => $expenseId, 'category' => 'Electricity', 'description' => 'Monthly electric bill', 'amount' => 650, 'payment_method' => 'cash', 'expense_date' => now()->toIso8601String()]],
        ];
        $this->postJson('/api/sync/push', ['operations' => $operations])->assertOk()
            ->assertJsonPath('results.0.status', 'processed')
            ->assertJsonPath('results.1.status', 'processed');

        $this->assertDatabaseHas('credits', ['id' => $creditId, 'status' => 'paid', 'balance' => 0]);
        $this->assertDatabaseHas('credit_payments', ['id' => $paymentId, 'credit_id' => $creditId, 'amount' => 250]);
        $this->assertDatabaseHas('expenses', ['id' => $expenseId, 'category' => 'Electricity', 'amount' => 650]);
        $query = http_build_query(['since' => now()->subDay()->toIso8601String()]);
        $this->getJson('/api/sync/pull?'.$query)->assertOk()
            ->assertJsonPath('credits.0.id', $creditId)
            ->assertJsonPath('credit_payments.0.id', $paymentId)
            ->assertJsonPath('expenses.0.id', $expenseId);
    }

    public function test_an_unregistered_device_cannot_push_operations(): void
    {
        $businessId = (string) Str::uuid();
        $branchId = (string) Str::uuid();
        DB::table('businesses')->insert(['id' => $businessId, 'name' => 'Test Store', 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main', 'code' => 'MAIN', 'timezone' => 'Asia/Manila', 'created_at' => now(), 'updated_at' => now()]);
        Sanctum::actingAs(User::factory()->create(['business_id' => $businessId, 'branch_id' => $branchId]));

        $this->postJson('/api/sync/push', ['operations' => [[
            'operation_id' => (string) Str::uuid(), 'device_id' => (string) Str::uuid(), 'type' => 'sale.create', 'payload' => ['id' => (string) Str::uuid()],
        ]]])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Register this device before synchronizing.');
    }
}
