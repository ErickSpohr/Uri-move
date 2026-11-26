<?php

namespace Tests\Feature;

use App\Models\PushSubscription;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\WebPush\WebPushCrypto;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Defer\DeferredCallbackCollection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class WebPushTest extends TestCase
{
    use RefreshDatabase;

    private function browserKeys(): array
    {
        $pair = WebPushCrypto::generateKeyPair();

        return [
            'p256dh' => WebPushCrypto::base64UrlEncode($pair['public']),
            'auth' => WebPushCrypto::base64UrlEncode(random_bytes(16)),
        ];
    }

    public function test_public_key_is_generated_once_and_persisted(): void
    {
        Cache::flush();
        $user = User::factory()->create();

        $first = $this->actingAs($user)->getJson('/api/v1/push/public-key')->assertOk()->json('public_key');
        Cache::flush();
        $second = $this->actingAs($user)->getJson('/api/v1/push/public-key')->json('public_key');

        $this->assertSame($first, $second);
        $this->assertSame(65, strlen(WebPushCrypto::base64UrlDecode($first)));
    }

    public function test_subscribe_moves_endpoint_between_accounts_and_unsubscribe(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $body = ['endpoint' => 'https://fcm.googleapis.com/fcm/send/xyz', 'keys' => $this->browserKeys()];

        $this->actingAs($a)->postJson('/api/v1/push/subscriptions', $body)->assertCreated();
        $this->actingAs($b)->postJson('/api/v1/push/subscriptions', $body)->assertCreated();

        $this->assertSame(1, PushSubscription::count());
        $this->assertSame($b->id, PushSubscription::first()->user_id);

        $this->actingAs($b)->deleteJson('/api/v1/push/subscriptions', ['endpoint' => $body['endpoint']])->assertOk();
        $this->assertSame(0, PushSubscription::count());
    }

    public function test_rejects_non_https_endpoint(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/push/subscriptions', [
            'endpoint' => 'http://169.254.169.254/latest',
            'keys' => $this->browserKeys(),
        ])->assertUnprocessable();
    }

    public function test_notification_sends_push_and_drops_expired_subscription(): void
    {
        Http::fake([
            'push.example.com/ok' => Http::response('', 201),
            'push.example.com/gone' => Http::response('', 410),
        ]);

        $user = User::factory()->create();
        foreach (['ok', 'gone'] as $path) {
            $keys = $this->browserKeys();
            PushSubscription::create([
                'user_id' => $user->id,
                'endpoint' => "https://push.example.com/{$path}",
                'endpoint_hash' => PushSubscription::hashEndpoint("https://push.example.com/{$path}"),
                'p256dh' => $keys['p256dh'],
                'auth' => $keys['auth'],
            ]);
        }

        app(NotificationService::class)->send($user, 'test', 'Título', 'Corpo');
        $this->app->make(DeferredCallbackCollection::class)->invoke();

        Http::assertSent(fn ($request) => $request->url() === 'https://push.example.com/ok'
            && $request->header('Content-Encoding')[0] === 'aes128gcm'
            && str_starts_with($request->header('Authorization')[0], 'vapid t='));
        $this->assertSame(['https://push.example.com/ok'], PushSubscription::pluck('endpoint')->all());
    }
}
