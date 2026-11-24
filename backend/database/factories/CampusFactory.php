<?php

namespace Database\Factories;

use App\Models\Campus;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Campus>
 */
class CampusFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => 'URI '.fake()->city(),
            'city' => fake()->city(),
            'uf' => 'RS',
            'is_active' => true,
        ];
    }
}
