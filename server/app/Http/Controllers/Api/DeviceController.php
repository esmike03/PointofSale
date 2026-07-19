<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DeviceController extends Controller
{
    public function register(Request $request, AuditService $audit)
    {
        $data = $request->validate([
            'id' => ['required', 'uuid'], 'name' => ['required', 'string', 'max:100'],
            'mode' => ['required', 'in:standalone,local_network,hosted'], 'branch_id' => ['nullable', 'uuid'],
            'settings' => ['nullable', 'array'],
        ]);
        $device = DB::table('devices')->where('id', $data['id'])->first();
        if ($device && $device->business_id !== $request->user()->business_id) {
            return response()->json(['message' => 'This device belongs to another business.'], 403);
        }
        DB::table('devices')->updateOrInsert(['id' => $data['id']], [
            'business_id' => $request->user()->business_id, 'branch_id' => $data['branch_id'] ?? $request->user()->branch_id,
            'name' => $data['name'], 'mode' => $data['mode'], 'settings' => isset($data['settings']) ? json_encode($data['settings']) : null,
            'last_seen_at' => now(), 'updated_at' => now(), 'created_at' => $device->created_at ?? now(),
        ]);
        $audit->record($request->user(), $device ? 'device.updated' : 'device.registered', 'device', $data['id'], null, $data, $data['id']);
        return response()->json(DB::table('devices')->find($data['id']), $device ? 200 : 201);
    }
}
