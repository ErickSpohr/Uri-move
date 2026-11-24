<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class PublicRepositorySafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_production_seeding_does_not_create_demo_accounts(): void
    {
        $this->app->detectEnvironment(fn (): string => 'production');

        $this->artisan('db:seed', ['--class' => DatabaseSeeder::class, '--force' => true])->assertSuccessful();

        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('campuses', 6);
    }

    public function test_direct_demo_seeding_is_blocked_in_production(): void
    {
        $this->app->detectEnvironment(fn (): string => 'production');

        try {
            $this->app->make(DemoSeeder::class)->run();
            $this->fail('Production must reject the demo seeder.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Demo accounts may only be seeded locally or in tests.', $exception->getMessage());
        }

        $this->assertDatabaseCount('users', 0);
    }

    public function test_demo_accounts_remain_available_in_local_environment(): void
    {
        $this->app->detectEnvironment(fn (): string => 'local');

        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseHas('users', ['email' => 'admin@uri.edu.br', 'role' => User::ROLE_ADMIN]);
    }
}
