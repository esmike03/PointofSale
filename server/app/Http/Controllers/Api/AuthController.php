<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        abort_unless(config('pos.allow_public_registration'), 403, 'Public registration is disabled.');
        $data = $request->validate([
            'business_name' => ['required', 'string', 'max:120'],
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $user = DB::transaction(function () use ($data) {
            $businessId = (string) Str::uuid();
            $branchId = (string) Str::uuid();
            DB::table('businesses')->insert([
                'id' => $businessId, 'name' => $data['business_name'], 'currency' => 'PHP',
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('branches')->insert([
                'id' => $branchId, 'business_id' => $businessId, 'name' => 'Main Branch',
                'code' => 'MAIN', 'timezone' => config('app.timezone'), 'created_at' => now(), 'updated_at' => now(),
            ]);
            return User::create([
                'name' => $data['name'], 'email' => $data['email'], 'password' => Hash::make($data['password']),
                'business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'super_admin',
            ]);
        });

        return response()->json(['user' => $user, 'token' => $user->createToken('pos-device')->plainTextToken], 201);
    }

    public function login(Request $request)
    {
        // Accept a username or an email in the same field so cashiers can sign in
        // with a username while existing email-only owners still work.
        $data = $request->validate(['username' => ['required', 'string'], 'password' => ['required', 'string']]);
        $login = trim($data['username']);
        $user = User::where('username', $login)->orWhere('email', $login)->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Invalid credentials.'], 422);
        }
        if ($user->deactivated_at !== null) {
            return response()->json(['message' => 'This account has been deactivated. Contact your manager.'], 403);
        }
        return ['user' => $user, 'token' => $user->createToken('pos-device')->plainTextToken];
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();
        return response()->noContent();
    }
}
