<?php

namespace Database\Factories;

use App\Models\Ride;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Ride>
 */
class RideFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $seats = fake()->numberBetween(1, 4);

        return [
            'driver_id' => User::factory(),
            'vehicle_id' => Vehicle::factory(),
            'origin' => 'Cerro Largo',
            'destination' => 'Santo Ângelo',
            'departure_date' => fake()->dateTimeBetween('+1 day', '+30 days')->format('Y-m-d'),
            'departure_time' => fake()->time('H:i'),
            'total_seats' => $seats,
            'available_seats' => $seats,
            'price' => fake()->randomFloat(2, 5, 50),
            'status' => Ride::STATUS_SCHEDULED,
            'notes' => null,
            'is_recurring' => false,
        ];
    }

    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => Ride::STATUS_COMPLETED,
        ]);
    }
}
