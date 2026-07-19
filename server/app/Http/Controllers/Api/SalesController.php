<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SalesController extends Controller
{
    public function showByReceipt(Request $request, string $receiptNumber)
    {
        $sale = DB::table('sales')
            ->where('business_id', $request->user()->business_id)
            ->where('receipt_number', $receiptNumber)
            ->whereNull('deleted_at')
            ->first();
        abort_unless($sale, 404, 'Receipt not found.');
        if (is_string($sale->receipt_profile ?? null)) {
            $sale->receipt_profile = json_decode($sale->receipt_profile, true);
        }

        $items = DB::table('sale_items')->where('sale_id', $sale->id)->orderBy('created_at')->get();
        $payments = DB::table('payments')->where('sale_id', $sale->id)->orderBy('created_at')->get();
        $refunds = DB::table('refunds')->where('sale_id', $sale->id)->orderByDesc('occurred_at')->get();
        $refundIds = $refunds->pluck('id');
        $refundItems = $refundIds->isEmpty()
            ? collect()
            : DB::table('refund_items')->whereIn('refund_id', $refundIds)->get();

        return response()->json([
            'sale' => $sale,
            'items' => $items,
            'payments' => $payments,
            'refunds' => $refunds,
            'refund_items' => $refundItems,
        ]);
    }
}
