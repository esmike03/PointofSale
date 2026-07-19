<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AuditService
{
    public function record(object $user, string $action, string $subjectType, string $subjectId, ?array $before = null, ?array $after = null, ?string $deviceId = null): void
    {
        DB::table('audit_logs')->insert([
            'id' => (string) Str::uuid(), 'business_id' => $user->business_id, 'user_id' => $user->id,
            'device_id' => $deviceId, 'action' => $action, 'subject_type' => $subjectType, 'subject_id' => $subjectId,
            'before' => $before ? json_encode($before) : null, 'after' => $after ? json_encode($after) : null,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }
}
