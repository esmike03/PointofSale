<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class InventoryService
{
    public function receive(array $data, object $user): string
    {
        return DB::transaction(function () use ($data, $user) {
            $this->assertBranch($data['branch_id'], $user->business_id);
            if (! empty($data['supplier_id'])) $this->assertSupplier($data['supplier_id'], $user->business_id);
            $receiptId = (string) Str::uuid();
            DB::table('stock_receipts')->insert([
                'id' => $receiptId, 'business_id' => $user->business_id, 'branch_id' => $data['branch_id'],
                'supplier_id' => $data['supplier_id'] ?? null, 'received_by' => $user->id, 'reference' => $data['reference'] ?? null,
                'note' => $data['note'] ?? null, 'received_at' => $data['received_at'] ?? now(), 'created_at' => now(), 'updated_at' => now(),
            ]);
            foreach ($data['items'] as $item) {
                DB::table('stock_receipt_items')->insert([
                    'id' => (string) Str::uuid(), 'stock_receipt_id' => $receiptId, 'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'], 'unit_cost' => $item['unit_cost'] ?? 0, 'batch_number' => $item['batch_number'] ?? null,
                    'expires_on' => $item['expires_on'] ?? null, 'created_at' => now(), 'updated_at' => now(),
                ]);
                $this->move($data['branch_id'], $item['product_id'], (float) $item['quantity'], 'receive', 'stock_receipt', $receiptId, $user, $data['note'] ?? null);
            }
            return $receiptId;
        });
    }

    public function adjust(array $data, object $user): string
    {
        return DB::transaction(function () use ($data, $user) {
            $this->assertBranch($data['branch_id'], $user->business_id);
            $id = (string) Str::uuid();
            $this->move($data['branch_id'], $data['product_id'], (float) $data['quantity_delta'], $data['reason'], 'adjustment', $id, $user, $data['note'] ?? null);
            return $id;
        });
    }

    public function transfer(array $data, object $user): string
    {
        return DB::transaction(function () use ($data, $user) {
            $this->assertBranch($data['source_branch_id'], $user->business_id);
            $this->assertBranch($data['destination_branch_id'], $user->business_id);
            if ($data['source_branch_id'] === $data['destination_branch_id']) throw new \InvalidArgumentException('Choose two different branches.');
            $transferId = (string) Str::uuid();
            DB::table('stock_transfers')->insert([
                'id' => $transferId, 'business_id' => $user->business_id, 'source_branch_id' => $data['source_branch_id'],
                'destination_branch_id' => $data['destination_branch_id'], 'transferred_by' => $user->id,
                'reference' => $data['reference'] ?? null, 'note' => $data['note'] ?? null, 'transferred_at' => $data['transferred_at'] ?? now(),
                'created_at' => now(), 'updated_at' => now(),
            ]);
            foreach ($data['items'] as $item) {
                DB::table('stock_transfer_items')->insert(['id' => (string) Str::uuid(), 'stock_transfer_id' => $transferId, 'product_id' => $item['product_id'], 'quantity' => $item['quantity'], 'created_at' => now(), 'updated_at' => now()]);
                $this->move($data['source_branch_id'], $item['product_id'], -1 * (float) $item['quantity'], 'transfer_out', 'stock_transfer', $transferId, $user, $data['note'] ?? null);
                $this->move($data['destination_branch_id'], $item['product_id'], (float) $item['quantity'], 'transfer_in', 'stock_transfer', $transferId, $user, $data['note'] ?? null);
            }
            return $transferId;
        });
    }

    public function count(array $data, object $user): string
    {
        return DB::transaction(function () use ($data, $user) {
            $this->assertBranch($data['branch_id'], $user->business_id);
            $countId = (string) Str::uuid();
            DB::table('stock_counts')->insert(['id' => $countId, 'business_id' => $user->business_id, 'branch_id' => $data['branch_id'], 'counted_by' => $user->id, 'reference' => $data['reference'] ?? null, 'note' => $data['note'] ?? null, 'counted_at' => $data['counted_at'] ?? now(), 'created_at' => now(), 'updated_at' => now()]);
            foreach ($data['items'] as $item) {
                $product = $this->product($item['product_id'], $user->business_id);
                $inventory = DB::table('inventory_items')->where('branch_id', $data['branch_id'])->where('product_id', $product->id)->lockForUpdate()->first();
                $expected = (float) ($inventory->quantity ?? 0);
                $delta = (float) $item['counted_quantity'] - $expected;
                DB::table('stock_count_items')->insert(['id' => (string) Str::uuid(), 'stock_count_id' => $countId, 'product_id' => $product->id, 'expected_quantity' => $expected, 'counted_quantity' => $item['counted_quantity'], 'quantity_delta' => $delta, 'created_at' => now(), 'updated_at' => now()]);
                if ($delta != 0.0) $this->move($data['branch_id'], $product->id, $delta, 'stock_count', 'stock_count', $countId, $user, $data['note'] ?? null);
            }
            return $countId;
        });
    }

    private function move(string $branchId, string $productId, float $delta, string $reason, string $sourceType, string $sourceId, object $user, ?string $note): void
    {
        $product = $this->product($productId, $user->business_id);
        $inventory = DB::table('inventory_items')->where('branch_id', $branchId)->where('product_id', $productId)->lockForUpdate()->first();
        $newQuantity = (float) ($inventory->quantity ?? 0) + $delta;
        if ($newQuantity < 0 && ! $product->allow_negative_stock) throw new \InvalidArgumentException("Insufficient stock for {$product->name}.");
        DB::table('inventory_items')->updateOrInsert(['branch_id' => $branchId, 'product_id' => $productId], ['id' => $inventory?->id ?? (string) Str::uuid(), 'quantity' => $newQuantity, 'updated_at' => now(), 'created_at' => $inventory?->created_at ?? now()]);
        DB::table('stock_movements')->insert(['id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'branch_id' => $branchId, 'product_id' => $productId, 'user_id' => $user->id, 'reason' => $reason, 'quantity_delta' => $delta, 'source_type' => $sourceType, 'source_id' => $sourceId, 'note' => $note, 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function product(string $productId, string $businessId): object
    {
        return DB::table('products')->where('id', $productId)->where('business_id', $businessId)->whereNull('deleted_at')->first() ?? throw new \InvalidArgumentException('Unknown product.');
    }

    private function assertBranch(string $branchId, string $businessId): void
    {
        if (! DB::table('branches')->where('id', $branchId)->where('business_id', $businessId)->whereNull('deleted_at')->exists()) throw new \InvalidArgumentException('Unknown branch.');
    }

    private function assertSupplier(string $supplierId, string $businessId): void
    {
        if (! DB::table('suppliers')->where('id', $supplierId)->where('business_id', $businessId)->whereNull('deleted_at')->exists()) throw new \InvalidArgumentException('Unknown supplier.');
    }
}
