<?php

namespace Tests\Feature;

use App\Models\EmailVerification;
use App\Models\Ride;
use App\Models\RideRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthRateLimitTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_is_limited_to_five_attempts_per_minute_per_email(): void
    {
        $user = User::factory()->create(['email' => 'limite@uri.edu.br']);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'errada'])
                ->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'errada'])
            ->assertTooManyRequests()
            ->assertJsonPath('message', 'Muitas tentativas de login. Aguarde um minuto e tente novamente.');
    }

    public function test_verify_email_blocks_code_brute_force(): void
    {
        $user = User::factory()->unverified()->create(['email' => 'forca.bruta@uri.edu.br']);
        EmailVerification::create([
            'user_id' => $user->id,
            'code' => '123456',
            'expires_at' => now()->addMinutes(10),
        ]);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postJson('/api/v1/auth/verify-email', ['email' => $user->email, 'code' => '000000'])
                ->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/verify-email', ['email' => $user->email, 'code' => '123456'])
            ->assertTooManyRequests();

        $this->assertNull($user->fresh()->email_verified_at);
    }

    public function test_resend_code_is_limited_per_email(): void
    {
        $user = User::factory()->unverified()->create(['email' => 'reenvio@uri.edu.br']);

        for ($attempt = 1; $attempt <= 3; $attempt++) {
            $this->postJson('/api/v1/auth/resend-code', ['email' => $user->email])->assertOk();
        }

        $this->postJson('/api/v1/auth/resend-code', ['email' => $user->email])->assertTooManyRequests();
        $this->assertSame(3, EmailVerification::where('user_id', $user->id)->count());
    }

    public function test_login_with_unverified_email_does_not_resend_recent_code(): void
    {
        $user = User::factory()->unverified()->create(['password' => 'password123']);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password123'])
            ->assertForbidden()
            ->assertJsonPath('requires_email_verification', true);
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password123'])
            ->assertForbidden()
            ->assertJsonPath('message', 'E-mail ainda não verificado. Use o código enviado recentemente.');

        $this->assertSame(1, EmailVerification::where('user_id', $user->id)->count());
    }

    public function test_already_answered_request_cannot_be_accepted_again(): void
    {
        $ride = Ride::factory()->create(['available_seats' => 1]);
        $rideRequest = RideRequest::create([
            'ride_id' => $ride->id,
            'passenger_id' => User::factory()->create()->id,
            'status' => RideRequest::STATUS_PENDING,
            'seats_requested' => 1,
        ]);

        Sanctum::actingAs($ride->driver);
        $this->patchJson("/api/v1/rides/{$ride->id}/requests/{$rideRequest->id}", ['action' => 'accepted'])->assertOk();
        $this->patchJson("/api/v1/rides/{$ride->id}/requests/{$rideRequest->id}", ['action' => 'accepted'])->assertUnprocessable();

        $this->assertSame(0, $ride->fresh()->available_seats);
    }
}
