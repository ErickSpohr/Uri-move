<?php

namespace Database\Seeders;

use App\Models\Campus;
use Illuminate\Database\Seeder;

class CampusSeeder extends Seeder
{
    public function run(): void
    {
        $campuses = [
            ['name' => 'URI Cerro Largo', 'city' => 'Cerro Largo', 'uf' => 'RS'],
            ['name' => 'URI Santo Ângelo', 'city' => 'Santo Ângelo', 'uf' => 'RS'],
            ['name' => 'URI São Luiz Gonzaga', 'city' => 'São Luiz Gonzaga', 'uf' => 'RS'],
            ['name' => 'URI Frederico Westphalen', 'city' => 'Frederico Westphalen', 'uf' => 'RS'],
            ['name' => 'URI Erechim', 'city' => 'Erechim', 'uf' => 'RS'],
            ['name' => 'URI Santiago', 'city' => 'Santiago', 'uf' => 'RS'],
        ];

        foreach ($campuses as $campus) {
            Campus::query()->updateOrCreate(
                ['name' => $campus['name']],
                $campus,
            );
        }
    }
}
