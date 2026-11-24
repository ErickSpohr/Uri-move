<?php

use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Laravel\Sanctum\Http\Middleware\AuthenticateSession;
use Laravel\Sanctum\Sanctum;

return [

    /*
    |--------------------------------------------------------------------------
    | Domínios com estado
    |--------------------------------------------------------------------------
    |
    | Requisições dos domínios/hosts a seguir receberão cookies de autenticação
    | com estado da API. Normalmente, devem incluir os domínios locais e de
    | produção que acessam sua API por meio de uma SPA no frontend.
    |
    */

    'stateful' => explode(',', env('SANCTUM_STATEFUL_DOMAINS', sprintf(
        '%s%s',
        'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000,::1',
        Sanctum::currentApplicationUrlWithPort(),
        // Sanctum::currentRequestHost(),
    ))),

    /*
    |--------------------------------------------------------------------------
    | Guards do Sanctum
    |--------------------------------------------------------------------------
    |
    | Este array contém os guards de autenticação verificados quando o Sanctum
    | tenta autenticar uma requisição. Se nenhum deles conseguir autenticá-la,
    | o Sanctum usará o token bearer presente na requisição recebida.
    |
    */

    'guard' => ['web'],

    /*
    |--------------------------------------------------------------------------
    | Minutos até a expiração
    |--------------------------------------------------------------------------
    |
    | Este valor define em quantos minutos um token emitido será considerado
    | expirado. Ele substitui qualquer valor definido no atributo "expires_at"
    | do token, mas não afeta as sessões próprias da aplicação.
    |
    */

    'expiration' => null,

    /*
    |--------------------------------------------------------------------------
    | Prefixo do token
    |--------------------------------------------------------------------------
    |
    | O Sanctum pode adicionar um prefixo aos novos tokens para aproveitar
    | iniciativas de análise de segurança de plataformas de código aberto,
    | que avisam os desenvolvedores quando tokens são enviados a repositórios.
    |
    | Consulte: https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning
    |
    */

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    /*
    |--------------------------------------------------------------------------
    | Middlewares do Sanctum
    |--------------------------------------------------------------------------
    |
    | Ao autenticar sua SPA própria com o Sanctum, talvez seja necessário
    | personalizar alguns middlewares usados pelo Sanctum ao processar a
    | requisição. Altere os middlewares abaixo conforme necessário.
    |
    */

    'middleware' => [
        'authenticate_session' => AuthenticateSession::class,
        'encrypt_cookies' => EncryptCookies::class,
        'validate_csrf_token' => ValidateCsrfToken::class,
    ],

];
