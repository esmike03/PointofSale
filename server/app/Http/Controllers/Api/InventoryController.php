<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuditService;
use App\Services\InventoryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryController extends Controller
{
    public function index(Request $request)
    {
        $branchId = $request->string('branch_id')->toString();
        $query = DB::table('inventory_items')
            ->join('products', 'inventory_items.product_id', '=', 'products.id')
            ->join('branches', 'inventory_items.branch_id', '=', 'branches.id')
            ->where('branches.business_id', $request->user()->business_id)
            ->whereNull('products.deleted_at')
            ->select('inventory_items.*', 'products.name as product_name', 'products.sku', 'products.unit', 'products.reorder_level', 'branches.name as branch_name');
        if ($branchId) $query->where('inventory_items.branch_id', $branchId);
        return response()->json($query->orderBy('products.name')->paginate(min($request->integer('per_page', 50), 100)));
    }

    public function movements(Request $request)
    {
        $query = DB::table('stock_movements')
            ->join('products', 'stock_movements.product_id', '=', 'products.id')
            ->join('branches', 'stock_movements.branch_id', '=', 'branches.id')
            ->where('stock_movements.business_id', $request->user()->business_id)
            ->select('stock_movements.*', 'products.name as product_name', 'products.sku', 'branches.name as branch_name');
        if ($request->filled('branch_id')) $query->where('stock_movements.branch_id', $request->string('branch_id')->toString());
        if ($request->filled('product_id')) $query->where('stock_movements.product_id', $request->string('product_id')->toString());
        return response()->json($query->orderByDesc('occurred_at')->paginate(min($request->integer('per_page', 50), 100)));
    }

    public function lowStock(Request $request)
    {
        $query = DB::table('inventory_items')
            ->join('products', 'inventory_items.product_id', '=', 'products.id')
            ->join('branches', 'inventory_items.branch_id', '=', 'branches.id')
            ->where('branches.business_id', $request->user()->business_id)
            ->whereColumn('inventory_items.quantity', '<=', 'products.reorder_level')
            ->whereNull('products.deleted_at')
            ->select('inventory_items.*', 'products.name as product_name', 'products.sku', 'products.reorder_level', 'branches.name as branch_name');
        if ($request->filled('branch_id')) $query->where('inventory_items.branch_id', $request->string('branch_id')->toString());
        return response()->json($query->orderBy('inventory_items.quantity')->get());
    }

    public function receive(Request $request, InventoryService $inventory, AuditService $audit)
    {
        $this->authorizeInventory($request);
        $data = $request->validate($this->itemsRules(['supplier_id' => ['nullable', 'uuid'], 'reference' => ['nullable', 'string', 'max:100'], 'note' => ['nullable', 'string', 'max:1000'], 'received_at' => ['nullable', 'date']], ['unit_cost' => ['nullable', 'numeric', 'min:0'], 'batch_number' => ['nullable', 'string', 'max:100'], 'expires_on' => ['nullable', 'date']]));
        $id = $inventory->receive($data, $request->user());
        $audit->record($request->user(), 'inventory.received', 'stock_receipt', $id, null, $data);
        return response()->json(['id' => $id], 201);
    }

    public function adjust(Request $request, InventoryService $inventory, AuditService $audit)
    {
        $this->authorizeInventory($request);
        $data = $request->validate(['branch_id' => ['required', 'uuid'], 'product_id' => ['required', 'uuid'], 'quantity_delta' => ['required', 'numeric', 'not_in:0'], 'reason' => ['required', 'in:adjustment,damage,expired,return_in,return_out'], 'note' => ['nullable', 'string', 'max:1000']]);
        $id = $inventory->adjust($data, $request->user());
        $audit->record($request->user(), 'inventory.adjusted', 'adjustment', $id, null, $data);
        return response()->json(['id' => $id], 201);
    }

    public function transfer(Request $request, InventoryService $inventory, AuditService $audit)
    {
        $this->authorizeInventory($request);
        $data = $request->validate(['source_branch_id' => ['required', 'uuid'], 'destination_branch_id' => ['required', 'uuid'], 'reference' => ['nullable', 'string', 'max:100'], 'note' => ['nullable', 'string', 'max:1000'], 'transferred_at' => ['nullable', 'date'], 'items' => ['required', 'array', 'min:1'], 'items.*.product_id' => ['required', 'uuid'], 'items.*.quantity' => ['required', 'numeric', 'gt:0']]);
        $id = $inventory->transfer($data, $request->user());
        $audit->record($request->user(), 'inventory.transferred', 'stock_transfer', $id, null, $data);
        return response()->json(['id' => $id], 201);
    }

    public function count(Request $request, InventoryService $inventory, AuditService $audit)
    {
        $this->authorizeInventory($request);
        $data = $request->validate(['branch_id' => ['required', 'uuid'], 'reference' => ['nullable', 'string', 'max:100'], 'note' => ['nullable', 'string', 'max:1000'], 'counted_at' => ['nullable', 'date'], 'items' => ['required', 'array', 'min:1'], 'items.*.product_id' => ['required', 'uuid'], 'items.*.counted_quantity' => ['required', 'numeric', 'min:0']]);
        $id = $inventory->count($data, $request->user());
        $audit->record($request->user(), 'inventory.counted', 'stock_count', $id, null, $data);
        return response()->json(['id' => $id], 201);
    }

    private function authorizeInventory(Request $request): void
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff'), 403, 'You are not allowed to manage inventory.');
    }

    private function itemsRules(array $extra, array $itemExtra): array
    {
        return [...['branch_id' => ['required', 'uuid'], 'items' => ['required', 'array', 'min:1'], 'items.*.product_id' => ['required', 'uuid'], 'items.*.quantity' => ['required', 'numeric', 'gt:0']], ...$extra, ...collect($itemExtra)->mapWithKeys(fn ($rules, $key) => ["items.*.{$key}" => $rules])->all()];
    }
}
