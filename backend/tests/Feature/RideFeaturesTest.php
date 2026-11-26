<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideFeaturesTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function ridePayload(array $extra = []): array
    {
        return $extra + [
            'origin' => 'Cerro Largo',
            'destination' => 'URI Santo Ângelo',
            'departure_date' => '2026-12-07',
            'departure_time' => '07:30',
            'total_seats' => 3,
        ];
    }

    protected function setUp(): void
    {
        parent::setUp();
        // Segunda-feira, 7 de dezembro de 2026 fica no futuro em relação a "hoje".
        Carbon::setTestNow('2026-12-01 10:00:00');
    }

    public function test_weekly_repetition_creates_series_on_chosen_weekdays(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        $this->postJson('/api/v1/rides', $this->ridePayload([
            'repeat_days' => [1, 3, 5],
            'repeat_until' => '2026-12-18',
        ]))->assertCreated()->assertJsonPath('rides_created', 6);

        $rides = Ride::orderBy('departure_date')->get();
        $this->assertSame(
            ['2026-12-07', '2026-12-09', '2026-12-11', '2026-12-14', '2026-12-16', '2026-12-18'],
            $rides->map(fn (Ride $ride) => $ride->departure_date->toDateString())->all(),
        );
        $this->assertCount(1, $rides->pluck('series_id')->unique());
        $this->assertNotNull($rides->first()->series_id);
    }

    public function test_repetition_limited_to_sixty_days(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/rides', $this->ridePayload([
            'repeat_days' => [1],
            'repeat_until' => '2027-03-01',
        ]))->assertUnprocessable()->assertJsonValidationErrors('repeat_until');
    }

    public function test_cancel_series_cancels_future_scheduled_rides_only(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);
        $this->postJson('/api/v1/rides', $this->ridePayload([
            'repeat_days' => [1, 3],
            'repeat_until' => '2026-12-16',
        ]))->assertCreated();
        $rides = Ride::orderBy('departure_date')->get();
        $rides->first()->update(['status' => Ride::STATUS_COMPLETED]);

        $this->postJson("/api/v1/rides/{$rides[1]->id}/cancel", ['scope' => 'series'])
            ->assertOk()
            ->assertJsonPath('cancelled_count', 3);

        $this->assertSame(Ride::STATUS_COMPLETED, $rides[0]->fresh()->status);
        $this->assertSame(3, Ride::where('status', Ride::STATUS_CANCELLED)->count());
    }

    public function test_women_only_rides_require_women_and_are_hidden_from_others(): void
    {
        $man = User::factory()->create(['gender' => 'man']);
        Sanctum::actingAs($man);
        $this->postJson('/api/v1/rides', $this->ridePayload(['women_only' => true]))->assertUnprocessable();

        $driver = User::factory()->create(['gender' => 'woman']);
        Sanctum::actingAs($driver);
        $rideId = $this->postJson('/api/v1/rides', $this->ridePayload(['women_only' => true]))
            ->assertCreated()
            ->assertJsonPath('ride.women_only', true)
            ->json('ride.id');

        Sanctum::actingAs($man);
        $this->getJson('/api/v1/rides')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/rides/{$rideId}/requests")->assertForbidden();

        Sanctum::actingAs(User::factory()->create(['gender' => 'woman']));
        $this->getJson('/api/v1/rides?women_only=1')->assertOk()->assertJsonCount(1, 'data');
        $this->postJson("/api/v1/rides/{$rideId}/requests")->assertCreated();
    }

    public function test_driver_pix_key_visible_only_to_confirmed_passengers(): void
    {
        $driver = User::factory()->create(['pix_key' => 'motorista@uri.edu.br']);
        $ride = Ride::factory()->create(['driver_id' => $driver->id, 'vehicle_id' => Vehicle::factory()->create(['user_id' => $driver->id])->id]);
        $confirmed = User::factory()->create();
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $confirmed->id, 'status' => 'confirmed']);
        $pending = User::factory()->create();
        RideRequest::create(['ride_id' => $ride->id, 'passenger_id' => $pending->id, 'status' => 'pending', 'seats_requested' => 1]);

        Sanctum::actingAs($pending);
        $this->assertArrayNotHasKey('driver_pix_key', $this->getJson("/api/v1/rides/{$ride->id}")->json('data'));

        Sanctum::actingAs($confirmed);
        $this->getJson("/api/v1/rides/{$ride->id}")->assertOk()->assertJsonPath('data.driver_pix_key', 'motorista@uri.edu.br');
    }

    public function test_user_can_save_own_pix_key(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/me', ['pix_key' => '55999990000'])
            ->assertOk()
            ->assertJsonPath('user.pix_key', '55999990000');
    }

    public function test_search_filters_time_range_and_max_price_keep_free_rides(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);
        foreach ([['07:30', 10], ['13:00', null], ['19:00', 25]] as [$time, $price]) {
            $this->postJson('/api/v1/rides', $this->ridePayload(['departure_time' => $time, 'price' => $price]))->assertCreated();
        }

        Sanctum::actingAs(User::factory()->create());
        $times = fn (array $query) => collect($this->getJson('/api/v1/rides?'.http_build_query($query + ['date' => '2026-12-07']))->assertOk()->json('data'))
            ->pluck('departure_time')->map(fn ($t) => substr($t, 0, 5))->all();

        $this->assertSame(['07:30'], $times(['from_time' => '05:00', 'to_time' => '11:59']));
        $this->assertSame(['07:30', '13:00'], $times(['price_max' => 15]));
        $this->assertSame(['13:00'], $times(['price_max' => 0]));
    }
}
