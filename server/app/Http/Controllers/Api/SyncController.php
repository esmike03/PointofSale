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
            'operations' => ['required', 'array', 'max:100'],
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
        $since = $request->date('since') ?? now()->subDays(30);
        $businessId = $request->user()->business_id;
        return response()->json([
            'server_time' => now()->toIso8601String(),
            'products' => DB::table('products')->where('business_id', $businessId)->where('updated_at', '>', $since)->get(),
            'barcodes' => DB::table('product_barcodes')->join('products', 'product_barcodes.product_id', '=', 'products.id')->where('products.business_id', $businessId)->where('product_barcodes.updated_at', '>', $since)->select('product_barcodes.*')->get(),
            'categories' => DB::table('categories')->where('business_id', $businessId)->where('updated_at', '>', $since)->whereNull('deleted_at')->get(),
            'inventory' => DB::table('inventory_items')->join('branches', 'inventory_items.branch_id', '=', 'branches.id')->where('branches.business_id', $businessId)->where('inventory_items.updated_at', '>', $since)->select('inventory_items.*')->get(),
            'credits' => DB::table('credits')->where('business_id', $businessId)->where('updated_at', '>', $since)->get(),
            'credit_payments' => DB::table('credit_payments')->join('credits', 'credit_payments.credit_id', '=', 'credits.id')->where('credits.business_id', $businessId)->where('credit_payments.updated_at', '>', $since)->select('credit_payments.*')->get(),
            'expenses' => DB::table('expenses')->where('business_id', $businessId)->where('updated_at', '>', $since)->get(),
            // Closed register shifts (and their cash movements) sync across devices as
            // history. Open shifts stay device-local so each drawer is independent.
            'register_shifts' => DB::table('register_shifts')->where('business_id', $businessId)->where('status', 'closed')->where('updated_at', '>', $since)->get(),
            'cash_movements' => DB::table('cash_movements')->join('register_shifts', 'cash_movements.register_shift_id', '=', 'register_shifts.id')->where('register_shifts.business_id', $businessId)->where('register_shifts.status', 'closed')->where('cash_movements.updated_at', '>', $since)->select('cash_movements.*')->get(),
            // Store/invoice identity (business-global key/value settings) syncs across devices.
            'settings' => DB::table('business_settings')->where('business_id', $businessId)->where('updated_at', '>', $since)->get(['key', 'value']),
        ]);
    }
}
