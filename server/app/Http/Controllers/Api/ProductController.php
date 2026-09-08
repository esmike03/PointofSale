<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = DB::table('products')
            ->where('business_id', $request->user()->business_id)
            ->when($request->boolean('archived'), fn ($query) => $query->whereNotNull('deleted_at'), fn ($query) => $query->whereNull('deleted_at'))
            ->when($request->string('search')->toString(), fn ($query, $search) => $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")->orWhere('sku', 'like', "%{$search}%");
            }))
            ->orderBy('name')->paginate(min($request->integer('per_page', 50), 100));

        return response()->json($products);
    }

    public function store(Request $request, AuditService $audit)
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff'), 403, 'You are not allowed to manage products.');
        $data = $request->validate([
            'id' => ['nullable', 'uuid'], 'name' => ['required', 'string', 'max:255'], 'sku' => ['nullable', 'string', 'max:100'],
            'selling_price' => ['required', 'numeric', 'min:0'], 'cost_price' => ['nullable', 'numeric', 'min:0'],
            'unit' => ['nullable', 'string', 'max:30'], 'category_id' => ['nullable', 'uuid'], 'barcode' => ['nullable', 'string', 'max:100'],
            'reorder_level' => ['nullable', 'numeric', 'min:0'], 'allow_negative_stock' => ['nullable', 'boolean'],
            'tax_category' => ['nullable', 'in:vatable,exempt,zero_rated'],
        ]);
        $id = $data['id'] ?? (string) Str::uuid();
        DB::transaction(function () use ($data, $id, $request) {
            DB::table('products')->insert([
                'id' => $id, 'business_id' => $request->user()->business_id, 'category_id' => $data['category_id'] ?? null,
                'sku' => $data['sku'] ?? null, 'name' => $data['name'], 'selling_price' => $data['selling_price'],
                'cost_price' => $data['cost_price'] ?? 0, 'unit' => $data['unit'] ?? 'piece', 'reorder_level' => $data['reorder_level'] ?? 0,
                'allow_negative_stock' => $data['allow_negative_stock'] ?? false,
                'tax_category' => $data['tax_category'] ?? 'vatable',
                'created_at' => now(), 'updated_at' => now(),
            ]);
            if (! empty($data['barcode'])) {
                DB::table('product_barcodes')->insert(['id' => (string) Str::uuid(), 'product_id' => $id, 'code' => $data['barcode'], 'type' => 'unknown', 'created_at' => now(), 'updated_at' => now()]);
            }
        });
        $audit->record($request->user(), 'product.created', 'product', $id, null, $data);

        return response()->json(DB::table('products')->find($id), 201);
    }

    public function archive(Request $request, string $productId, AuditService $audit)
    {
        return $this->setArchived($request, $productId, true, $audit);
    }

    public function restore(Request $request, string $productId, AuditService $audit)
    {
        return $this->setArchived($request, $productId, false, $audit);
    }

    public function reset(Request $request, AuditService $audit)
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner'), 403, 'Only an owner or administrator can reset the server product catalog.');
        $request->validate([
            'confirmation' => ['required', 'in:RESET PRODUCTS'],
        ]);

        $businessId = $request->user()->business_id;
        $productCount = DB::table('products')->where('business_id', $businessId)->count();
        $inventoryCount = DB::table('inventory_items')
            ->whereIn('product_id', DB::table('products')->select('id')->where('business_id', $businessId))
            ->count();
        $resetAt = now();

        DB::transaction(function () use ($request, $audit, $businessId, $productCount, $inventoryCount, $resetAt) {
            $productIds = DB::table('products')->select('id')->where('business_id', $businessId);
            DB::table('product_barcodes')->whereIn('product_id', clone $productIds)->delete();
            DB::table('inventory_items')->whereIn('product_id', clone $productIds)->delete();
            DB::table('products')->where('business_id', $businessId)->delete();

            $existingReset = DB::table('business_settings')
                ->where('business_id', $businessId)
                ->where('key', 'system.products_reset_at')
                ->first();
            DB::table('business_settings')->updateOrInsert(
                ['business_id' => $businessId, 'key' => 'system.products_reset_at'],
                [
                    'id' => $existingReset->id ?? (string) Str::uuid(),
                    'value' => $resetAt->toIso8601String(),
                    'created_at' => $existingReset->created_at ?? $resetAt,
                    'updated_at' => $resetAt,
                ]
            );

            $audit->record(
                $request->user(),
                'products.reset',
                'business',
                $businessId,
                ['product_count' => $productCount, 'inventory_count' => $inventoryCount],
                ['product_count' => 0, 'inventory_count' => 0, 'reset_at' => $resetAt->toIso8601String()]
            );
        });

        return response()->json([
            'deleted_products' => $productCount,
            'deleted_inventory_items' => $inventoryCount,
            'reset_at' => $resetAt->toIso8601String(),
        ]);
    }

    private function setArchived(Request $request, string $productId, bool $archived, AuditService $audit)
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff'), 403, 'You are not allowed to manage products.');
        $product = DB::table('products')->where('business_id', $request->user()->business_id)->where('id', $productId)->first();
        abort_unless($product, 404, 'Product not found.');
        DB::table('products')->where('id', $productId)->update(['deleted_at' => $archived ? now() : null, 'updated_at' => now()]);
        $audit->record($request->user(), $archived ? 'product.archived' : 'product.restored', 'product', $productId, (array) $product, ['archived' => $archived]);

        return response()->json(['id' => $productId, 'archived' => $archived]);
    }
}
