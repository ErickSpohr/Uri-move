<?php

namespace Tests\Feature;

use App\Models\Campus;
use App\Models\Course;
use App\Models\EmailVerification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function institutionalPayload(array $overrides = []): array
    {
        $campus = Campus::factory()->create();
        $course = Course::factory()->create(['campus_id' => $campus->id]);

        return array_merge([
            'name' => 'Aluno Teste',
            'email' => 'aluno.teste@uri.edu.br',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'ra' => '2301999',
            'phone' => '(55) 99999-9999',
            'course_id' => $course->id,
            'campus_id' => $campus->id,
        ], $overrides);
    }

    public function test_non_institutional_email_cannot_register(): void
    {
        $response = $this->postJson('/api/v1/auth/register', $this->institutionalPayload([
            'email' => 'aluno.teste@gmail.com',
        ]));

        $response->assertStatus(422)->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', ['email' => 'aluno.teste@gmail.com']);
    }

    public function test_user_can_register_and_verify_with_otp(): void
    {
        $response = $this->postJson('/api/v1/auth/register', $this->institutionalPayload());

        $response->assertCreated();

        $user = User::where('email', 'aluno.teste@uri.edu.br')->firstOrFail();
        $this->assertNull($user->email_verified_at);

        $code = EmailVerification::where('user_id', $user->id)->latest()->firstOrFail()->code;

        $verifyResponse = $this->postJson('/api/v1/auth/verify-email', [
            'email' => $user->email,
            'code' => $code,
        ]);

        $verifyResponse->assertOk()
            ->assertJsonStructure(['token', 'user' => ['id', 'email']]);

        $this->assertNotNull($user->fresh()->email_verified_at);
    }

    public function test_santo_angelo_student_email_can_register(): void
    {
        $email = 'aluno.teste@aluno.santoangelo.uri.br';

        $this->postJson('/api/v1/auth/register', $this->institutionalPayload(['email' => $email]))
            ->assertCreated();

        $this->assertDatabaseHas('users', ['email' => $email]);
    }

    public function test_lookalike_student_domain_is_rejected(): void
    {
        $email = 'aluno.teste@aluno.santoangelo.uri.br.example.com';

        $this->postJson('/api/v1/auth/register', $this->institutionalPayload(['email' => $email]))
            ->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', ['email' => $email]);
    }

    public function test_unverified_user_cannot_login(): void
    {
        User::factory()->create([
            'email' => 'pendente@uri.edu.br',
            'email_verified_at' => null,
            'password' => 'password123',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'pendente@uri.edu.br',
            'password' => 'password123',
        ]);

        $response->assertForbidden()
            ->assertJsonPath('requires_email_verification', true)
            ->assertJsonPath('user.email', 'pendente@uri.edu.br');
    }

    public function test_verified_user_can_login(): void
    {
        User::factory()->create([
            'email' => 'verificado@uri.edu.br',
            'password' => 'password123',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'verificado@uri.edu.br',
            'password' => 'password123',
        ])->assertOk()->assertJsonStructure(['token', 'user' => ['id', 'email']]);
    }

    public function test_logout_revokes_access_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $this->withHeaders(['Authorization' => 'Bearer '.$token])
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $user->id]);
    }
}
