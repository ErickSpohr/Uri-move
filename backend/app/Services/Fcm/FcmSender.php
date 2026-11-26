<?php

namespace App\Services\Fcm;

use App\Models\DeviceToken;
use App\Models\User;
use App\Services\WebPush\WebPushCrypto;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

/**
 * Envio de notificações para o app Android pela API HTTP v1 do Firebase Cloud Messaging.
 * Autenticação: JWT RS256 assinado com a chave da conta de serviço (env FIREBASE_CREDENTIALS)
 * trocado por um access token OAuth 2.0, mantido em cache até perto de expirar.
 */
class FcmSender
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    /**
     * @return array{project_id: string, client_email: string, private_key: string}|null
     */
    public function credentials(): ?array
    {
        $raw = config('urimove.firebase_credentials');
        if (! is_string($raw) || trim($raw) === '') {
            return null;
        }

        // Aceita o JSON puro ou codificado em base64.
        $json = json_decode($raw, true) ?? json_decode((string) base64_decode($raw, true), true);
        if (! is_array($json) || ! isset($json['project_id'], $json['client_email'], $json['private_key'])) {
            Log::warning('FIREBASE_CREDENTIALS inválido.');

            return null;
        }

        return $json;
    }

    public function enabled(): bool
    {
        return $this->credentials() !== null;
    }

    /**
     * JWT de asserção (RFC 7523) para obter o access token do Google.
     */
    public static function assertion(string $clientEmail, string $privateKey, int $now): string
    {
        $header = WebPushCrypto::base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = WebPushCrypto::base64UrlEncode(json_encode([
            'iss' => $clientEmail,
            'scope' => self::SCOPE,
            'aud' => self::TOKEN_URL,
            'iat' => $now,
            'exp' => $now + 3600,
        ]));

        if (! openssl_sign("{$header}.{$claims}", $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Falha ao assinar o JWT do Firebase.');
        }

        return "{$header}.{$claims}.".WebPushCrypto::base64UrlEncode($signature);
    }

    private function accessToken(array $credentials): string
    {
        return Cache::remember('fcm_access_token', 3000, function () use ($credentials) {
            $response = Http::asForm()->timeout(8)->post(self::TOKEN_URL, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => self::assertion($credentials['client_email'], $credentials['private_key'], time()),
            ]);

            if ($response->failed() || ! $response->json('access_token')) {
                throw new RuntimeException('Google OAuth recusou a conta de serviço ('.$response->status().').');
            }

            return $response->json('access_token');
        });
    }

    /**
     * Envia para todos os aparelhos do usuário e devolve um relatório (usado no teste do app).
     *
     * @param  array<string, mixed>  $data
     * @return array{configured: bool, devices: int, sent: int, errors: list<string>}
     */
    public function sendToUser(User $user, string $title, ?string $body, array $data = []): array
    {
        $report = ['configured' => false, 'devices' => 0, 'sent' => 0, 'errors' => []];
        $credentials = $this->credentials();
        if ($credentials === null) {
            $report['errors'][] = 'FIREBASE_CREDENTIALS ausente ou inválido no servidor.';

            return $report;
        }
        $report['configured'] = true;

        $tokens = DeviceToken::query()->where('user_id', $user->id)->get();
        $report['devices'] = $tokens->count();
        if ($tokens->isEmpty()) {
            return $report;
        }

        try {
            $accessToken = $this->accessToken($credentials);
        } catch (Throwable $e) {
            Log::warning('FCM indisponível', ['error' => $e->getMessage()]);
            $report['errors'][] = $e->getMessage();

            return $report;
        }

        $url = "https://fcm.googleapis.com/v1/projects/{$credentials['project_id']}/messages:send";
        // A API v1 só aceita strings em "data".
        $data = array_map('strval', array_filter($data, fn ($value) => $value !== null));

        foreach ($tokens as $device) {
            try {
                $response = Http::withToken($accessToken)->timeout(8)->post($url, [
                    'message' => [
                        'token' => $device->token,
                        'notification' => ['title' => $title, 'body' => (string) $body],
                        'data' => (object) $data,
                        'android' => [
                            'priority' => 'HIGH',
                            // Mesma notificação não aparece duplicada na bandeja.
                            'notification' => array_filter([
                                'tag' => isset($data['notification_id']) ? 'n'.$data['notification_id'] : null,
                            ]) ?: new \stdClass,
                        ],
                    ],
                ]);

                // Token não registrado/inválido: o app foi desinstalado ou o token mudou.
                $status = $response->json('error.status');
                if ($response->successful()) {
                    $report['sent']++;
                } else {
                    $report['errors'][] = "FCM {$response->status()}: ".($response->json('error.message') ?? $status ?? 'erro');
                }
                if (in_array($status, ['NOT_FOUND', 'UNREGISTERED'], true)) {
                    $device->delete();
                } elseif ($response->status() === 401) {
                    Cache::forget('fcm_access_token');
                } elseif ($response->failed()) {
                    Log::warning('FCM rejeitou a mensagem', ['status' => $response->status(), 'device' => $device->id]);
                }
            } catch (Throwable $e) {
                Log::warning('Falha no envio FCM', ['error' => $e->getMessage(), 'device' => $device->id]);
                $report['errors'][] = $e->getMessage();
            }
        }

        return $report;
    }
}
