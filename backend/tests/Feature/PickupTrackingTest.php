<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserNotification;
use App\Services\PickupProximityService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PickupTrackingTest extends TestCase
{
    use RefreshDatabase;

    /** Praça de Cerro Largo (aprox.) usada como ponto de encontro. */
    private const PICKUP = [-28.1467, -54.7383];

    /**
     * @return array{0: User, 1: User, 2: User, 3: int}
     */
    private function activeRideWithTwoPassengers(): array
    {
        Carbon::setTestNow('2026-12-01 10:00:00');
        [$driver, $ana, $bruno] = User::factory()->count(3)->create();

        Sanctum::actingAs($driver);
        $rideId = $this->postJson('/api/v1/rides', [
            'origin' => 'Cerro Largo', 'destination' => 'URI Santo Ângelo',
            'departure_date' => '2026-12-01', 'departure_time' => '11:00', 'total_seats' => 3,
        ])->assertCreated()->json('ride.id');

        Sanctum::actingAs($ana);
        $anaRequest = $this->postJson("/api/v1/rides/{$rideId}/requests", [
            'pickup_lat' => self::PICKUP[0], 'pickup_lng' => self::PICKUP[1], 'pickup_label' => 'Praça',
        ])->assertCreated()->assertJsonPath('request.pickup_label', 'Praça')->json('request.id');

        Sanctum::actingAs($bruno);
        $brunoRequest = $this->postJson("/api/v1/rides/{$rideId}/requests", [
            'pickup_lat' => -28.30, 'pickup_lng' => -54.26,
        ])->json('request.id');

        Sanctum::actingAs($driver);
        foreach ([$anaRequest, $brunoRequest] as $id) {
            $this->patchJson("/api/v1/rides/{$rideId}/requests/{$id}", ['action' => 'accepted'])->assertOk();
        }
        $this->postJson("/api/v1/rides/{$rideId}/start")->assertOk();

        return [$driver, $ana, $bruno, $rideId];
    }

    public function test_driver_sees_all_stops_and_passenger_only_their_own(): void
    {
        [$driver, $ana, , $rideId] = $this->activeRideWithTwoPassengers();

        Sanctum::actingAs($driver);
        $this->getJson("/api/v1/rides/{$rideId}/location")->assertOk()->assertJsonCount(2, 'data.stops');

        Sanctum::actingAs($ana);
        $this->getJson("/api/v1/rides/{$rideId}/location")->assertOk()
            ->assertJsonCount(1, 'data.stops')
            ->assertJsonPath('data.stops.0.passenger_id', $ana->id);
    }

    public function test_near_and_arrived_alerts_are_sent_once(): void
    {
        [$driver, $ana, , $rideId] = $this->activeRideWithTwoPassengers();
        Sanctum::actingAs($driver);
        $send = fn (float $lat, float $lng) => $this->putJson("/api/v1/rides/{$rideId}/location", ['latitude' => $lat, 'longitude' => $lng])->assertOk();
        $types = fn () => UserNotification::where('user_id', $ana->id)->whereIn('type', ['driver_near', 'driver_arrived'])->pluck('type')->all();

        $send(-28.20, -54.74);             // ~6 km: nenhum aviso
        $this->assertSame([], $types());

        $send(-28.1600, -54.7383);         // ~1,5 km: "a caminho"
        $send(-28.1590, -54.7383);         // de novo perto: não repete
        $this->assertSame(['driver_near'], $types());

        $send(self::PICKUP[0] + 0.0005, self::PICKUP[1]); // ~55 m: chegou
        $send(self::PICKUP[0], self::PICKUP[1]);
        $this->assertSame(['driver_near', 'driver_arrived'], $types());
    }

    public function test_haversine_distance(): void
    {
        // 0,01° de latitude ≈ 1 112 m.
        $this->assertEqualsWithDelta(1112, PickupProximityService::distanceMeters(-28.0, -54.0, -28.01, -54.0), 2);
    }
}
