<?php

namespace Database\Factories;

use App\Models\Rating;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Rating>
 */
class RatingFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'ride_id' => Ride::factory(),
            'rater_id' => User::factory(),
            'rated_id' => User::factory(),
            'score' => fake()->numberBetween(1, 5),
            'punctuality' => null,
            'communication' => null,
            'safety' => null,
            'driving' => null,
            'behavior' => null,
            'comment' => null,
        ];
    }
}
