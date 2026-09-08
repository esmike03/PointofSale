<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ServerAccountSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_default_seeder_creates_one_usable_owner_idempotently(): void
    {
        $this->seed();
        $this->seed();

        $this->assertDatabaseCount('businesses', 1);
        $this->assertDatabaseCount('branches', 1);
        $this->assertDatabaseCount('users', 1);

        $owner = User::where('username', 'admin')->firstOrFail();
        $this->assertSame('admin@chirpy.local', $owner->email);
        $this->assertSame('super_admin', $owner->role);
        $this->assertNotNull($owner->business_id);
        $this->assertNotNull($owner->branch_id);
        $this->assertTrue(Hash::check('admin1234', $owner->password));
    }
}
