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
];
