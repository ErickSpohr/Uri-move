<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordRecoveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_email_contains_a_working_code_and_does_not_expose_it_in_the_response(): void
    {
        $user = User::factory()->create();
        config(['mail.default' => 'brevo', 'services.brevo.key' => 'test-key']);
        Http::preventStrayRequests();
        Http::fake(['https://api.brevo.com/v3/smtp/email' => Http::response(['messageId' => 'test-message'], 201)]);

        $response = $this->postJson('/api/v1/auth/forgot-password', ['email' => strtoupper($user->email)]);

        $response->assertOk()->assertJsonMissingPath('token');
        Http::assertSent(function ($request) use ($user): bool {
            preg_match('/\n\n([a-f0-9]{64})\n\n/', $request['textContent'], $matches);

            return $request['to'][0]['email'] === $user->email && isset($matches[1]) && Password::tokenExists($user, $matches[1]);
        });
        Http::assertSentCount(1);
    }

    public function test_unknown_email_receives_the_same_message_without_sending_mail(): void
    {
        config(['mail.default' => 'brevo']);
        Http::preventStrayRequests();
        Http::fake(['https://api.brevo.com/v3/smtp/email' => Http::response([], 201)]);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'unknown@uri.edu.br'])
            ->assertOk()->assertJsonPath('message', 'Se este e-mail estiver cadastrado, você receberá um código de recuperação. Confira também a pasta de spam.');

        Http::assertNothingSent();
        $this->assertDatabaseCount('password_reset_tokens', 0);
    }

    public function test_reset_changes_password_verifies_email_revokes_sessions_and_consumes_code(): void
    {
        $user = User::factory()->unverified()->create(['password' => 'previous-password']);
        $user->createToken('old-session');
        $token = Password::createToken($user);
        $payload = ['email' => $user->email, 'token' => $token, 'password' => 'new-password123', 'password_confirmation' => 'new-password123'];

        $this->postJson('/api/v1/auth/reset-password', $payload)->assertOk();

        $this->assertTrue(Hash::check('new-password123', $user->fresh()->password));
        $this->assertNotNull($user->fresh()->email_verified_at);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('password_reset_tokens', 0);
        $this->postJson('/api/v1/auth/reset-password', $payload)->assertUnprocessable()->assertJsonValidationErrors('token');
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'previous-password'])->assertUnauthorized();
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'new-password123'])->assertOk();
    }

    public function test_expired_code_cannot_change_password(): void
    {
        $this->freezeTime();
        $user = User::factory()->create(['password' => 'previous-password']);
        $token = Password::createToken($user);
        $this->travel(61)->minutes();

        $this->postJson('/api/v1/auth/reset-password', ['email' => $user->email, 'token' => $token, 'password' => 'new-password123', 'password_confirmation' => 'new-password123'])
            ->assertUnprocessable()->assertJsonValidationErrors('token');

        $this->assertTrue(Hash::check('previous-password', $user->fresh()->password));
    }

    public function test_code_cannot_reset_another_account(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create(['password' => 'unchanged-password']);
        $token = Password::createToken($owner);

        $this->postJson('/api/v1/auth/reset-password', ['email' => $other->email, 'token' => $token, 'password' => 'new-password123', 'password_confirmation' => 'new-password123'])
            ->assertUnprocessable()->assertJsonValidationErrors('token');

        $this->assertTrue(Hash::check('unchanged-password', $other->fresh()->password));
        $this->assertTrue(Password::tokenExists($owner, $token));
    }

    public function test_failed_delivery_invalidates_the_code_and_hides_provider_errors(): void
    {
        $user = User::factory()->create();
        config(['mail.default' => 'brevo', 'services.brevo.key' => 'test-key']);
        Http::preventStrayRequests();
        Http::fake(['https://api.brevo.com/v3/smtp/email' => Http::response(['message' => 'private-provider-detail'], 500)]);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])
            ->assertUnprocessable()->assertJsonValidationErrors('email')->assertDontSee('private-provider-detail');

        Http::assertSentCount(1);
        $this->assertDatabaseCount('password_reset_tokens', 0);
    }

    public function test_invalid_inputs_cannot_change_password(): void
    {
        $this->postJson('/api/v1/auth/forgot-password', [])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->postJson('/api/v1/auth/forgot-password', ['email' => ['student@uri.edu.br']])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->postJson('/api/v1/auth/reset-password', [])->assertUnprocessable()->assertJsonValidationErrors(['email', 'token', 'password']);
        $this->postJson('/api/v1/auth/reset-password', ['email' => 'student@uri.edu.br', 'token' => str_repeat('a', 64), 'password' => 'short', 'password_confirmation' => 'different'])
            ->assertUnprocessable()->assertJsonValidationErrors('password');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_requesting_codes_is_rate_limited(): void
    {
        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/v1/auth/forgot-password', ['email' => 'unknown@uri.edu.br'])->assertOk();
        }

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'unknown@uri.edu.br'])->assertTooManyRequests();
    }
}
