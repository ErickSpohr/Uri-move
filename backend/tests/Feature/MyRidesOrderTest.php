<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MyRidesOrderTest extends TestCase
{
    use RefreshDatabase;

    public function test_most_recently_published_rides_come_first(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $ids = [];
        foreach (['2026-12-10', '2026-12-05', '2026-12-08'] as $i => $date) {
            Carbon::setTestNow(Carbon::parse('2026-12-01 10:00')->addMinutes($i));
            $ids[] = $this->postJson('/api/v1/rides', [
                'origin' => 'Cerro Largo', 'destination' => 'URI', 'departure_date' => $date,
                'departure_time' => '07:30', 'total_seats' => 3,
            ])->assertCreated()->json('ride.id');
        }

        $this->assertSame(array_reverse($ids), collect($this->getJson('/api/v1/me/rides')->json('data'))->pluck('id')->all());
    }
}
