<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            CampusSeeder::class,
            CourseSeeder::class,
        ]);

        if (app()->environment(['local', 'testing'])) {
            $this->call(DemoSeeder::class);
        }
    }
}
