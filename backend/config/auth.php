<?php

use App\Models\User;

return [

    /*
    |--------------------------------------------------------------------------
    | Padrões de autenticação
    |--------------------------------------------------------------------------
    |
    | Esta opção define o "guard" de autenticação e o "broker" de redefinição
    | de senha padrão da aplicação. Altere esses valores conforme necessário.
    |
    */

    'defaults' => [
        'guard' => env('AUTH_GUARD', 'web'),
        'passwords' => env('AUTH_PASSWORD_BROKER', 'users'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Guards de autenticação
    |--------------------------------------------------------------------------
    |
    | A seguir, você pode definir cada guard de autenticação da aplicação.
    | A configuração padrão usa armazenamento de sessão e o provedor de
    | usuários do Eloquent.
    |
    | Cada guard possui um provedor que define como os usuários são buscados
    | no banco de dados ou em outro sistema de armazenamento da aplicação.
    | Normalmente, utiliza-se o Eloquent.
    |
    | Compatíveis: "session"
    |
    */

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Provedores de usuários
    |--------------------------------------------------------------------------
    |
    | Todos os guards de autenticação possuem um provedor de usuários, que
    | define como os usuários são obtidos do banco de dados ou de outro sistema
    | de armazenamento usado pela aplicação. Normalmente, utiliza-se o Eloquent.
    |
    | Se houver várias tabelas ou modelos de usuários, você pode configurar
    | vários provedores para representá-los. Depois, atribua esses provedores
    | aos guards de autenticação adicionais que tiver definido.
    |
    | Compatíveis: "database", "eloquent"
    |
    */

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => env('AUTH_MODEL', User::class),
        ],

        // 'users' => [
        //     'driver' => 'database',
        //     'table' => 'users',
        // ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Redefinição de senhas
    |--------------------------------------------------------------------------
    |
    | Estas opções definem o comportamento da redefinição de senha do Laravel,
    | incluindo a tabela que armazena os tokens e o provedor usado para buscar
    | os usuários.
    |
    | O prazo de validade define por quantos minutos cada token de redefinição
    | será válido. Tokens com validade curta reduzem o tempo disponível para
    | tentativas de adivinhação. Altere o valor se necessário.
    |
    | O limite define quantos segundos o usuário deve aguardar antes de gerar
    | outro token de redefinição. Isso evita a criação rápida de muitos tokens.
    |
    */

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => env('AUTH_PASSWORD_RESET_TOKEN_TABLE', 'password_reset_tokens'),
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Tempo limite da confirmação de senha
    |--------------------------------------------------------------------------
    |
    | Defina após quantos segundos a confirmação de senha expira e o usuário
    | precisa informá-la novamente. Por padrão, o prazo é de três horas.
    |
    */

    'password_timeout' => env('AUTH_PASSWORD_TIMEOUT', 10800),

];
