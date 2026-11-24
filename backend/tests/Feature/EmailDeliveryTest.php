<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class EmailDeliveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_resend_delivers_the_persisted_code_to_the_user_via_brevo(): void
    {
        $user = User::factory()->unverified()->create();
        config(['mail.default' => 'brevo', 'services.brevo.key' => 'test-key',
            'mail.from.address' => 'sender@example.com', 'mail.from.name' => 'URI Move']);
        Http::preventStrayRequests();
        Http::fake(['https://api.brevo.com/v3/smtp/email' => Http::response(['messageId' => 'test-message'], 201)]);

        $response = $this->postJson('/api/v1/auth/resend-code', ['email' => $user->email]);

        $response->assertOk();
        $record = $user->emailVerifications()->sole();
        Http::assertSent(fn (Request $request): bool => $request->hasHeader('api-key', 'test-key')
            && $request['to'] === [['email' => $user->email]]
            && $request['sender']['email'] === 'sender@example.com'
            && str_contains($request['textContent'], $record->code));
        $this->assertNull($user->fresh()->email_verified_at);
    }

    public function test_provider_failure_returns_422_and_discards_the_unsent_code(): void
    {
        $user = User::factory()->unverified()->create();
        config(['mail.default' => 'brevo', 'services.brevo.key' => 'test-key']);
        Http::preventStrayRequests();
        Http::fake(['https://api.brevo.com/v3/smtp/email' => Http::response(['message' => 'API key rejected'], 401)]);

        $response = $this->postJson('/api/v1/auth/resend-code', ['email' => $user->email]);

        $response->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertDatabaseMissing('email_verifications', ['user_id' => $user->id]);
        Http::assertSentCount(1);
    }

    public function test_missing_provider_key_returns_422_without_attempting_delivery(): void
    {
        $user = User::factory()->unverified()->create();
        config(['mail.default' => 'brevo', 'services.brevo.key' => null]);
        Http::preventStrayRequests();

        $response = $this->postJson('/api/v1/auth/resend-code', ['email' => $user->email]);

        $response->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertDatabaseMissing('email_verifications', ['user_id' => $user->id]);
        Http::assertNothingSent();
    }
}
