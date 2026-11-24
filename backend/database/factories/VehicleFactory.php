<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Vehicle>
 */
class VehicleFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'brand' => fake()->randomElement(['Volkswagen', 'Fiat', 'Chevrolet', 'Renault']),
            'model' => fake()->word(),
            'color' => fake()->colorName(),
            'plate' => strtoupper(fake()->unique()->regexify('[A-Z]{3}[0-9][A-Z0-9][0-9]{2}')),
            'year' => fake()->numberBetween(2005, 2024),
            'seats' => 4,
            'is_active' => true,
        ];
    }
}
