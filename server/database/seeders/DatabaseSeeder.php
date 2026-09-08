<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use RuntimeException;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Create one usable business, branch, and server owner account.
     *
     * The operation is idempotent: running db:seed again updates the same
     * owner instead of adding duplicate businesses or users.
     */
    public function run(): void
    {
        $businessName = env('POS_SEED_BUSINESS_NAME', 'Chirpy POS Demo');
        $ownerName = env('POS_SEED_OWNER_NAME', 'Server Administrator');
        $username = env('POS_SEED_OWNER_USERNAME', 'admin');
        $email = env('POS_SEED_OWNER_EMAIL', 'admin@chirpy.local');
        $password = env('POS_SEED_OWNER_PASSWORD');

        if (! is_string($password) || $password === '') {
            if (app()->environment('production')) {
                $this->command?->warn('Set POS_SEED_OWNER_PASSWORD before seeding a production server. No default owner was created.');

                return;
            }
            $password = 'admin1234';
        }
        if (strlen($password) < 8) {
            throw new RuntimeException('POS_SEED_OWNER_PASSWORD must contain at least 8 characters.');
        }

        DB::transaction(function () use ($businessName, $ownerName, $username, $email, $password): void {
            $owner = User::query()
                ->where('email', $email)
                ->orWhere('username', $username)
                ->first();

            $businessId = $owner?->business_id;
            if (! $businessId) {
                $businessId = DB::table('businesses')->where('name', $businessName)->value('id');
            }
            if (! $businessId) {
                $businessId = (string) Str::uuid();
                DB::table('businesses')->insert([
                    'id' => $businessId,
                    'name' => $businessName,
                    'currency' => 'PHP',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            $branchId = DB::table('branches')
                ->where('business_id', $businessId)
                ->where('code', 'MAIN')
                ->value('id');
            if (! $branchId) {
                $branchId = (string) Str::uuid();
                DB::table('branches')->insert([
                    'id' => $branchId,
                    'business_id' => $businessId,
                    'name' => 'Main Branch',
                    'code' => 'MAIN',
                    'timezone' => config('app.timezone'),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            $attributes = [
                'name' => $ownerName,
                'email' => $email,
                'username' => $username,
                'password' => Hash::make($password),
                'business_id' => $businessId,
                'branch_id' => $branchId,
                'role' => 'super_admin',
                'deactivated_at' => null,
            ];
            if ($owner) {
                $owner->forceFill($attributes)->save();
            } else {
                User::create($attributes);
            }
        });

        $this->command?->info("Server owner ready: {$username} ({$email})");
    }
}
