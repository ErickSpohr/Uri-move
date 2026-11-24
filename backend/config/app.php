<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Nome da aplicação
    |--------------------------------------------------------------------------
    |
    | Este é o nome da aplicação, usado pelo framework em notificações e
    | em outros elementos da interface que exibem o nome do sistema.
    |
    */

    'name' => env('APP_NAME', 'Laravel'),

    /*
    |--------------------------------------------------------------------------
    | Ambiente da aplicação
    |--------------------------------------------------------------------------
    |
    | Este valor define o ambiente em que a aplicação está sendo executada e
    | pode influenciar a configuração dos serviços usados. Defina-o no arquivo
    | ".env".
    |
    */

    'env' => env('APP_ENV', 'production'),

    /*
    |--------------------------------------------------------------------------
    | Modo de depuração da aplicação
    |--------------------------------------------------------------------------
    |
    | No modo de depuração, erros exibem mensagens detalhadas e rastreamentos
    | de pilha. Quando desativado, é exibida uma página de erro genérica.
    |
    */

    'debug' => (bool) env('APP_DEBUG', false),

    /*
    |--------------------------------------------------------------------------
    | URL da aplicação
    |--------------------------------------------------------------------------
    |
    | Esta URL é usada pelo console para gerar endereços corretamente nos
    | comandos Artisan. Defina-a como o endereço raiz da aplicação.
    |
    */

    'url' => env('APP_URL', 'http://localhost'),

    /*
    |--------------------------------------------------------------------------
    | Fuso horário da aplicação
    |--------------------------------------------------------------------------
    |
    | Aqui você pode definir o fuso horário padrão da aplicação, usado pelas
    | funções de data e hora do PHP. O padrão é "UTC", adequado para a maioria
    | dos casos.
    |
    */

    'timezone' => 'UTC',

    /*
    |--------------------------------------------------------------------------
    | Configuração de idioma da aplicação
    |--------------------------------------------------------------------------
    |
    | O idioma da aplicação define o padrão usado pelos recursos de tradução
    | e localização do Laravel. Escolha um idioma para o qual existam textos
    | traduzidos.
    |
    */

    'locale' => env('APP_LOCALE', 'en'),

    'fallback_locale' => env('APP_FALLBACK_LOCALE', 'en'),

    'faker_locale' => env('APP_FAKER_LOCALE', 'en_US'),

    /*
    |--------------------------------------------------------------------------
    | Chave de criptografia
    |--------------------------------------------------------------------------
    |
    | Esta chave é usada pelos serviços de criptografia do Laravel. Defina
    | uma sequência aleatória de 32 caracteres para proteger os dados
    | criptografados antes de publicar a aplicação.
    |
    */

    'cipher' => 'AES-256-CBC',

    'key' => env('APP_KEY'),

    'previous_keys' => [
        ...array_filter(
            explode(',', (string) env('APP_PREVIOUS_KEYS', ''))
        ),
    ],

    /*
    |--------------------------------------------------------------------------
    | Driver do modo de manutenção
    |--------------------------------------------------------------------------
    |
    | Estas opções definem o driver usado para controlar o modo de manutenção
    | do Laravel. O driver "cache" permite controlar esse modo em várias
    | máquinas.
    |
    | Drivers compatíveis: "file", "cache", "array"
    |
    */

    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE', 'database'),
    ],

];
