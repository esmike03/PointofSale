<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SyncService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    public function push(Request $request, SyncService $sync)
    {
        $data = $request->validate([
            // A device back from a long spell offline can hold six figures of
            // queued work (a barcode-master import is one operation per item),
            // so the batch has to be large enough to drain in minutes.
            'operations' => ['required', 'array', 'max:500'],
            'operations.*.operation_id' => ['required', 'uuid'],
            'operations.*.device_id' => ['required', 'uuid'],
            'operations.*.type' => ['required', 'string', 'max:50'],
            'operations.*.payload' => ['required', 'array'],
        ]);
        $deviceIds = collect($data['operations'])->pluck('device_id')->unique();
        $registered = DB::table('devices')->where('business_id', $request->user()->business_id)->whereIn('id', $deviceIds)->pluck('id');
        if ($registered->count() !== $deviceIds->count()) {
            return response()->json(['message' => 'Register this device before synchronizing.'], 422);
        }
        DB::table('devices')->whereIn('id', $registered)->update(['last_seen_at' => now(), 'updated_at' => now()]);
        $results = array_map(fn ($operation) => $sync->apply($operation, $request->user()), $data['operations']);

        return response()->json(['results' => $results]);
    }

    public function pull(Request $request)
    {
        $scope = $request->string('scope')->toString() ?: 'all';
        abort_unless(in_array($scope, ['all', 'products', 'business_data'], true), 422, 'Invalid sync scope.');
        $since = $request->filled('since') ? $request->date('since') : null;
        $serverTime = $request->filled('until') ? $request->date('until') : now();
        $businessId = $request->user()->business_id;
        $changed = static fn ($query) => $since === null
            ? $query
            : $query->where('updated_at', '>', $since);
        $response = [
            'server_time' => $serverTime->toIso8601String(),
            'scope' => $scope,
            'full_snapshot' => $since === null,
        ];
        if ($scope === 'products' || $scope === 'all') {
            $response['products_reset_at'] = DB::table('business_settings')
                ->where('business_id', $businessId)
                ->where('key', 'system.products_reset_at')
                ->value('value');
        }

        if ($scope === 'products') {
            $limit = min(max($request->integer('limit', 2000), 100), 5000);
            $cursor = $request->string('cursor')->toString();
            $products = DB::table('products')
                ->where('business_id', $businessId)
                ->where('updated_at', '<=', $serverTime)
                ->when($since, fn ($query) => $query->where('updated_at', '>', $since))
                ->when($cursor, fn ($query) => $query->where('id', '>', $cursor))
                ->orderBy('id')
                ->limit($limit + 1)
                ->get();
            $hasMore = $products->count() > $limit;
            $page = $products->take($limit)->values();
            $productIds = $page->pluck('id');
            $response['products'] = $page;
            // Return the complete current barcode set for every product in the
            // page. A product-only timestamp filter loses unchanged barcodes
            // when the product itself is archived, restored, or repriced.
            $response['barcodes'] = $productIds->isEmpty()
                ? []
                : DB::table('product_barcodes')->whereIn('product_id', $productIds)->get();
            $response['categories'] = $cursor === ''
                ? $changed(DB::table('categories')->where('business_id', $businessId)->whereNull('deleted_at'))->get()
                : [];
            $response['has_more'] = $hasMore;
            $response['next_cursor'] = $hasMore ? $page->last()->id : null;
        } elseif ($scope === 'all') {
            $products = DB::table('products')->where('business_id', $businessId);
            $categories = DB::table('categories')->where('business_id', $businessId)->whereNull('deleted_at');
            $response['products'] = $changed($products)->get();
            $response['barcodes'] = DB::table('product_barcodes')
                ->join('products', 'product_barcodes.product_id', '=', 'products.id')
                ->where('products.business_id', $businessId)
                ->when($since, fn ($query) => $query->where(function ($query) use ($since) {
                    $query->where('product_barcodes.updated_at', '>', $since)
                        ->orWhere('products.updated_at', '>', $since);
                }))
                ->select('product_barcodes.*')
                ->get();
            $response['categories'] = $changed($categories)->get();
        }

        if ($scope === 'all' || $scope === 'business_data') {
            $inventory = DB::table('inventory_items')->join('branches', 'inventory_items.branch_id', '=', 'branches.id')->where('branches.business_id', $businessId)->select('inventory_items.*');
            $credits = DB::table('credits')->where('business_id', $businessId);
            $creditPayments = DB::table('credit_payments')->join('credits', 'credit_payments.credit_id', '=', 'credits.id')->where('credits.business_id', $businessId)->select('credit_payments.*');
            $expenses = DB::table('expenses')->where('business_id', $businessId);
            $response['inventory'] = $since === null ? $inventory->get() : $inventory->where('inventory_items.updated_at', '>', $since)->get();
            $response['credits'] = $changed($credits)->get();
            $response['credit_payments'] = $since === null ? $creditPayments->get() : $creditPayments->where('credit_payments.updated_at', '>', $since)->get();
            $response['expenses'] = $changed($expenses)->get();
            // Closed register shifts (and their cash movements) sync across devices as
            // history. Open shifts stay device-local so each drawer is independent.
            $shifts = DB::table('register_shifts')->where('business_id', $businessId)->where('status', 'closed');
            $movements = DB::table('cash_movements')->join('register_shifts', 'cash_movements.register_shift_id', '=', 'register_shifts.id')->where('register_shifts.business_id', $businessId)->where('register_shifts.status', 'closed')->select('cash_movements.*');
            $response['register_shifts'] = $changed($shifts)->get();
            $response['cash_movements'] = $since === null ? $movements->get() : $movements->where('cash_movements.updated_at', '>', $since)->get();
            // Store/invoice identity (business-global key/value settings) syncs across devices.
            $settings = DB::table('business_settings')
                ->where('business_id', $businessId)
                ->where('key', 'not like', 'system.%');
            $response['settings'] = $changed($settings)->get(['key', 'value']);
            if ($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager')) {
                $users = DB::table('users')->where('business_id', $businessId)
                    ->select('id', 'name', 'email', 'username', 'role', 'branch_id', 'deactivated_at', 'updated_at');
                $response['users'] = $changed($users)->get();
            }
        }

        return response()->json($response);
    }
}
