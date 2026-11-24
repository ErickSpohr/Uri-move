<?php

namespace Database\Seeders;

use App\Models\Campus;
use App\Models\Course;
use Illuminate\Database\Seeder;

class CourseSeeder extends Seeder
{
    private array $coursesByCampus = [
        'URI Cerro Largo' => [
            'Ciência da Computação', 'Agronomia', 'Engenharia Ambiental e Sanitária',
            'Enfermagem', 'Nutrição', 'Administração',
        ],
        'URI Santo Ângelo' => [
            'Direito', 'Psicologia', 'Ciências Biológicas',
            'Engenharia Elétrica', 'Fisioterapia', 'Administração', 'Ciência da Computação',
        ],
        'URI São Luiz Gonzaga' => [
            'Administração', 'Ciências Contábeis', 'Engenharia de Alimentos',
        ],
        'URI Frederico Westphalen' => [
            'Direito', 'Medicina', 'Odontologia', 'Enfermagem',
            'Psicologia', 'Engenharia Civil', 'Administração',
        ],
        'URI Erechim' => [
            'Direito', 'Engenharia Mecânica', 'Pedagogia', 'Serviço Social',
            'Enfermagem', 'Agronomia',
        ],
        'URI Santiago' => [
            'Administração', 'Ciências Contábeis', 'Pedagogia', 'Sistemas de Informação',
        ],
    ];

    public function run(): void
    {
        foreach ($this->coursesByCampus as $campusName => $courses) {
            $campus = Campus::where('name', $campusName)->first();
            if (! $campus) {
                continue;
            }

            foreach ($courses as $courseName) {
                Course::query()->updateOrCreate(
                    ['campus_id' => $campus->id, 'name' => $courseName],
                    ['shift' => null, 'is_active' => true],
                );
            }
        }
    }
}
