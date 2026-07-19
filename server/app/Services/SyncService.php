<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Throwable;

class SyncService
{
    public function __construct(private InventoryService $inventory)
    {
    }

    public function apply(array $operation, object $user): array
    {
        $existing = DB::table('sync_operations')
            ->where('business_id', $user->business_id)->where('operation_id', $operation['operation_id'])->first();
        if ($existing?->status === 'processed') return ['operation_id' => $operation['operation_id'], 'status' => 'already_processed'];

        // Persist the receipt of the operation outside the business transaction. A failed
        // operation then remains visible to an authorized user and can be retried safely.
        if (! $existing) {
            DB::table('sync_operations')->insertOrIgnore([
                'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'device_id' => $operation['device_id'],
                'operation_id' => $operation['operation_id'], 'type' => $operation['type'], 'status' => 'received',
                'payload' => json_encode($operation['payload']), 'created_at' => now(), 'updated_at' => now(),
            ]);
            $existing = DB::table('sync_operations')->where('business_id', $user->business_id)->where('operation_id', $operation['operation_id'])->first();
            if ($existing?->status === 'processed') return ['operation_id' => $operation['operation_id'], 'status' => 'already_processed'];
        }

        try {
            DB::transaction(function () use ($operation, $user) {
                match ($operation['type']) {
                    'sale.create' => $this->createSale($operation['payload'], $operation['device_id'], $user),
                    'sale.refund' => $this->refundSale($operation['payload'], $operation['device_id'], $user),
                    'product.create' => $this->createProduct($operation['payload'], $user),
                    'product.update' => $this->updateProduct($operation['payload'], $operation['device_id'], $user),
                    'product.archive' => $this->setProductArchived($operation['payload'], $operation['device_id'], $user, true),
                    'product.restore' => $this->setProductArchived($operation['payload'], $operation['device_id'], $user, false),
                    'product.delete' => $this->deleteProduct($operation['payload'], $operation['device_id'], $user),
                    'inventory.receive' => $this->inventory->receive($operation['payload'], $user),
                    'inventory.adjust' => $this->inventory->adjust($operation['payload'], $user),
                    'inventory.transfer' => $this->inventory->transfer($operation['payload'], $user),
                    'inventory.count' => $this->inventory->count($operation['payload'], $user),
                    'register.open' => $this->openRegister($operation['payload'], $operation['device_id'], $user),
                    'register.cash_movement' => $this->recordCashMovement($operation['payload'], $user),
                    'register.close' => $this->closeRegister($operation['payload'], $user),
                    'credit.create' => $this->createCredit($operation['payload'], $operation['device_id'], $user),
                    'credit.payment' => $this->recordCreditPayment($operation['payload'], $user),
                    'expense.create' => $this->createExpense($operation['payload'], $operation['device_id'], $user),
                    'settings.update' => $this->updateSetting($operation['payload'], $user),
                    default => throw new \InvalidArgumentException('Unsupported operation type.'),
                };
                DB::table('sync_operations')->where('business_id', $user->business_id)->where('operation_id', $operation['operation_id'])
                    ->update(['status' => 'processed', 'processed_at' => now(), 'error' => null, 'updated_at' => now()]);
            });
            return ['operation_id' => $operation['operation_id'], 'status' => 'processed'];
        } catch (Throwable $exception) {
            DB::table('sync_operations')->where('business_id', $user->business_id)->where('operation_id', $operation['operation_id'])
                ->update(['status' => 'failed', 'error' => $exception->getMessage(), 'updated_at' => now()]);
            return ['operation_id' => $operation['operation_id'], 'status' => 'failed', 'error' => $exception->getMessage()];
        }
    }

    private function createSale(array $sale, string $deviceId, object $user): void
    {
        if (DB::table('sales')->where('id', $sale['id'])->exists()) return;
        $items = $sale['items'] ?? [];
        if (empty($items)) throw new \InvalidArgumentException('A sale must include at least one item.');
        $gross = collect($items)->sum(fn ($item) => (float) $item['line_total']);
        $discount = (float) ($sale['discount_amount'] ?? 0);
        $net = $gross - $discount;
        if ($discount < 0 || $discount > $gross || round($gross, 4) !== round((float) $sale['gross_amount'], 4) || round($net, 4) !== round((float) $sale['net_amount'], 4)) throw new \InvalidArgumentException('Sale total does not match its items.');
        $paymentTotal = collect($sale['payments'] ?? [])->sum(fn ($payment) => (float) ($payment['amount'] ?? 0));
        if (abs($paymentTotal - $net) > 0.005) throw new \InvalidArgumentException('Payment total does not match the sale total.');
        $creditAmount = collect($sale['payments'] ?? [])->where('method', 'credit')->sum(fn ($payment) => (float) $payment['amount']);
        if ($creditAmount > 0 && empty($sale['credit'])) throw new \InvalidArgumentException('Customer details are required for a credit sale.');
        if (! empty($sale['credit']) && abs((float) ($sale['credit']['original_amount'] ?? 0) - $creditAmount) > 0.005) throw new \InvalidArgumentException('Credit amount does not match the credit payment portion.');

        $resolvedItems = [];
        foreach ($items as $item) {
            $product = DB::table('products')->where('id', $item['product_id'])->where('business_id', $user->business_id)->first();
            if (! $product) throw new \InvalidArgumentException('Unknown product in sale.');
            $resolvedItems[] = ['item' => $item, 'product' => $product];
        }
        $tax = $this->saleTaxBreakdown($resolvedItems, $gross, $discount, $sale['tax_mode'] ?? 'unregistered', (float) ($sale['vat_rate'] ?? 0));

        DB::table('sales')->insert([
            'id' => $sale['id'], 'business_id' => $user->business_id, 'branch_id' => $sale['branch_id'] ?? $user->branch_id,
            'device_id' => $deviceId, 'cashier_id' => $user->id, 'receipt_number' => $sale['receipt_number'],
            'receipt_name' => $sale['receipt_name'] ?? null,
            'status' => 'completed', 'gross_amount' => $sale['gross_amount'], 'discount_amount' => $sale['discount_amount'] ?? 0, 'discount_reason' => $sale['discount_reason'] ?? null,
            'net_amount' => $sale['net_amount'], 'tax_mode' => $tax['tax_mode'], 'vat_rate' => $tax['vat_rate'],
            'vatable_sales' => $tax['vatable_sales'], 'vat_amount' => $tax['vat_amount'],
            'vat_exempt_sales' => $tax['vat_exempt_sales'], 'zero_rated_sales' => $tax['zero_rated_sales'],
            'receipt_profile' => isset($sale['receipt_profile']) ? json_encode($sale['receipt_profile']) : null,
            'occurred_at' => $sale['occurred_at'] ?? now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        foreach ($resolvedItems as $resolved) {
            $item = $resolved['item'];
            $product = $resolved['product'];
            DB::table('sale_items')->insert([
                'id' => $item['id'] ?? (string) Str::uuid(), 'sale_id' => $sale['id'], 'product_id' => $product->id,
                'product_name' => $product->name, 'sku' => $product->sku, 'quantity' => $item['quantity'],
                'unit_price' => $item['unit_price'], 'discount_amount' => $item['discount_amount'] ?? 0, 'line_total' => $item['line_total'],
                'tax_category' => $product->tax_category ?? 'vatable',
                'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->recordStockSale($product, $item, $sale, $deviceId, $user);
        }
        foreach ($sale['payments'] ?? [] as $payment) {
            DB::table('payments')->insert(['id' => $payment['id'] ?? (string) Str::uuid(), 'sale_id' => $sale['id'], 'method' => $payment['method'], 'amount' => $payment['amount'], 'reference' => $payment['reference'] ?? null, 'created_at' => now(), 'updated_at' => now()]);
        }
        if (! empty($sale['credit'])) {
            $this->createCredit([...$sale['credit'], 'sale_id' => $sale['id'], 'receipt_number' => $sale['receipt_number']], $deviceId, $user);
        }
    }

    private function saleTaxBreakdown(array $resolvedItems, float $gross, float $discount, string $mode, float $vatRate): array
    {
        if (! in_array($mode, ['unregistered', 'non_vat', 'vat'], true)) throw new \InvalidArgumentException('Invalid tax registration mode.');
        if ($mode !== 'vat') return ['tax_mode' => $mode, 'vat_rate' => 0, 'vatable_sales' => 0, 'vat_amount' => 0, 'vat_exempt_sales' => 0, 'zero_rated_sales' => 0];
        if ($vatRate < 0 || $vatRate > 1) throw new \InvalidArgumentException('Invalid VAT rate.');
        $categories = ['vatable' => 0.0, 'exempt' => 0.0, 'zero_rated' => 0.0];
        foreach ($resolvedItems as $resolved) {
            $category = $resolved['product']->tax_category ?? 'vatable';
            if (! array_key_exists($category, $categories)) $category = 'vatable';
            $categories[$category] += (float) $resolved['item']['line_total'];
        }
        $afterDiscount = fn (string $category): float => $gross <= 0 ? 0 : $categories[$category] - ($discount * $categories[$category] / $gross);
        $inclusiveVatable = $afterDiscount('vatable');
        $vatableSales = $inclusiveVatable / (1 + $vatRate);
        return [
            'tax_mode' => 'vat', 'vat_rate' => $vatRate,
            'vatable_sales' => round($vatableSales, 4), 'vat_amount' => round($inclusiveVatable - $vatableSales, 4),
            'vat_exempt_sales' => round($afterDiscount('exempt'), 4), 'zero_rated_sales' => round($afterDiscount('zero_rated'), 4),
        ];
    }

    private function createCredit(array $data, string $deviceId, object $user): void
    {
        if (DB::table('credits')->where('id', $data['id'] ?? null)->exists()) return;
        $customerName = trim($data['customer_name'] ?? '');
        $amount = (float) ($data['original_amount'] ?? $data['amount'] ?? 0);
        if ($customerName === '' || $amount <= 0) throw new \InvalidArgumentException('Customer name and a positive credit amount are required.');
        if (! empty($data['sale_id'])) {
            $sale = DB::table('sales')->where('id', $data['sale_id'])->where('business_id', $user->business_id)->first();
            if (! $sale) throw new \InvalidArgumentException('Credit sale was not found.');
        }
        DB::table('credits')->insert([
            'id' => $data['id'], 'business_id' => $user->business_id, 'branch_id' => $data['branch_id'] ?? $user->branch_id,
            'device_id' => $deviceId, 'user_id' => $user->id, 'sale_id' => $data['sale_id'] ?? null,
            'receipt_number' => $data['receipt_number'] ?? null, 'customer_name' => $customerName,
            'customer_contact' => $data['customer_contact'] ?? null, 'original_amount' => $amount,
            'balance' => $amount, 'status' => 'unpaid', 'due_at' => $data['due_at'] ?? null,
            'note' => $data['note'] ?? null, 'paid_at' => null,
            'created_at' => $data['created_at'] ?? now(), 'updated_at' => now(),
        ]);
    }

    private function recordCreditPayment(array $data, object $user): void
    {
        if (DB::table('credit_payments')->where('id', $data['id'] ?? null)->exists()) return;
        $credit = DB::table('credits')->where('id', $data['credit_id'] ?? null)
            ->where('business_id', $user->business_id)->lockForUpdate()->first();
        if (! $credit) throw new \InvalidArgumentException('Credit account not found.');
        $amount = (float) ($data['amount'] ?? 0);
        if ($amount <= 0 || $amount > (float) $credit->balance + 0.005) throw new \InvalidArgumentException('Invalid credit payment amount.');
        $method = $data['method'] ?? '';
        if (! in_array($method, ['cash', 'card', 'gcash', 'maya', 'bank_transfer'], true)) throw new \InvalidArgumentException('Invalid credit payment method.');
        $paidAt = $data['paid_at'] ?? now();
        DB::table('credit_payments')->insert([
            'id' => $data['id'], 'credit_id' => $credit->id, 'amount' => $amount,
            'method' => $method, 'note' => $data['note'] ?? null, 'paid_at' => $paidAt,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $balance = max(0, (float) $credit->balance - $amount);
        DB::table('credits')->where('id', $credit->id)->update([
            'balance' => $balance, 'status' => $balance <= 0.005 ? 'paid' : 'unpaid',
            'paid_at' => $balance <= 0.005 ? $paidAt : null, 'updated_at' => now(),
        ]);
    }

    private function createExpense(array $data, string $deviceId, object $user): void
    {
        if (DB::table('expenses')->where('id', $data['id'] ?? null)->exists()) return;
        $category = trim($data['category'] ?? '');
        $description = trim($data['description'] ?? '');
        $amount = (float) ($data['amount'] ?? 0);
        if ($category === '' || $description === '' || $amount <= 0) throw new \InvalidArgumentException('Category, description, and a positive expense amount are required.');
        $method = $data['payment_method'] ?? '';
        if (! in_array($method, ['cash', 'card', 'gcash', 'maya', 'bank_transfer'], true)) throw new \InvalidArgumentException('Invalid expense payment method.');
        DB::table('expenses')->insert([
            'id' => $data['id'], 'business_id' => $user->business_id, 'branch_id' => $data['branch_id'] ?? $user->branch_id,
            'device_id' => $deviceId, 'user_id' => $user->id, 'category' => $category,
            'description' => $description, 'amount' => $amount, 'payment_method' => $method,
            'vendor' => $data['vendor'] ?? null, 'expense_date' => $data['expense_date'] ?? now(),
            'note' => $data['note'] ?? null, 'created_at' => $data['created_at'] ?? now(), 'updated_at' => now(),
        ]);
    }

    private function refundSale(array $refund, string $deviceId, object $user): void
    {
        if (DB::table('refunds')->where('id', $refund['id'])->exists()) return;
        if (! $user->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'cashier')) {
            throw new \InvalidArgumentException('You are not allowed to issue refunds.');
        }
        $sale = DB::table('sales')->where('id', $refund['sale_id'])->where('business_id', $user->business_id)->lockForUpdate()->first();
        if (! $sale) throw new \InvalidArgumentException('The original sale was not found.');
        if (empty($refund['items']) || empty(trim($refund['reason'] ?? ''))) throw new \InvalidArgumentException('Refund items and a reason are required.');
        if (! in_array($refund['method'] ?? '', ['cash', 'card', 'gcash', 'maya', 'bank_transfer'], true)) throw new \InvalidArgumentException('Invalid refund method.');

        $ratio = (float) $sale->gross_amount === 0.0 ? 1.0 : (float) $sale->net_amount / (float) $sale->gross_amount;
        $refundItems = [];
        $amount = 0.0;
        foreach ($refund['items'] as $requested) {
            $saleItem = DB::table('sale_items')->where('sale_id', $sale->id)->where('product_id', $requested['product_id'])->lockForUpdate()->first();
            if (! $saleItem) throw new \InvalidArgumentException('A selected sale item was not found.');
            $alreadyReturned = (float) DB::table('refund_items')->join('refunds', 'refund_items.refund_id', '=', 'refunds.id')
                ->where('refunds.sale_id', $sale->id)->where('refund_items.sale_item_id', $saleItem->id)->sum('refund_items.quantity');
            $quantity = (float) ($requested['quantity'] ?? 0);
            if ($quantity <= 0 || $quantity > (float) $saleItem->quantity - $alreadyReturned + 0.0001) {
                throw new \InvalidArgumentException("Return quantity exceeds the remaining quantity for {$saleItem->product_name}.");
            }
            $itemAmount = round($quantity * (float) $saleItem->unit_price * $ratio, 2);
            $amount += $itemAmount;
            $refundItems[] = ['request' => $requested, 'sale_item' => $saleItem, 'quantity' => $quantity, 'amount' => $itemAmount];
        }
        $alreadyRefunded = (float) DB::table('refunds')->where('sale_id', $sale->id)->sum('amount');
        $amount = min(round($amount, 2), round((float) $sale->net_amount - $alreadyRefunded, 2));
        if ($amount <= 0) throw new \InvalidArgumentException('This sale is already fully refunded.');
        if (round((float) ($refund['amount'] ?? -1), 2) !== $amount) throw new \InvalidArgumentException('Refund total does not match the returned items.');

        DB::table('refunds')->insert([
            'id' => $refund['id'], 'business_id' => $user->business_id, 'sale_id' => $sale->id,
            'device_id' => $deviceId, 'user_id' => $user->id, 'refund_number' => $refund['refund_number'],
            'amount' => $amount, 'method' => $refund['method'], 'reason' => trim($refund['reason']),
            'occurred_at' => $refund['occurred_at'] ?? now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        $allocated = 0.0;
        foreach ($refundItems as $index => $item) {
            $itemAmount = $index === array_key_last($refundItems) ? round($amount - $allocated, 2) : $item['amount'];
            $allocated += $itemAmount;
            DB::table('refund_items')->insert([
                'id' => $item['request']['id'] ?? (string) Str::uuid(), 'refund_id' => $refund['id'],
                'sale_item_id' => $item['sale_item']->id, 'product_id' => $item['sale_item']->product_id,
                'quantity' => $item['quantity'], 'amount' => $itemAmount, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->recordStockReturn($sale, $refund, $item['sale_item'], $item['quantity'], $deviceId, $user);
        }
        DB::table('audit_logs')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'user_id' => $user->id,
            'device_id' => $deviceId, 'action' => 'sale.refund', 'subject_type' => 'refund', 'subject_id' => $refund['id'],
            'after' => json_encode(['sale_id' => $sale->id, 'amount' => $amount, 'reason' => trim($refund['reason'])]),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function recordStockReturn(object $sale, array $refund, object $saleItem, float $quantity, string $deviceId, object $user): void
    {
        if (! $sale->branch_id) return;
        $inventory = DB::table('inventory_items')->where('branch_id', $sale->branch_id)->where('product_id', $saleItem->product_id)->lockForUpdate()->first();
        $newQuantity = (float) ($inventory->quantity ?? 0) + $quantity;
        DB::table('inventory_items')->updateOrInsert(
            ['branch_id' => $sale->branch_id, 'product_id' => $saleItem->product_id],
            ['id' => $inventory->id ?? (string) Str::uuid(), 'quantity' => $newQuantity, 'updated_at' => now(), 'created_at' => $inventory->created_at ?? now()]
        );
        DB::table('stock_movements')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'branch_id' => $sale->branch_id,
            'product_id' => $saleItem->product_id, 'device_id' => $deviceId, 'user_id' => $user->id,
            'reason' => 'return', 'quantity_delta' => $quantity, 'source_type' => 'refund', 'source_id' => $refund['id'],
            'note' => trim($refund['reason']), 'occurred_at' => $refund['occurred_at'] ?? now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function createProduct(array $product, object $user): void
    {
        if (! $user->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff')) throw new \InvalidArgumentException('You are not allowed to manage products.');
        if (empty($product['id']) || empty($product['name']) || ! isset($product['selling_price'])) throw new \InvalidArgumentException('Invalid product payload.');
        if (DB::table('products')->where('id', $product['id'])->exists()) return;
        DB::table('products')->insert([
            'id' => $product['id'], 'business_id' => $user->business_id, 'sku' => $product['sku'] ?? null,
            'name' => $product['name'], 'selling_price' => $product['selling_price'], 'cost_price' => $product['cost_price'] ?? 0,
            'unit' => $product['unit'] ?? 'piece', 'reorder_level' => $product['reorder_level'] ?? 0,
            'tax_category' => in_array($product['tax_category'] ?? 'vatable', ['vatable', 'exempt', 'zero_rated'], true) ? ($product['tax_category'] ?? 'vatable') : 'vatable',
            'allow_negative_stock' => $product['allow_negative_stock'] ?? false, 'client_updated_at' => $product['updated_at'] ?? now(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        if (! empty($product['barcode'])) {
            DB::table('product_barcodes')->insert(['id' => (string) Str::uuid(), 'product_id' => $product['id'], 'code' => $product['barcode'], 'type' => 'unknown', 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    private function updateProduct(array $data, string $deviceId, object $user): void
    {
        if (! $user->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff')) throw new \InvalidArgumentException('You are not allowed to manage products.');
        $product = DB::table('products')->where('id', $data['id'] ?? null)->where('business_id', $user->business_id)->first();
        if (! $product) throw new \InvalidArgumentException('Product not found.');
        if (empty(trim((string) ($data['name'] ?? ''))) || ! isset($data['selling_price'])) throw new \InvalidArgumentException('Invalid product payload.');

        DB::table('products')->where('id', $product->id)->update([
            'name' => trim($data['name']), 'sku' => $data['sku'] ?? null,
            'selling_price' => $data['selling_price'], 'cost_price' => $data['cost_price'] ?? 0,
            'unit' => $data['unit'] ?? 'piece', 'reorder_level' => $data['reorder_level'] ?? 0,
            'tax_category' => in_array($data['tax_category'] ?? 'vatable', ['vatable', 'exempt', 'zero_rated'], true) ? ($data['tax_category'] ?? 'vatable') : 'vatable',
            'client_updated_at' => $data['updated_at'] ?? now(), 'updated_at' => now(),
        ]);
        DB::table('product_barcodes')->where('product_id', $product->id)->delete();
        if (! empty($data['barcode'])) {
            DB::table('product_barcodes')->insert(['id' => (string) Str::uuid(), 'product_id' => $product->id, 'code' => $data['barcode'], 'type' => 'unknown', 'created_at' => now(), 'updated_at' => now()]);
        }
        DB::table('audit_logs')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'user_id' => $user->id,
            'device_id' => $deviceId, 'action' => 'product.updated', 'subject_type' => 'product', 'subject_id' => $product->id,
            'before' => json_encode((array) $product), 'after' => json_encode($data), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function deleteProduct(array $data, string $deviceId, object $user): void
    {
        if (! $user->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff')) throw new \InvalidArgumentException('You are not allowed to manage products.');
        $product = DB::table('products')->where('id', $data['id'] ?? null)->where('business_id', $user->business_id)->first();
        if (! $product) throw new \InvalidArgumentException('Product not found.');
        if ($product->deleted_at === null) throw new \InvalidArgumentException('Archive this product before deleting it.');

        $references = [
            'sale_items' => 'completed sales', 'refund_items' => 'returns',
            'stock_movements' => 'inventory history', 'stock_receipt_items' => 'stock receipts',
            'stock_transfer_items' => 'stock transfers', 'stock_count_items' => 'stock counts',
        ];
        foreach ($references as $table => $label) {
            if (DB::table($table)->where('product_id', $product->id)->exists()) {
                throw new \InvalidArgumentException("This product is referenced by {$label} and cannot be permanently deleted. Keep it archived to preserve business records.");
            }
        }
        $hasStock = DB::table('inventory_items')->where('product_id', $product->id)->where('quantity', '!=', 0)->exists();
        if ($hasStock) throw new \InvalidArgumentException('This product still has stock and cannot be permanently deleted.');

        DB::table('audit_logs')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'user_id' => $user->id,
            'device_id' => $deviceId, 'action' => 'product.deleted', 'subject_type' => 'product', 'subject_id' => $product->id,
            'before' => json_encode((array) $product), 'after' => json_encode(['permanently_deleted' => true]), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('product_barcodes')->where('product_id', $product->id)->delete();
        DB::table('inventory_items')->where('product_id', $product->id)->delete();
        DB::table('products')->where('id', $product->id)->delete();
    }

    private function setProductArchived(array $data, string $deviceId, object $user, bool $archived): void
    {
        if (! $user->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff')) throw new \InvalidArgumentException('You are not allowed to manage products.');
        $product = DB::table('products')->where('id', $data['id'] ?? null)->where('business_id', $user->business_id)->first();
        if (! $product) throw new \InvalidArgumentException('Product not found.');
        DB::table('products')->where('id', $product->id)->update([
            'deleted_at' => $archived ? now() : null,
            'client_updated_at' => $data['updated_at'] ?? now(),
            'updated_at' => now(),
        ]);
        DB::table('audit_logs')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'user_id' => $user->id,
            'device_id' => $deviceId, 'action' => $archived ? 'product.archived' : 'product.restored',
            'subject_type' => 'product', 'subject_id' => $product->id,
            'before' => json_encode(['deleted_at' => $product->deleted_at]), 'after' => json_encode(['archived' => $archived]),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function openRegister(array $data, string $deviceId, object $user): void
    {
        if (DB::table('register_shifts')->where('id', $data['id'])->exists()) return;
        if ((float) $data['opening_cash'] < 0) throw new \InvalidArgumentException('Opening cash must not be negative.');
        if (DB::table('register_shifts')->where('business_id', $user->business_id)->where('device_id', $deviceId)->where('status', 'open')->exists()) throw new \InvalidArgumentException('This device already has an open register shift.');
        DB::table('register_shifts')->insert([
            'id' => $data['id'], 'business_id' => $user->business_id, 'branch_id' => $user->branch_id,
            'device_id' => $deviceId, 'cashier_id' => $user->id, 'opening_cash' => $data['opening_cash'],
            'status' => 'open', 'opened_at' => $data['opened_at'] ?? now(), 'note' => $data['note'] ?? null,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function recordCashMovement(array $data, object $user): void
    {
        if (DB::table('cash_movements')->where('id', $data['id'])->exists()) return;
        if (! in_array($data['type'] ?? '', ['cash_in', 'cash_out'], true) || (float) ($data['amount'] ?? 0) <= 0) throw new \InvalidArgumentException('Invalid cash movement.');
        $shift = DB::table('register_shifts')->where('id', $data['shift_id'])->where('business_id', $user->business_id)->where('status', 'open')->first();
        if (! $shift) throw new \InvalidArgumentException('Register shift is not open.');
        DB::table('cash_movements')->insert([
            'id' => $data['id'], 'register_shift_id' => $shift->id, 'type' => $data['type'],
            'amount' => $data['amount'], 'note' => $data['note'] ?? null, 'occurred_at' => $data['occurred_at'] ?? now(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function closeRegister(array $data, object $user): void
    {
        $shift = DB::table('register_shifts')->where('id', $data['id'])->where('business_id', $user->business_id)->lockForUpdate()->first();
        if (! $shift || $shift->status === 'closed') return;
        $cashSales = (float) DB::table('payments')->join('sales', 'payments.sale_id', '=', 'sales.id')
            ->where('sales.device_id', $shift->device_id)->where('payments.method', 'cash')->where('sales.occurred_at', '>=', $shift->opened_at)->sum('payments.amount');
        $cashRefunds = (float) DB::table('refunds')->where('device_id', $shift->device_id)
            ->where('method', 'cash')->where('occurred_at', '>=', $shift->opened_at)->sum('amount');
        $cashIn = (float) DB::table('cash_movements')->where('register_shift_id', $shift->id)->where('type', 'cash_in')->sum('amount');
        $cashOut = (float) DB::table('cash_movements')->where('register_shift_id', $shift->id)->where('type', 'cash_out')->sum('amount');
        $expected = (float) $shift->opening_cash + $cashSales + $cashIn - $cashOut - $cashRefunds;
        $actual = (float) $data['actual_cash'];
        if ($actual < 0) throw new \InvalidArgumentException('Actual cash must not be negative.');
        DB::table('register_shifts')->where('id', $shift->id)->update([
            'status' => 'closed', 'closed_at' => $data['closed_at'] ?? now(), 'expected_cash' => $expected,
            'actual_cash' => $actual, 'variance' => $actual - $expected, 'note' => $data['note'] ?? $shift->note, 'updated_at' => now(),
        ]);
    }

    private function updateSetting(array $data, object $user): void
    {
        $key = trim($data['key'] ?? '');
        if ($key === '') throw new \InvalidArgumentException('Setting key is required.');
        $value = (string) ($data['value'] ?? '');
        $existing = DB::table('business_settings')->where('business_id', $user->business_id)->where('key', $key)->first();
        if ($existing) {
            DB::table('business_settings')->where('id', $existing->id)->update(['value' => $value, 'updated_at' => now()]);
        } else {
            DB::table('business_settings')->insert([
                'id' => (string) Str::uuid(), 'business_id' => $user->business_id,
                'key' => $key, 'value' => $value, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    private function recordStockSale(object $product, array $item, array $sale, string $deviceId, object $user): void
    {
        $branchId = $sale['branch_id'] ?? $user->branch_id;
        if (! $branchId) return;
        $inventory = DB::table('inventory_items')->where('branch_id', $branchId)->where('product_id', $product->id)->lockForUpdate()->first();
        $remaining = (float) ($inventory->quantity ?? 0) - (float) $item['quantity'];
        if ($remaining < 0 && ! $product->allow_negative_stock) throw new \InvalidArgumentException("Insufficient stock for {$product->name}.");
        DB::table('inventory_items')->updateOrInsert(['branch_id' => $branchId, 'product_id' => $product->id], ['id' => $inventory->id ?? (string) Str::uuid(), 'quantity' => $remaining, 'updated_at' => now(), 'created_at' => $inventory->created_at ?? now()]);
        DB::table('stock_movements')->insert(['id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'branch_id' => $branchId, 'product_id' => $product->id, 'device_id' => $deviceId, 'user_id' => $user->id, 'reason' => 'sale', 'quantity_delta' => -1 * (float) $item['quantity'], 'source_type' => 'sale', 'source_id' => $sale['id'], 'occurred_at' => $sale['occurred_at'] ?? now(), 'created_at' => now(), 'updated_at' => now()]);
    }
}
