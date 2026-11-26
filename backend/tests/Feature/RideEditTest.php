<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideEditTest extends TestCase
{
    use RefreshDatabase;

    private function publish(User $driver): int
    {
        Sanctum::actingAs($driver);

        return $this->postJson('/api/v1/rides', [
            'origin' => 'Cerro Largo', 'destination' => 'URI',
            'departure_date' => now()->addDay()->toDateString(), 'departure_time' => '07:30',
            'total_seats' => 3,
        ])->assertCreated()->json('ride.id');
    }

    public function test_driver_edits_ride_and_pending_passenger_is_notified(): void
    {
        $driver = User::factory()->create();
        $rideId = $this->publish($driver);
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);
        $this->postJson("/api/v1/rides/{$rideId}/requests", ['pickup_lat' => -28.15, 'pickup_lng' => -54.74])->assertCreated();

        Sanctum::actingAs($driver);
        $this->putJson("/api/v1/rides/{$rideId}", ['departure_time' => '08:15', 'total_seats' => 2, 'notes' => 'Saio da praça'])
            ->assertOk()
            ->assertJsonPath('ride.departure_time', '08:15:00')
            ->assertJsonPath('ride.available_seats', 2)
            ->assertJsonPath('ride.notes', 'Saio da praça');

        $this->assertTrue(UserNotification::where('user_id', $passenger->id)->where('type', 'ride_updated')->exists());
    }

    public function test_cannot_edit_after_accepting_or_as_other_user(): void
    {
        $driver = User::factory()->create();
        $rideId = $this->publish($driver);

        Sanctum::actingAs(User::factory()->create());
        $this->putJson("/api/v1/rides/{$rideId}", ['total_seats' => 1])->assertForbidden();

        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);
        $requestId = $this->postJson("/api/v1/rides/{$rideId}/requests", ['pickup_lat' => -28.15, 'pickup_lng' => -54.74])->json('request.id');
        Sanctum::actingAs($driver);
        $this->patchJson("/api/v1/rides/{$rideId}/requests/{$requestId}", ['action' => 'accepted'])->assertOk();

        $this->putJson("/api/v1/rides/{$rideId}", ['total_seats' => 1])->assertUnprocessable();
    }
}
