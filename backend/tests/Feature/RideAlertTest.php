<?php

namespace Tests\Feature;

use App\Models\RideAlert;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideAlertTest extends TestCase
{
    use RefreshDatabase;

    private function publish(User $driver, array $extra = []): void
    {
        Sanctum::actingAs($driver);
        $this->postJson('/api/v1/rides', $extra + [
            'origin' => 'Cerro Largo - Centro', 'destination' => 'URI Santo Ângelo',
            'departure_date' => now()->addDay()->toDateString(), 'departure_time' => '19:00',
            'total_seats' => 3,
        ])->assertCreated();
    }

    private function alertsOf(User $user): int
    {
        return UserNotification::where('user_id', $user->id)->where('type', 'ride_alert')->count();
    }

    public function test_matching_ride_notifies_ignoring_accents_and_case(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);
        $this->postJson('/api/v1/ride-alerts', [
            'origin' => 'cerro largo', 'destination' => 'santo angelo', 'from_time' => '18:00', 'to_time' => '23:59',
        ])->assertCreated();

        $this->publish(User::factory()->create());

        $this->assertSame(1, $this->alertsOf($passenger));
    }

    public function test_non_matching_time_or_place_does_not_notify(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);
        $this->postJson('/api/v1/ride-alerts', ['origin' => 'Cerro Largo', 'from_time' => '05:00', 'to_time' => '11:59'])->assertCreated();
        $this->postJson('/api/v1/ride-alerts', ['destination' => 'Erechim'])->assertCreated();

        $this->publish(User::factory()->create());

        $this->assertSame(0, $this->alertsOf($passenger));
    }

    public function test_expired_alert_blocked_driver_and_own_ride_are_ignored(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();
        RideAlert::create(['user_id' => $passenger->id, 'origin' => 'Cerro Largo', 'expires_at' => now()->subDay()]);
        $this->publish($driver);
        $this->assertSame(0, $this->alertsOf($passenger));

        Sanctum::actingAs($passenger);
        $this->postJson('/api/v1/ride-alerts', ['origin' => 'Cerro Largo'])->assertCreated();
        $this->postJson('/api/v1/blocks', ['blocked_id' => $driver->id])->assertSuccessful();
        $this->publish($driver);
        $this->publish($passenger);
        $this->assertSame(0, $this->alertsOf($passenger));
    }

    public function test_requires_origin_or_destination_and_can_be_deleted(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/ride-alerts', ['from_time' => '07:00'])->assertUnprocessable();

        $id = $this->postJson('/api/v1/ride-alerts', ['destination' => 'URI'])->json('alert.id');
        $this->getJson('/api/v1/ride-alerts')->assertJsonCount(1, 'data');

        Sanctum::actingAs(User::factory()->create());
        $this->deleteJson("/api/v1/ride-alerts/{$id}")->assertForbidden();

        Sanctum::actingAs($user);
        $this->deleteJson("/api/v1/ride-alerts/{$id}")->assertOk();
        $this->getJson('/api/v1/ride-alerts')->assertJsonCount(0, 'data');
    }
}
