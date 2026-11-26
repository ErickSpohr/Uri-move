<?php

namespace Tests\Feature;

use App\Models\DeviceToken;
use App\Models\User;
use App\Services\Fcm\FcmSender;
use App\Services\NotificationService;
use App\Services\WebPush\WebPushCrypto;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Defer\DeferredCallbackCollection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FcmTest extends TestCase
{
    use RefreshDatabase;

    private string $publicKey;

    protected function setUp(): void
    {
        parent::setUp();
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $privatePem);
        $this->publicKey = openssl_pkey_get_details($key)['key'];
        config(['urimove.firebase_credentials' => json_encode([
            'project_id' => 'uri-move-test',
            'client_email' => 'push@uri-move-test.iam.gserviceaccount.com',
            'private_key' => $privatePem,
        ])]);
        Cache::flush();
    }

    public function test_device_registration_moves_token_between_accounts(): void
    {
        [$a, $b] = User::factory()->count(2)->create();

        Sanctum::actingAs($a);
        $this->postJson('/api/v1/push/devices', ['token' => 'tok-1'])->assertCreated();
        Sanctum::actingAs($b);
        $this->postJson('/api/v1/push/devices', ['token' => 'tok-1'])->assertCreated();
        $this->assertSame($b->id, DeviceToken::sole()->user_id);

        $this->deleteJson('/api/v1/push/devices', ['token' => 'tok-1'])->assertOk();
        $this->assertSame(0, DeviceToken::count());
    }

    public function test_assertion_jwt_is_signed_with_service_account_key(): void
    {
        $credentials = app(FcmSender::class)->credentials();
        $jwt = FcmSender::assertion($credentials['client_email'], $credentials['private_key'], 1_700_000_000);
        [$header, $claims, $signature] = explode('.', $jwt);

        $this->assertSame(1, openssl_verify("{$header}.{$claims}", WebPushCrypto::base64UrlDecode($signature), $this->publicKey, OPENSSL_ALGO_SHA256));
        $decoded = json_decode(WebPushCrypto::base64UrlDecode($claims), true);
        $this->assertSame('https://oauth2.googleapis.com/token', $decoded['aud']);
        $this->assertSame(1_700_003_600, $decoded['exp']);
    }

    public function test_notification_is_sent_to_devices_and_unregistered_token_is_removed(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3599]),
            'fcm.googleapis.com/*' => Http::sequence()
                ->push(['name' => 'projects/uri-move-test/messages/1'])
                ->push(['error' => ['code' => 404, 'status' => 'NOT_FOUND']], 404),
        ]);
        $user = User::factory()->create();
        DeviceToken::create(['user_id' => $user->id, 'token' => 'valid']);
        DeviceToken::create(['user_id' => $user->id, 'token' => 'stale']);

        app(NotificationService::class)->send($user, 'ride_request_received', 'Nova solicitação', 'Ana pediu vaga', null, ['ride_id' => 7]);
        $this->app->make(DeferredCallbackCollection::class)->invoke();

        Http::assertSent(fn ($request) => str_contains($request->url(), 'messages:send')
            && $request->header('Authorization')[0] === 'Bearer ya29.test'
            && $request['message']['token'] === 'valid'
            && $request['message']['notification']['title'] === 'Nova solicitação'
            && ((array) $request['message']['data'])['ride_id'] === '7');
        $this->assertSame(['valid'], DeviceToken::pluck('token')->all());
    }

    public function test_without_credentials_nothing_is_sent(): void
    {
        config(['urimove.firebase_credentials' => null]);
        Http::fake();
        $user = User::factory()->create();
        DeviceToken::create(['user_id' => $user->id, 'token' => 'valid']);

        app(FcmSender::class)->sendToUser($user, 'Título', 'Corpo');

        Http::assertNothingSent();
    }

    public function test_test_endpoint_reports_missing_device(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/push/devices/test')
            ->assertOk()
            ->assertJson(['configured' => true, 'devices' => 0, 'sent' => 0]);
    }

    public function test_private_chat_message_pushes_to_receiver_without_listing_notification(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'ok']),
        ]);
        [$driver, $passenger] = User::factory()->count(2)->create();
        DeviceToken::create(['user_id' => $driver->id, 'token' => 'driver-phone']);

        Sanctum::actingAs($driver);
        $rideId = $this->postJson('/api/v1/rides', [
            'origin' => 'Cerro Largo', 'destination' => 'URI', 'departure_date' => now()->addDay()->toDateString(),
            'departure_time' => '07:30', 'total_seats' => 3,
        ])->json('ride.id');

        Sanctum::actingAs($passenger);
        $this->postJson("/api/v1/rides/{$rideId}/requests", ['pickup_lat' => -28.15, 'pickup_lng' => -54.74])->assertCreated();
        $this->app->make(DeferredCallbackCollection::class)->forget('*');
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'ok']),
        ]);
        $before = $driver->notifications()->count();

        $this->postJson("/api/v1/rides/{$rideId}/messages", ['body' => 'Posso levar mochila?'])->assertCreated();
        $this->app->make(DeferredCallbackCollection::class)->invoke();

        Http::assertSent(fn ($request) => str_contains($request->url(), 'messages:send')
            && $request['message']['token'] === 'driver-phone'
            && $request['message']['notification']['body'] === 'Posso levar mochila?');
        $this->assertSame($before, $driver->notifications()->count());
    }
}
