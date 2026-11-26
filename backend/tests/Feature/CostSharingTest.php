<?php

namespace Tests\Feature;

use App\Models\RideRequest;
use App\Models\User;
use App\Services\Pricing\RidePricing;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CostSharingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['urimove.fuel_price' => 6.0, 'urimove.default_fuel_consumption' => 10]);
        // OSRM falso: rota direta 50 km / 40 min; com o embarque 54 km / 46 min.
        Http::fake(function (Request $request) {
            $stops = substr_count(parse_url($request->url(), PHP_URL_PATH), ';') + 1;

            return Http::response(['code' => 'Ok', 'routes' => [[
                'distance' => $stops === 3 ? 54000 : 50000,
                'duration' => $stops === 3 ? 46 * 60 : 40 * 60,
            ]]]);
        });
    }

    private function publish(User $driver, array $extra = []): int
    {
        Sanctum::actingAs($driver);
        $vehicleId = $this->postJson('/api/v1/vehicles', [
            'brand' => 'Fiat', 'model' => 'Argo', 'plate' => 'ABC1D23', 'seats' => 4, 'fuel_consumption' => 12,
        ])->assertCreated()->json('vehicle.id') ?? $this->getJson('/api/v1/vehicles')->json('data.0.id');

        return $this->postJson('/api/v1/rides', $extra + [
            'vehicle_id' => $vehicleId,
            'origin' => 'Cerro Largo', 'origin_lat' => -28.148, 'origin_lng' => -54.734,
            'destination' => 'URI Santo Ângelo', 'destination_lat' => -28.277, 'destination_lng' => -54.271,
            'departure_date' => now()->addDay()->toDateString(), 'departure_time' => '07:30',
            'total_seats' => 3, 'cost_sharing' => true,
        ])->assertCreated()->json('ride.id');
    }

    public function test_formula_helpers(): void
    {
        $this->assertSame(7.5, RidePricing::roundUpToHalf(7.01));
        $this->assertSame(7.0, RidePricing::roundUpToHalf(7.0));
        // 50 km × R$ 0,50/km ÷ (3 vagas + motorista) = 6,25 → 6,50
        $this->assertSame(6.5, RidePricing::baseShare(50, 0.5, 3));
    }

    public function test_publishing_computes_base_share_from_route_and_vehicle_consumption(): void
    {
        $rideId = $this->publish(User::factory()->create());

        // R$ 6,00 ÷ 12 km/L = R$ 0,50/km; 50 km × 0,50 ÷ 4 = 6,25 → 6,50
        $this->getJson("/api/v1/rides/{$rideId}")
            ->assertJsonPath('data.cost_sharing', true)
            ->assertJsonPath('data.price', 6.5)
            ->assertJsonPath('data.route_km', 50);
    }

    public function test_cost_sharing_requires_coordinates(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/v1/rides', [
            'origin' => 'Cerro Largo', 'destination' => 'URI',
            'departure_date' => now()->addDay()->toDateString(), 'departure_time' => '07:30',
            'total_seats' => 3, 'cost_sharing' => true,
        ])->assertUnprocessable()->assertJsonValidationErrors('origin_lat');
    }

    public function test_quote_and_request_include_detour(): void
    {
        $rideId = $this->publish(User::factory()->create());
        Sanctum::actingAs(User::factory()->create());
        $pickup = ['pickup_lat' => -28.20, 'pickup_lng' => -54.60];

        // Desvio 4 km × 0,50 = 2,00 → 6,50 + 2,00 = 8,50
        $this->getJson("/api/v1/rides/{$rideId}/quote?".http_build_query($pickup))
            ->assertOk()
            ->assertJsonPath('data.detour_km', 4)
            ->assertJsonPath('data.detour_minutes', 6)
            ->assertJsonPath('data.suggested_price', 8.5);

        $this->postJson("/api/v1/rides/{$rideId}/requests", $pickup)
            ->assertCreated()
            ->assertJsonPath('request.suggested_price', 8.5)
            ->assertJsonPath('request.detour_km', 4);
    }

    public function test_driver_can_lower_but_not_raise_price_on_accept(): void
    {
        $driver = User::factory()->create();
        $rideId = $this->publish($driver);
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);
        $requestId = $this->postJson("/api/v1/rides/{$rideId}/requests", ['pickup_lat' => -28.20, 'pickup_lng' => -54.60])->json('request.id');

        Sanctum::actingAs($driver);
        $this->patchJson("/api/v1/rides/{$rideId}/requests/{$requestId}", ['action' => 'accepted', 'price' => 20])
            ->assertUnprocessable();
        $this->patchJson("/api/v1/rides/{$rideId}/requests/{$requestId}", ['action' => 'accepted', 'price' => 5])
            ->assertOk();
        $this->assertSame(5.0, RideRequest::find($requestId)->agreed_price);

        Sanctum::actingAs($passenger);
        $this->getJson("/api/v1/rides/{$rideId}")->assertJsonPath('data.my_price', 5);
    }
}
