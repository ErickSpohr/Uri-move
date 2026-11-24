<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Configuração de compartilhamento de recursos entre origens (CORS)
    |--------------------------------------------------------------------------
    |
    | Aqui você pode configurar o compartilhamento de recursos entre origens,
    | ou "CORS". Isso determina quais operações entre origens podem ser
    | executadas nos navegadores. Ajuste estas opções conforme necessário.
    |
    | Saiba mais: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
