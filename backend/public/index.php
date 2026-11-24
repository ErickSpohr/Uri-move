<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

// Verifica se a aplicação está em modo de manutenção.
if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Carrega o autoloader do Composer.
require __DIR__.'/../vendor/autoload.php';

// Inicializa o Laravel e processa a solicitação HTTP.
/** @var Application $app */
$app = require_once __DIR__.'/../bootstrap/app.php';

$app->handleRequest(Request::capture());
