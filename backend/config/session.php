<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Driver de sessão padrão
    |--------------------------------------------------------------------------
    |
    | Esta opção define o driver de sessão padrão usado nas solicitações.
    | O Laravel oferece várias opções de armazenamento persistente; o banco
    | de dados é uma boa escolha padrão.
    |
    | Compatíveis: "file", "cookie", "database", "memcached",
    |            "redis", "dynamodb", "array"
    |
    */

    'driver' => env('SESSION_DRIVER', 'database'),

    /*
    |--------------------------------------------------------------------------
    | Duração da sessão
    |--------------------------------------------------------------------------
    |
    | Defina quantos minutos a sessão pode permanecer inativa antes de expirar.
    | Para expirá-la ao fechar o navegador, use a opção expire_on_close.
    |
    */

    'lifetime' => (int) env('SESSION_LIFETIME', 120),

    'expire_on_close' => env('SESSION_EXPIRE_ON_CLOSE', false),

    /*
    |--------------------------------------------------------------------------
    | Criptografia da sessão
    |--------------------------------------------------------------------------
    |
    | Esta opção define se os dados da sessão serão criptografados antes do
    | armazenamento. O Laravel faz a criptografia automaticamente e a sessão
    | pode ser usada normalmente.
    |
    */

    'encrypt' => env('SESSION_ENCRYPT', false),

    /*
    |--------------------------------------------------------------------------
    | Local dos arquivos de sessão
    |--------------------------------------------------------------------------
    |
    | Com o driver de sessão "file", os arquivos são gravados em disco. O
    | local padrão é definido aqui, mas você pode escolher outro diretório.
    |
    */

    'files' => storage_path('framework/sessions'),

    /*
    |--------------------------------------------------------------------------
    | Conexão de banco de dados da sessão
    |--------------------------------------------------------------------------
    |
    | Ao usar os drivers "database" ou "redis", você pode especificar a
    | conexão que gerenciará as sessões. Ela deve corresponder a uma conexão
    | definida nas opções do banco de dados.
    |
    */

    'connection' => env('SESSION_CONNECTION'),

    /*
    |--------------------------------------------------------------------------
    | Tabela de sessões no banco de dados
    |--------------------------------------------------------------------------
    |
    | Com o driver "database", você pode definir a tabela que armazenará as
    | sessões. Há um valor padrão que pode ser alterado se necessário.
    |
    */

    'table' => env('SESSION_TABLE', 'sessions'),

    /*
    |--------------------------------------------------------------------------
    | Armazenamento de cache da sessão
    |--------------------------------------------------------------------------
    |
    | Ao usar um backend de sessão baseado em cache, defina o armazenamento
    | usado para manter os dados entre solicitações. Ele deve corresponder
    | a um dos armazenamentos de cache configurados.
    |
    | Afeta: "dynamodb", "memcached", "redis"
    |
    */

    'store' => env('SESSION_STORE'),

    /*
    |--------------------------------------------------------------------------
    | Probabilidade de limpeza de sessões
    |--------------------------------------------------------------------------
    |
    | Alguns drivers precisam remover sessões antigas manualmente. Estes
    | valores definem a chance de a limpeza ocorrer em cada solicitação.
    | Por padrão, a probabilidade é de 2 em 100.
    |
    */

    'lottery' => [2, 100],

    /*
    |--------------------------------------------------------------------------
    | Nome do cookie de sessão
    |--------------------------------------------------------------------------
    |
    | Aqui você pode alterar o nome do cookie de sessão criado pelo framework.
    | Em geral, não é necessário mudar este valor, pois isso não oferece um
    | ganho significativo de segurança.
    |
    */

    'cookie' => env(
        'SESSION_COOKIE',
        Str::slug((string) env('APP_NAME', 'laravel')).'-session'
    ),

    /*
    |--------------------------------------------------------------------------
    | Caminho do cookie de sessão
    |--------------------------------------------------------------------------
    |
    | O caminho do cookie define em quais rotas ele estará disponível. Em
    | geral, corresponde à raiz da aplicação, mas pode ser alterado.
    |
    */

    'path' => env('SESSION_PATH', '/'),

    /*
    |--------------------------------------------------------------------------
    | Domínio do cookie de sessão
    |--------------------------------------------------------------------------
    |
    | Este valor define em quais domínios e subdomínios o cookie estará
    | disponível. Por padrão, ele vale para o domínio raiz. Normalmente,
    | não é necessário alterar esta opção.
    |
    */

    'domain' => env('SESSION_DOMAIN'),

    /*
    |--------------------------------------------------------------------------
    | Cookies somente por HTTPS
    |--------------------------------------------------------------------------
    |
    | Quando esta opção é verdadeira, os cookies de sessão só são enviados ao
    | servidor por uma conexão HTTPS, evitando o envio sem segurança.
    |
    */

    'secure' => env('SESSION_SECURE_COOKIE'),

    /*
    |--------------------------------------------------------------------------
    | Acesso somente por HTTP
    |--------------------------------------------------------------------------
    |
    | Quando verdadeiro, o JavaScript não pode acessar o valor do cookie, que
    | fica disponível somente pelo protocolo HTTP. Em geral, mantenha ativado.
    |
    */

    'http_only' => env('SESSION_HTTP_ONLY', true),

    /*
    |--------------------------------------------------------------------------
    | Cookies do mesmo site
    |--------------------------------------------------------------------------
    |
    | Esta opção define o comportamento dos cookies em solicitações entre
    | sites e ajuda a reduzir ataques CSRF. O padrão "lax" permite
    | solicitações entre sites de forma mais segura.
    |
    | Consulte: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#samesitesamesite-value
    |
    | Compatíveis: "lax", "strict", "none", null
    |
    */

    'same_site' => env('SESSION_SAME_SITE', 'lax'),

    /*
    |--------------------------------------------------------------------------
    | Cookies particionados
    |--------------------------------------------------------------------------
    |
    | Quando verdadeiro, o cookie fica vinculado ao site de nível superior em
    | contextos entre sites. O navegador aceita cookies particionados quando
    | marcados como "secure" e com Same-Site definido como "none".
    |
    */

    'partitioned' => env('SESSION_PARTITIONED_COOKIE', false),

    /*
    |--------------------------------------------------------------------------
    | Serialização da sessão
    |--------------------------------------------------------------------------
    |
    | Este valor define como os dados da sessão são serializados. O padrão é
    | JSON. O formato "php" permite armazenar objetos PHP, mas pode expor a
    | aplicação a ataques de cadeia de gadgets se a APP_KEY vazar.
    |
    | Compatíveis: "json", "php"
    |
    */

    'serialization' => 'json',

];
