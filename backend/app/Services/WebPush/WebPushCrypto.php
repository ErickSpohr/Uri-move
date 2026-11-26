<?php

namespace App\Services\WebPush;

use RuntimeException;

/**
 * Criptografia do Web Push sem dependências externas (OpenSSL do PHP):
 * - cifragem do conteúdo "aes128gcm" (RFC 8291 + RFC 8188);
 * - assinatura VAPID ES256 (RFC 8292).
 * Chaves públicas P-256 trafegam no formato "não comprimido" (0x04 || X || Y, 65 bytes).
 */
class WebPushCrypto
{
    private const SPKI_P256_PREFIX = '3059301306072a8648ce3d020106082a8648ce3d030107034200';

    private const RECORD_SIZE = 4096;

    public static function base64UrlEncode(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    public static function base64UrlDecode(string $value): string
    {
        $decoded = base64_decode(strtr($value, '-_', '+/'), true);

        if ($decoded === false) {
            throw new RuntimeException('Valor base64url inválido.');
        }

        return $decoded;
    }

    /**
     * Gera um par de chaves P-256.
     *
     * @return array{private_pem: string, public: string} public em formato não comprimido (65 bytes)
     */
    public static function generateKeyPair(): array
    {
        $key = openssl_pkey_new(['curve_name' => 'prime256v1', 'private_key_type' => OPENSSL_KEYTYPE_EC]);

        if ($key === false || ! openssl_pkey_export($key, $privatePem)) {
            throw new RuntimeException('Falha ao gerar chave EC P-256.');
        }

        return ['private_pem' => $privatePem, 'public' => self::publicKeyFromPrivate($key)];
    }

    /**
     * Chave privada PEM (SEC1) a partir do escalar d (32 bytes) e da chave pública (65 bytes).
     */
    public static function privatePemFromRaw(string $d, string $publicRaw): string
    {
        $der = hex2bin('30770201010420').$d
            .hex2bin('a00a06082a8648ce3d030107a144034200').$publicRaw;

        return "-----BEGIN EC PRIVATE KEY-----\n".chunk_split(base64_encode($der), 64, "\n")."-----END EC PRIVATE KEY-----\n";
    }

    public static function publicPemFromRaw(string $publicRaw): string
    {
        if (strlen($publicRaw) !== 65 || $publicRaw[0] !== "\x04") {
            throw new RuntimeException('Chave pública P-256 inválida.');
        }

        $der = hex2bin(self::SPKI_P256_PREFIX).$publicRaw;

        return "-----BEGIN PUBLIC KEY-----\n".chunk_split(base64_encode($der), 64, "\n")."-----END PUBLIC KEY-----\n";
    }

    public static function publicKeyFromPrivate(mixed $privateKey): string
    {
        $key = is_string($privateKey) ? openssl_pkey_get_private($privateKey) : $privateKey;
        $details = $key ? openssl_pkey_get_details($key) : false;

        if (! $details || ! isset($details['ec']['x'], $details['ec']['y'])) {
            throw new RuntimeException('Chave EC inválida.');
        }

        return "\x04".str_pad($details['ec']['x'], 32, "\0", STR_PAD_LEFT)
            .str_pad($details['ec']['y'], 32, "\0", STR_PAD_LEFT);
    }

    /**
     * Cifra o conteúdo para um navegador (corpo da requisição ao serviço de push).
     *
     * @param  string  $userAgentPublic  chave p256dh do navegador (65 bytes)
     * @param  string  $authSecret  segredo auth do navegador (16 bytes)
     * @param  array{private_pem: string, public: string}|null  $ephemeral  par efêmero do servidor (testes)
     * @param  string|null  $salt  16 bytes aleatórios (testes)
     */
    public static function encrypt(
        string $plaintext,
        string $userAgentPublic,
        string $authSecret,
        ?array $ephemeral = null,
        ?string $salt = null,
    ): string {
        $ephemeral ??= self::generateKeyPair();
        $salt ??= random_bytes(16);

        $privateKey = openssl_pkey_get_private($ephemeral['private_pem']);
        $peerKey = openssl_pkey_get_public(self::publicPemFromRaw($userAgentPublic));
        $ecdhSecret = ($privateKey && $peerKey) ? openssl_pkey_derive($peerKey, $privateKey, 32) : false;

        if ($ecdhSecret === false) {
            throw new RuntimeException('Falha no acordo de chaves ECDH.');
        }

        // RFC 8291 §3.3: IKM = HKDF(auth_secret, ecdh_secret, "WebPush: info" || 0x00 || ua_public || as_public, 32)
        $keyInfo = "WebPush: info\0".$userAgentPublic.$ephemeral['public'];
        $ikm = hash_hkdf('sha256', $ecdhSecret, 32, $keyInfo, $authSecret);

        // RFC 8188 §2.2–2.3: chave de conteúdo e nonce derivados do salt.
        $cek = hash_hkdf('sha256', $ikm, 16, "Content-Encoding: aes128gcm\0", $salt);
        $nonce = hash_hkdf('sha256', $ikm, 12, "Content-Encoding: nonce\0", $salt);

        // Registro único: conteúdo seguido do delimitador 0x02 (último registro).
        $ciphertext = openssl_encrypt($plaintext."\x02", 'aes-128-gcm', $cek, OPENSSL_RAW_DATA, $nonce, $tag);

        if ($ciphertext === false) {
            throw new RuntimeException('Falha ao cifrar a mensagem.');
        }

        $header = $salt.pack('N', self::RECORD_SIZE).chr(strlen($ephemeral['public'])).$ephemeral['public'];

        return $header.$ciphertext.$tag;
    }

    /**
     * Cabeçalho Authorization VAPID (RFC 8292) para o endpoint informado.
     */
    public static function vapidAuthorization(string $endpoint, string $subject, string $privatePem, string $publicRaw, int $ttlSeconds = 43200): string
    {
        $parts = parse_url($endpoint);
        $audience = $parts['scheme'].'://'.$parts['host'].(isset($parts['port']) ? ':'.$parts['port'] : '');

        $header = self::base64UrlEncode(json_encode(['typ' => 'JWT', 'alg' => 'ES256']));
        $claims = self::base64UrlEncode(json_encode([
            'aud' => $audience,
            'exp' => time() + $ttlSeconds,
            'sub' => $subject,
        ]));
        $signingInput = $header.'.'.$claims;

        if (! openssl_sign($signingInput, $derSignature, $privatePem, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Falha ao assinar o token VAPID.');
        }

        $jwt = $signingInput.'.'.self::base64UrlEncode(self::derSignatureToRaw($derSignature));

        return 'vapid t='.$jwt.', k='.self::base64UrlEncode($publicRaw);
    }

    /**
     * Converte assinatura ECDSA DER (SEQUENCE{r, s}) para r || s com 32 bytes cada (JWS ES256).
     */
    public static function derSignatureToRaw(string $der): string
    {
        $offset = 2;
        if ((ord($der[1]) & 0x80) !== 0) {
            $offset += ord($der[1]) & 0x7F;
        }

        $integers = [];
        for ($i = 0; $i < 2; $i++) {
            $length = ord($der[$offset + 1]);
            $value = ltrim(substr($der, $offset + 2, $length), "\0");
            $integers[] = str_pad($value, 32, "\0", STR_PAD_LEFT);
            $offset += 2 + $length;
        }

        return $integers[0].$integers[1];
    }
}
