<?php

namespace Database\Seeders;

use App\Models\Campus;
use App\Models\Course;
use App\Models\Ride;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Database\Seeder;

class DemoSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            throw new \RuntimeException('Demo accounts may only be seeded locally or in tests.');
        }

        $admin = User::query()->firstOrCreate(
            ['email' => 'admin@uri.edu.br'],
            [
                'name' => 'Administrador URI Move',
                'password' => 'password',
                'phone' => '(55) 99999-0000',
                'role' => User::ROLE_ADMIN,
                'email_verified_at' => now(),
                'is_active' => true,
            ],
        );

        $teacher = User::query()->firstOrCreate(
            ['email' => 'professor@uri.edu.br'],
            [
                'name' => 'Professora Demo',
                'password' => 'password',
                'phone' => '(55) 98888-0000',
                'role' => User::ROLE_TEACHER,
                'email_verified_at' => now(),
                'is_active' => true,
            ],
        );

        $campus = Campus::where('city', 'Cerro Largo')->first();
        $course = $campus ? Course::where('campus_id', $campus->id)->first() : null;

        $drivers = [
            ['name' => 'João Pedro', 'email' => 'joao.pedro@uri.edu.br', 'phone' => '(55) 98111-2233', 'ra' => '2301001'],
            ['name' => 'Ana Souza', 'email' => 'ana.souza@uri.edu.br', 'phone' => '(55) 98222-3344', 'ra' => '2301002'],
        ];

        $driverUsers = [];
        foreach ($drivers as $driver) {
            $driverUsers[] = User::query()->firstOrCreate(
                ['email' => $driver['email']],
                [
                    ...$driver,
                    'password' => 'password',
                    'role' => User::ROLE_STUDENT,
                    'campus_id' => $campus?->id,
                    'course_id' => $course?->id,
                    'email_verified_at' => now(),
                    'is_active' => true,
                    'rating_avg' => 4.9,
                    'rating_count' => 12,
                ],
            );
        }

        foreach ($driverUsers as $index => $driver) {
            Vehicle::query()->firstOrCreate(
                ['user_id' => $driver->id],
                [
                    'brand' => 'Volkswagen',
                    'model' => 'Gol',
                    'color' => 'Prata',
                    'plate' => $index === 0 ? 'ABC1D23' : 'XYZ7B89',
                    'year' => 2015,
                    'seats' => 4,
                    'is_active' => true,
                ],
            );
        }

        $driver = $driverUsers[0];
        $vehicle = $driver->vehicles()->first();

        Ride::query()->firstOrCreate(
            [
                'driver_id' => $driver->id,
                'origin' => 'Cerro Largo',
                'destination' => 'Santo Ângelo',
                'departure_date' => now()->addDays(2)->toDateString(),
                'departure_time' => '18:00',
            ],
            [
                'vehicle_id' => $vehicle?->id,
                'total_seats' => 4,
                'available_seats' => 3,
                'price' => 15.00,
                'status' => Ride::STATUS_SCHEDULED,
                'notes' => 'Saída em frente à praça central. Só estudantes da URI.',
                'is_recurring' => false,
            ],
        );

        Ride::query()->firstOrCreate(
            [
                'driver_id' => $driver->id,
                'origin' => 'Santo Ângelo',
                'destination' => 'Cerro Largo',
                'departure_date' => now()->addDays(2)->toDateString(),
                'departure_time' => '07:00',
            ],
            [
                'vehicle_id' => $vehicle?->id,
                'total_seats' => 4,
                'available_seats' => 4,
                'price' => 15.00,
                'status' => Ride::STATUS_SCHEDULED,
                'notes' => 'Retorno após aulas.',
                'is_recurring' => true,
            ],
        );

        $this->command?->info('Usuários demo criados. Senha padrão: password');
    }
}
