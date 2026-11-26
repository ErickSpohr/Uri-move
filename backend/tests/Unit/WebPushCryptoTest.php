<?php

namespace Tests\Unit;

use App\Services\WebPush\WebPushCrypto;
use PHPUnit\Framework\TestCase;

class WebPushCryptoTest extends TestCase
{
    /**
     * Exemplo da RFC 8291, seção 5 e apêndice A.
     */
    public function test_encryption_matches_rfc8291_example(): void
    {
        $b = fn (string $value) => WebPushCrypto::base64UrlDecode($value);

        $serverPublic = $b('BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8');
        $ephemeral = [
            'private_pem' => WebPushCrypto::privatePemFromRaw($b('yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw'), $serverPublic),
            'public' => $serverPublic,
        ];

        $body = WebPushCrypto::encrypt(
            'When I grow up, I want to be a watermelon',
            $b('BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4'),
            $b('BTBZMqHH6r4Tts7J_aSIgg'),
            $ephemeral,
            $b('DGv6ra1nlYgDCS1FRnbzlw'),
        );

        $header = substr($body, 0, 86);
        $ciphertext = substr($body, 86);

        $this->assertSame('DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy', substr(WebPushCrypto::base64UrlEncode($header), 0, 60));
        $this->assertStringEndsWith('nmYWAmS6TlzAC8wEqKK6PBru3jl7A8', WebPushCrypto::base64UrlEncode($header));
        $this->assertSame(
            '8pfeW0KbunFT06SuDKoJH9Ql87S1QUrdirN6GcG7sFz1y1sqLgVi1VhjVkHsUoEsbI_0LpXMuGvnzQ',
            WebPushCrypto::base64UrlEncode($ciphertext),
        );
    }

    public function test_vapid_token_has_valid_es256_signature(): void
    {
        $pair = WebPushCrypto::generateKeyPair();

        $authorization = WebPushCrypto::vapidAuthorization(
            'https://fcm.googleapis.com/fcm/send/abc',
            'mailto:contato@uri.edu.br',
            $pair['private_pem'],
            $pair['public'],
        );

        $this->assertMatchesRegularExpression('/^vapid t=[\w-]+\.[\w-]+\.[\w-]+, k=[\w-]+$/', $authorization);
        preg_match('/t=([\w-]+)\.([\w-]+)\.([\w-]+)/', $authorization, $m);

        $claims = json_decode(WebPushCrypto::base64UrlDecode($m[2]), true);
        $this->assertSame('https://fcm.googleapis.com', $claims['aud']);

        // Reconverte r||s para DER e confere com a chave pública.
        $raw = WebPushCrypto::base64UrlDecode($m[3]);
        $this->assertSame(64, strlen($raw));
        $int = fn (string $v) => (ord(ltrim($v, "\0")[0]) & 0x80 ? "\0" : '').ltrim($v, "\0");
        $r = $int(substr($raw, 0, 32));
        $s = $int(substr($raw, 32));
        $seq = "\x02".chr(strlen($r)).$r."\x02".chr(strlen($s)).$s;
        $der = "\x30".chr(strlen($seq)).$seq;

        $this->assertSame(1, openssl_verify($m[1].'.'.$m[2], $der, WebPushCrypto::publicPemFromRaw($pair['public']), OPENSSL_ALGO_SHA256));
    }
}
