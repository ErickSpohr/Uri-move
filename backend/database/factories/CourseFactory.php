<?php

namespace Database\Factories;

use App\Models\Campus;
use App\Models\Course;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Course>
 */
class CourseFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'campus_id' => Campus::factory(),
            'name' => fake()->words(2, true),
            'shift' => fake()->randomElement(['manhã', 'tarde', 'noite']),
            'is_active' => true,
        ];
    }
}
