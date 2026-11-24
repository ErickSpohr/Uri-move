<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideTrackingTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_confirmed_participants_can_see_an_active_ride_location(): void
    {
        $ride = Ride::factory()->create(['status' => Ride::STATUS_ACTIVE]);
        $passenger = User::factory()->create();
        $stranger = User::factory()->create();
        RidePassenger::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RidePassenger::STATUS_CONFIRMED,
        ]);

        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/rides/{$ride->id}/location")->assertForbidden();
        $this->putJson("/api/v1/rides/{$ride->id}/location", [
            'latitude' => -28.3, 'longitude' => -54.26,
        ])->assertForbidden();

        Sanctum::actingAs($ride->driver);
        $this->putJson("/api/v1/rides/{$ride->id}/location", [
            'latitude' => -28.3, 'longitude' => -54.26, 'accuracy_meters' => 25,
        ])->assertOk();

        Sanctum::actingAs($passenger);
        $this->getJson("/api/v1/rides/{$ride->id}/location")
            ->assertOk()
            ->assertJsonPath('data.sharing', true)
            ->assertJsonPath('data.latitude', -28.3)
            ->assertJsonPath('data.longitude', -54.26);

        $this->travel(31)->seconds();
        $this->getJson("/api/v1/rides/{$ride->id}/location")
            ->assertOk()
            ->assertJsonPath('data.sharing', false)
            ->assertJsonPath('data.latitude', null);

        Sanctum::actingAs($ride->driver);
        $this->putJson("/api/v1/rides/{$ride->id}/location", [
            'latitude' => -28.3, 'longitude' => -54.26,
        ])->assertOk();
        Sanctum::actingAs($passenger);
        $this->getJson("/api/v1/rides/{$ride->id}/location")
            ->assertOk()
            ->assertJsonPath('data.sharing', true);
    }

    public function test_driver_can_stop_sharing_and_tracking_requires_active_ride(): void
    {
        $ride = Ride::factory()->create(['status' => Ride::STATUS_SCHEDULED]);
        Sanctum::actingAs($ride->driver);

        $this->putJson("/api/v1/rides/{$ride->id}/location", [
            'latitude' => -28.3, 'longitude' => -54.26,
        ])->assertUnprocessable();

        $ride->update(['status' => Ride::STATUS_ACTIVE]);
        $this->putJson("/api/v1/rides/{$ride->id}/location", [
            'latitude' => -28.3, 'longitude' => -54.26,
        ])->assertOk();
        $this->deleteJson("/api/v1/rides/{$ride->id}/location")->assertOk();
        $this->assertDatabaseCount('ride_locations', 0);
    }
}
