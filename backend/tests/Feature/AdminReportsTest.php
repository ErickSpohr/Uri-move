<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminReportsTest extends TestCase
{
    use RefreshDatabase;

    private function report(User $reporter, User $reported, string $status = Report::STATUS_OPEN): Report
    {
        return Report::create([
            'reporter_id' => $reporter->id,
            'reported_id' => $reported->id,
            'reason' => 'misconduct',
            'details' => 'Atrasou e foi grosseiro.',
            'status' => $status,
        ]);
    }

    public function test_admin_lists_reports_with_reporter_count_and_pagination(): void
    {
        $admin = User::factory()->create(['role' => User::ROLE_ADMIN]);
        $reported = User::factory()->create();
        $this->report(User::factory()->create(), $reported);
        $this->report(User::factory()->create(), $reported, Report::STATUS_RESOLVED);

        Sanctum::actingAs($admin);
        $response = $this->getJson('/api/v1/admin/reports?status=open')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.reported_reports_count', 2)
            ->assertJsonPath('meta.total', 1);

        $this->assertNotNull($response->json('data.0.reporter.email'));
        $this->assertNotNull($response->json('data.0.reported.email'));
    }

    public function test_non_admin_cannot_access_reports_panel(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/admin/reports')->assertForbidden();
    }

    public function test_resolving_report_notifies_reporter(): void
    {
        $admin = User::factory()->create(['role' => User::ROLE_ADMIN]);
        $reporter = User::factory()->create();
        $report = $this->report($reporter, User::factory()->create());

        Sanctum::actingAs($admin);
        $this->patchJson("/api/v1/admin/reports/{$report->id}/status", ['status' => 'resolved'])
            ->assertOk()
            ->assertJsonPath('report.status', 'resolved');

        $this->assertDatabaseHas('notifications', ['user_id' => $reporter->id, 'type' => 'report_update']);
    }

    public function test_moving_to_review_does_not_notify(): void
    {
        $admin = User::factory()->create(['role' => User::ROLE_ADMIN]);
        $reporter = User::factory()->create();
        $report = $this->report($reporter, User::factory()->create());

        Sanctum::actingAs($admin);
        $this->patchJson("/api/v1/admin/reports/{$report->id}/status", ['status' => 'reviewing'])->assertOk();

        $this->assertDatabaseMissing('notifications', ['user_id' => $reporter->id]);
    }

    public function test_make_admin_command_promotes_configured_emails(): void
    {
        $user = User::factory()->create(['email' => 'Coordenacao@uri.edu.br']);
        config(['urimove.admin_emails' => ['coordenacao@uri.edu.br', 'inexistente@uri.edu.br']]);

        $this->artisan('users:make-admin')->assertSuccessful();

        $this->assertTrue($user->fresh()->isAdmin());
    }

    public function test_ra_is_hidden_from_other_users(): void
    {
        $ride = Ride::factory()->create();
        $ride->driver->update(['ra' => '123456']);

        Sanctum::actingAs(User::factory()->create());
        $driver = $this->getJson("/api/v1/rides/{$ride->id}")->assertOk()->json('data.driver');

        $this->assertArrayNotHasKey('ra', $driver);
    }
}
