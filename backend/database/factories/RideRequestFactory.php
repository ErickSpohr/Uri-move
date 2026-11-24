<?php

namespace Database\Factories;

use App\Models\Ride;
use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<RideRequest>
 */
class RideRequestFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'ride_id' => Ride::factory(),
            'passenger_id' => User::factory(),
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 1,
            'message' => null,
            'responded_at' => null,
        ];
    }
}
