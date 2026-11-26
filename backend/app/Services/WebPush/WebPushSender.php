<?php

namespace App\Services\WebPush;

use App\Models\PushSubscription;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Envio de Web Push (RFC 8030) com VAPID. O par de chaves VAPID é gerado na primeira
 * utilização e persistido em app_settings, dispensando configuração manual.
 */
class WebPushSender
{
    private const SETTING_KEY = 'webpush_vapid';

    private const TTL_SECONDS = 86400;

    /**
     * @return array{private_pem: string, public: string}
     */
    public function vapidKeys(): array
    {
        return Cache::rememberForever(self::SETTING_KEY, function () {
            $stored = DB::table('app_settings')->where('key', self::SETTING_KEY)->value('value');

            if ($stored === null) {
                $pair = WebPushCrypto::generateKeyPair();
                DB::table('app_settings')->insertOrIgnore([
                    'key' => self::SETTING_KEY,
                    'value' => json_encode([
                        'private_pem' => $pair['private_pem'],
                        'public' => WebPushCrypto::base64UrlEncode($pair['public']),
                    ]),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                // Releitura: em corrida entre processos, prevalece o primeiro registro gravado.
                $stored = DB::table('app_settings')->where('key', self::SETTING_KEY)->value('value');
            }

            $data = json_decode($stored, true);

            return [
                'private_pem' => $data['private_pem'],
                'public' => WebPushCrypto::base64UrlDecode($data['public']),
            ];
        });
    }

    public function publicKey(): string
    {
        return WebPushCrypto::base64UrlEncode($this->vapidKeys()['public']);
    }

    /**
     * Envia a todos os navegadores inscritos do usuário. Inscrições expiradas (404/410) são removidas.
     *
     * @param  array<string, mixed>  $payload
     */
    public function sendToUser(User $user, array $payload): void
    {
        $subscriptions = PushSubscription::query()->where('user_id', $user->id)->get();

        if ($subscriptions->isEmpty()) {
            return;
        }

        $keys = $this->vapidKeys();
        $body = json_encode($payload, JSON_UNESCAPED_UNICODE);
        $subject = 'mailto:'.(config('mail.from.address') ?: 'suporte@urimove.app');

        foreach ($subscriptions as $subscription) {
            try {
                $encrypted = WebPushCrypto::encrypt(
                    $body,
                    WebPushCrypto::base64UrlDecode($subscription->p256dh),
                    WebPushCrypto::base64UrlDecode($subscription->auth),
                );

                $response = Http::timeout(5)
                    ->withHeaders([
                        'Authorization' => WebPushCrypto::vapidAuthorization($subscription->endpoint, $subject, $keys['private_pem'], $keys['public']),
                        'Content-Encoding' => 'aes128gcm',
                        'TTL' => (string) self::TTL_SECONDS,
                        'Urgency' => 'normal',
                    ])
                    ->withBody($encrypted, 'application/octet-stream')
                    ->post($subscription->endpoint);

                if (in_array($response->status(), [404, 410], true)) {
                    $subscription->delete();
                } elseif ($response->failed()) {
                    Log::warning('Web Push rejeitado', ['status' => $response->status(), 'subscription' => $subscription->id]);
                }
            } catch (Throwable $e) {
                Log::warning('Falha no envio de Web Push', ['error' => $e->getMessage(), 'subscription' => $subscription->id]);
            }
        }
    }
}
