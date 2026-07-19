<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CreatePosOwner extends Command
{
    protected $signature = 'pos:owner {business : Business name} {name : Owner name} {email : Owner email} {--password= : Password; omit to be prompted}';
    protected $description = 'Create the first business, main branch, and super admin owner.';

    public function handle(): int
    {
        if (User::where('email', $this->argument('email'))->exists()) {
            $this->error('A user with that email already exists.');
            return self::FAILURE;
        }
        $password = $this->option('password') ?: $this->secret('Password (minimum 8 characters)');
        if (! $password || strlen($password) < 8) {
            $this->error('Password must be at least 8 characters.');
            return self::FAILURE;
        }
        DB::transaction(function () use ($password) {
            $businessId = (string) Str::uuid();
            $branchId = (string) Str::uuid();
            DB::table('businesses')->insert(['id' => $businessId, 'name' => $this->argument('business'), 'currency' => 'PHP', 'created_at' => now(), 'updated_at' => now()]);
            DB::table('branches')->insert(['id' => $branchId, 'business_id' => $businessId, 'name' => 'Main Branch', 'code' => 'MAIN', 'timezone' => config('app.timezone'), 'created_at' => now(), 'updated_at' => now()]);
            User::create(['name' => $this->argument('name'), 'email' => $this->argument('email'), 'password' => Hash::make($password), 'business_id' => $businessId, 'branch_id' => $branchId, 'role' => 'super_admin']);
        });
        $this->info('POS owner created.');
        return self::SUCCESS;
    }
}
