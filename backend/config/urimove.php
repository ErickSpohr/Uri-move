<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Domínios de e-mail institucional permitidos
    |--------------------------------------------------------------------------
    |
    | Somente e-mails que terminem em um destes domínios podem se cadastrar.
    |
    */
    'allowlist_email_domains' => [
        'uri.edu.br',
        'uri.br',
        'aluno.santoangelo.uri.br',
    ],

    /*
    |--------------------------------------------------------------------------
    | Código de verificação de e-mail
    |--------------------------------------------------------------------------
    |
    */
    'verification_code' => [
        'digits' => 6,
        'expires_at_minutes' => 10,
    ],

    /*
    |--------------------------------------------------------------------------
    | Administradores
    |--------------------------------------------------------------------------
    |
    | E-mails promovidos a administrador no start do container
    | (php artisan users:make-admin). Configurado no painel do Render.
    |
    */
    'admin_emails' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('ADMIN_EMAILS', '')),
    ))),

    // Conta de serviço do Firebase (JSON, ou JSON em base64) para notificações no app Android.
    'firebase_credentials' => env('FIREBASE_CREDENTIALS'),

    // Rateio de custos: preço do litro (R$) e consumo padrão quando o veículo não informa (km/L).
    'fuel_price' => (float) env('FUEL_PRICE', 6.50),
    'default_fuel_consumption' => (float) env('DEFAULT_FUEL_CONSUMPTION', 10),
];
