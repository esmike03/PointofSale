<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class ManagementController extends Controller
{
    private const ROLES = ['admin', 'business_owner', 'store_manager', 'cashier', 'inventory_staff', 'auditor', 'accountant'];

    public function users(Request $request)
    {
        $this->authorizeManagement($request);
        return response()->json(User::query()
            ->where('business_id', $request->user()->business_id)
            ->select('id', 'name', 'email', 'username', 'role', 'branch_id', 'deactivated_at', 'created_at')
            ->orderBy('name')
            ->get());
    }

    public function createUser(Request $request, AuditService $audit)
    {
        $this->authorizeManagement($request);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:255', 'unique:users'],
            'username' => ['required', 'string', 'max:60', 'alpha_dash', 'unique:users'],
            'password' => ['required', 'string', 'min:8'],
            'role' => ['required', 'in:' . implode(',', self::ROLES)],
            'branch_id' => ['nullable', 'uuid'],
        ]);
        $branchId = $data['branch_id'] ?? $request->user()->branch_id;
        if ($branchId && ! DB::table('branches')->where('id', $branchId)->where('business_id', $request->user()->business_id)->whereNull('deleted_at')->exists()) {
            return response()->json(['message' => 'Unknown branch.'], 422);
        }
        $user = User::create([
            'name' => $data['name'], 'email' => $data['email'], 'username' => $data['username'], 'password' => Hash::make($data['password']),
            'business_id' => $request->user()->business_id, 'branch_id' => $branchId, 'role' => $data['role'],
        ]);
        $audit->record($request->user(), 'user.created', 'user', (string) $user->id, null, ['name' => $user->name, 'email' => $user->email, 'username' => $user->username, 'role' => $user->role]);
        return response()->json($user->only('id', 'name', 'email', 'username', 'role', 'branch_id', 'created_at'), 201);
    }

    public function updateUser(Request $request, string $userId, AuditService $audit)
    {
        $this->authorizeManagement($request);
        $user = User::where('id', $userId)->where('business_id', $request->user()->business_id)->first();
        if (! $user) {
            return response()->json(['message' => 'Staff member not found.'], 404);
        }
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            'username' => ['required', 'string', 'max:60', 'alpha_dash', Rule::unique('users')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:8'],
            'role' => ['required', 'in:' . implode(',', self::ROLES)],
            'branch_id' => ['nullable', 'uuid'],
        ]);
        $branchId = $data['branch_id'] ?? $user->branch_id;
        if ($branchId && ! DB::table('branches')->where('id', $branchId)->where('business_id', $request->user()->business_id)->whereNull('deleted_at')->exists()) {
            return response()->json(['message' => 'Unknown branch.'], 422);
        }
        $before = $user->only('name', 'email', 'username', 'role');
        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->username = $data['username'];
        $user->role = $data['role'];
        $user->branch_id = $branchId;
        if (! empty($data['password'])) {
            $user->password = Hash::make($data['password']);
        }
        $user->save();
        $audit->record($request->user(), 'user.updated', 'user', (string) $user->id, $before, $user->only('name', 'email', 'username', 'role'));
        return response()->json($user->only('id', 'name', 'email', 'username', 'role', 'branch_id', 'created_at'));
    }

    public function setUserStatus(Request $request, string $userId, bool $active, AuditService $audit)
    {
        $this->authorizeManagement($request);
        $user = User::where('id', $userId)->where('business_id', $request->user()->business_id)->first();
        if (! $user) {
            return response()->json(['message' => 'Staff member not found.'], 404);
        }
        if ((string) $user->id === (string) $request->user()->id) {
            return response()->json(['message' => 'You cannot change your own account status.'], 422);
        }
        if ($user->role === 'super_admin') {
            return response()->json(['message' => 'The business owner account cannot be deactivated.'], 422);
        }
        $user->deactivated_at = $active ? null : now();
        $user->save();
        if (! $active) {
            $user->tokens()->delete();
        }
        $audit->record($request->user(), $active ? 'user.reactivated' : 'user.deactivated', 'user', (string) $user->id, null, ['role' => $user->role]);
        return response()->json($user->only('id', 'name', 'email', 'username', 'role', 'branch_id', 'deactivated_at', 'created_at'));
    }

    public function deactivateUser(Request $request, string $userId, AuditService $audit)
    {
        return $this->setUserStatus($request, $userId, false, $audit);
    }

    public function reactivateUser(Request $request, string $userId, AuditService $audit)
    {
        return $this->setUserStatus($request, $userId, true, $audit);
    }

    public function auditLogs(Request $request)
    {
        $this->authorizeManagement($request);
        $logs = DB::table('audit_logs')
            ->leftJoin('users', 'audit_logs.user_id', '=', 'users.id')
            ->where('audit_logs.business_id', $request->user()->business_id)
            ->select('audit_logs.id', 'audit_logs.action', 'audit_logs.subject_type', 'audit_logs.subject_id', 'audit_logs.created_at', 'users.name as user_name')
            ->orderByDesc('audit_logs.created_at')
            ->limit(min($request->integer('limit', 50), 100))
            ->get();
        return response()->json($logs);
    }

    private function authorizeManagement(Request $request): void
    {
        abort_unless($request->user()->hasAnyRole('super_admin', 'admin', 'business_owner', 'store_manager'), 403, 'You are not allowed to manage this business.');
    }
}
