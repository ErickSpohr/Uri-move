<?php

namespace Tests\Feature;

use App\Models\Campus;
use App\Models\Course;
use App\Models\Report;
use App\Models\Ride;
use App\Models\RidePassenger;
use App\Models\RideRequest;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideFlowTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function makeStudent(array $overrides = []): User
    {
        $campus = Campus::factory()->create();
        $course = Course::factory()->create(['campus_id' => $campus->id]);

        return User::factory()->create(array_merge([
            'campus_id' => $campus->id,
            'course_id' => $course->id,
            'role' => 'student',
            'email' => fake()->unique()->safeEmail(),
        ], $overrides));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function ridePayload(array $overrides = []): array
    {
        return array_merge([
            'origin' => 'Cerro Largo',
            'destination' => 'Santo Ângelo',
            'departure_date' => now()->addDays(2)->format('Y-m-d'),
            'departure_time' => '18:00',
            'total_seats' => 3,
            'price' => 15,
        ], $overrides);
    }

    public function test_driver_cannot_use_another_users_vehicle(): void
    {
        $driver = $this->makeStudent();
        $other = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $other->id]);

        Sanctum::actingAs($driver);

        $this->postJson('/api/v1/rides', $this->ridePayload(['vehicle_id' => $vehicle->id]))
            ->assertForbidden();

        $this->assertDatabaseCount('rides', 0);
    }

    public function test_driver_and_passenger_can_view_ride_details(): void
    {
        $driver = $this->makeStudent();
        $passenger = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
        ]);

        foreach ([$driver, $passenger] as $viewer) {
            Sanctum::actingAs($viewer);

            $this->getJson("/api/v1/rides/{$ride->id}")
                ->assertOk()
                ->assertJsonPath('data.id', $ride->id)
                ->assertJsonPath('data.driver.id', $driver->id)
                ->assertJsonPath('data.vehicle.id', $vehicle->id);
        }
    }

    public function test_driver_can_publish_ride_with_own_vehicle(): void
    {
        $driver = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);

        Sanctum::actingAs($driver);

        $this->postJson('/api/v1/rides', $this->ridePayload(['vehicle_id' => $vehicle->id]))
            ->assertCreated()
            ->assertJsonPath('ride.driver.id', $driver->id);

        $this->assertDatabaseHas('rides', [
            'driver_id' => $driver->id,
            'total_seats' => 3,
            'available_seats' => 3,
        ]);
    }

    public function test_passenger_requests_and_driver_accepts(): void
    {
        $driver = $this->makeStudent();
        $passenger = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
            'total_seats' => 3,
            'available_seats' => 3,
        ]);

        Sanctum::actingAs($passenger);
        $requestResponse = $this->postJson("/api/v1/rides/{$ride->id}/requests", [
            'seats_requested' => 1,
        ]);
        $requestResponse->assertCreated();
        $requestId = $requestResponse->json('request.id');

        Sanctum::actingAs($driver);
        $this->patchJson("/api/v1/rides/{$ride->id}/requests/{$requestId}", [
            'action' => 'accepted',
        ])->assertOk();

        $this->assertDatabaseHas('rides', ['id' => $ride->id, 'available_seats' => 2]);
        $this->assertDatabaseHas('ride_passengers', [
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RidePassenger::STATUS_CONFIRMED,
        ]);
    }

    public function test_cancelling_a_pending_request_does_not_add_seats(): void
    {
        $driver = $this->makeStudent();
        $passenger = $this->makeStudent();
        $ride = Ride::factory()->create([
            'driver_id' => $driver->id,
            'total_seats' => 3,
            'available_seats' => 3,
        ]);
        $rideRequest = RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 2,
        ]);

        Sanctum::actingAs($passenger);

        $this->deleteJson("/api/v1/rides/{$ride->id}/requests/{$rideRequest->id}")
            ->assertOk();

        $this->assertSame(3, $ride->fresh()->available_seats);
        $this->assertSame(RideRequest::STATUS_CANCELLED, $rideRequest->fresh()->status);
    }

    public function test_completing_ride_increments_driver_ride_count(): void
    {
        $driver = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
        ]);

        Sanctum::actingAs($driver);

        $this->postJson("/api/v1/rides/{$ride->id}/complete")
            ->assertOk()
            ->assertJsonPath('ride.status', Ride::STATUS_COMPLETED);

        $this->assertSame(1, (int) $driver->fresh()->ride_count);
    }

    public function test_passenger_can_rate_driver_after_completion(): void
    {
        $driver = $this->makeStudent();
        $passenger = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->completed()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
            'total_seats' => 2,
            'available_seats' => 1,
        ]);

        RidePassenger::create([
            'ride_id' => $ride->id,
            'passenger_id' => $passenger->id,
            'status' => RidePassenger::STATUS_COMPLETED,
        ]);

        Sanctum::actingAs($passenger);

        $this->postJson('/api/v1/ratings', [
            'ride_id' => $ride->id,
            'rated_id' => $driver->id,
            'score' => 5,
            'comment' => 'Excelente motorista',
        ])->assertCreated();

        $this->assertDatabaseHas('ratings', [
            'ride_id' => $ride->id,
            'rater_id' => $passenger->id,
            'rated_id' => $driver->id,
            'score' => 5,
        ]);

        $driver->refresh();
        $this->assertSame(1, (int) $driver->rating_count);
        $this->assertEquals(5.0, (float) $driver->rating_avg);
    }

    public function test_rating_requires_participation(): void
    {
        $driver = $this->makeStudent();
        $stranger = $this->makeStudent();
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->completed()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
        ]);

        Sanctum::actingAs($stranger);

        $this->postJson('/api/v1/ratings', [
            'ride_id' => $ride->id,
            'rated_id' => $driver->id,
            'score' => 5,
        ])->assertForbidden();

        $this->assertDatabaseCount('ratings', 0);
    }

    public function test_report_and_admin_flow(): void
    {
        $driver = $this->makeStudent();
        $passenger = $this->makeStudent();
        $admin = $this->makeStudent(['role' => 'admin']);
        $vehicle = Vehicle::factory()->create(['user_id' => $driver->id]);
        $ride = Ride::factory()->create([
            'driver_id' => $driver->id,
            'vehicle_id' => $vehicle->id,
        ]);

        Sanctum::actingAs($passenger);
        $reportResponse = $this->postJson('/api/v1/reports', [
            'reported_id' => $driver->id,
            'ride_id' => $ride->id,
            'reason' => 'misconduct',
            'details' => 'Atraso sem aviso.',
        ]);
        $reportResponse->assertCreated()->assertJsonPath('report.status', Report::STATUS_OPEN);
        $reportId = $reportResponse->json('report.id');

        Sanctum::actingAs($passenger);
        $this->getJson('/api/v1/admin/reports')->assertForbidden();

        Sanctum::actingAs($admin);
        $this->getJson('/api/v1/admin/reports')->assertOk();

        $this->patchJson("/api/v1/admin/reports/{$reportId}/status", [
            'status' => Report::STATUS_REVIEWING,
        ])->assertOk()->assertJsonPath('report.status', Report::STATUS_REVIEWING);

        $this->assertDatabaseHas('reports', ['id' => $reportId, 'status' => Report::STATUS_REVIEWING]);
    }
}
