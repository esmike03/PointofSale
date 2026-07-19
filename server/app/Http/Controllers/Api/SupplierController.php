<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(DB::table('suppliers')->where('business_id', $request->user()->business_id)->whereNull('deleted_at')->orderBy('name')->get());
    }

    public function store(Request $request, AuditService $audit)
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager', 'inventory_staff'), 403, 'You are not allowed to manage suppliers.');
        $data = $request->validate(['name' => ['required', 'string', 'max:255'], 'contact_name' => ['nullable', 'string', 'max:255'], 'phone' => ['nullable', 'string', 'max:50'], 'email' => ['nullable', 'email', 'max:255'], 'address' => ['nullable', 'string', 'max:1000']]);
        $id = (string) Str::uuid();
        DB::table('suppliers')->insert(['id' => $id, 'business_id' => $request->user()->business_id, ...$data, 'created_at' => now(), 'updated_at' => now()]);
        $audit->record($request->user(), 'supplier.created', 'supplier', $id, null, $data);
        return response()->json(DB::table('suppliers')->find($id), 201);
    }
}
