<?php

namespace Tests\Feature;

use App\Models\Block;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use App\Services\VerificationEmailSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class ReviewFixesTest extends TestCase
{
    use RefreshDatabase;

    private function request(Ride $ride, User $passenger, string $status): RideRequest
    {
        return RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => $status,
            'seats_requested' => 1,
        ]);
    }

    public function test_ride_search_query_count_does_not_grow_with_results(): void
    {
        $passenger = User::factory()->create();
        Ride::factory()->count(3)->create(['available_seats' => 3, 'total_seats' => 3]);
        Sanctum::actingAs($passenger);

        DB::enableQueryLog();
        $this->getJson('/api/v1/rides')->assertOk()->assertJsonCount(3, 'data');
        $fewRides = count(DB::getQueryLog());

        Ride::factory()->count(9)->create(['available_seats' => 3, 'total_seats' => 3]);
        DB::flushQueryLog();
        $this->getJson('/api/v1/rides')->assertOk()->assertJsonCount(12, 'data');
        $manyRides = count(DB::getQueryLog());

        $this->assertSame($fewRides, $manyRides);
    }

    public function test_my_request_status_reflects_latest_request(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        $this->request($ride, $passenger, RideRequest::STATUS_CANCELLED);
        $latest = $this->request($ride, $passenger, RideRequest::STATUS_PENDING);

        Sanctum::actingAs($passenger);
        $this->getJson("/api/v1/rides/{$ride->id}")
            ->assertOk()
            ->assertJsonPath('data.my_request_status', 'pending')
            ->assertJsonPath('data.my_request_id', $latest->id);
        $this->getJson('/api/v1/rides')->assertOk()->assertJsonPath('data.0.my_request_status', 'pending');
    }

    public function test_joined_rides_exclude_cancelled_participation(): void
    {
        $passenger = User::factory()->create();
        $kept = Ride::factory()->create();
        $left = Ride::factory()->create();
        RidePassenger::create(['ride_id' => $kept->id, 'passenger_id' => $passenger->id, 'status' => 'confirmed']);
        RidePassenger::create(['ride_id' => $left->id, 'passenger_id' => $passenger->id, 'status' => 'cancelled']);

        Sanctum::actingAs($passenger);
        $this->getJson('/api/v1/me/rides/joined')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $kept->id);
    }

    public function test_passenger_cannot_release_confirmed_seat_after_ride_started(): void
    {
        $ride = Ride::factory()->create(['status' => Ride::STATUS_ACTIVE, 'total_seats' => 3, 'available_seats' => 2]);
        $passenger = User::factory()->create();
        $rideRequest = $this->request($ride, $passenger, RideRequest::STATUS_ACCEPTED);
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $passenger->id, 'status' => 'confirmed']);

        Sanctum::actingAs($passenger);
        $this->deleteJson("/api/v1/rides/{$ride->id}/requests/{$rideRequest->id}")->assertUnprocessable();

        $this->assertSame(2, $ride->fresh()->available_seats);
        $this->assertSame('confirmed', RidePassenger::first()->status);
    }

    public function test_cancelling_ride_closes_requests_and_notifies_passengers(): void
    {
        $ride = Ride::factory()->create(['total_seats' => 3, 'available_seats' => 2]);
        $confirmed = User::factory()->create();
        $pending = User::factory()->create();
        $this->request($ride, $confirmed, RideRequest::STATUS_ACCEPTED);
        $this->request($ride, $pending, RideRequest::STATUS_PENDING);
        RidePassenger::create(['ride_id' => $ride->id, 'passenger_id' => $confirmed->id, 'status' => 'confirmed']);

        Sanctum::actingAs($ride->driver);
        $this->postJson("/api/v1/rides/{$ride->id}/cancel")->assertOk();

        $this->assertSame(0, RideRequest::whereIn('status', ['pending', 'accepted'])->count());
        $this->assertSame('cancelled', RidePassenger::first()->status);
        foreach ([$confirmed, $pending] as $passenger) {
            $this->assertDatabaseHas('notifications', ['user_id' => $passenger->id, 'type' => 'ride_cancelled']);
        }
    }

    public function test_guest_can_search_rides(): void
    {
        Ride::factory()->create();

        $this->getJson('/api/v1/rides')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.my_request_status', null);
    }

    public function test_invalid_search_filters_return_validation_error(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/rides?date=amanha')->assertUnprocessable()->assertJsonValidationErrors('date');
        $this->getJson('/api/v1/rides?from_time=25h')->assertUnprocessable()->assertJsonValidationErrors('from_time');
    }

    public function test_register_is_rolled_back_when_code_email_fails(): void
    {
        $this->mock(VerificationEmailSender::class)
            ->shouldReceive('send')
            ->andThrow(new RuntimeException('Brevo indisponível'));

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Aluno Teste',
            'email' => 'falha.envio@uri.edu.br',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertUnprocessable();

        $this->assertDatabaseMissing('users', ['email' => 'falha.envio@uri.edu.br']);
    }

    public function test_guest_without_json_accept_header_gets_401(): void
    {
        $this->get('/api/v1/notifications')->assertUnauthorized();
    }

    public function test_other_users_contact_data_is_hidden(): void
    {
        $ride = Ride::factory()->create();
        $ride->driver->update(['phone' => '55999990000']);
        $viewer = User::factory()->create(['phone' => '55988887777']);

        Sanctum::actingAs($viewer);
        $driver = $this->getJson("/api/v1/rides/{$ride->id}")->assertOk()->json('data.driver');
        $this->assertArrayNotHasKey('email', $driver);
        $this->assertArrayNotHasKey('phone', $driver);

        $this->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.email', $viewer->email)
            ->assertJsonPath('data.phone', '55988887777');
    }

    public function test_block_hides_rides_and_prevents_requests(): void
    {
        $ride = Ride::factory()->create();
        $passenger = User::factory()->create();
        Block::create(['blocker_id' => $ride->driver_id, 'blocked_id' => $passenger->id]);

        Sanctum::actingAs($passenger);
        $this->getJson('/api/v1/rides')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/rides/{$ride->id}/requests")->assertForbidden();
    }
}
