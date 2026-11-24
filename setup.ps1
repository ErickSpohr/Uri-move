# URI Move - instalação do ambiente local no Windows.
# Executar uma vez: clique duplo em setup.cmd (ou: powershell -ExecutionPolicy Bypass -File setup.ps1).
# Idempotente: pode ser executado de novo sem refazer o que já está instalado.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Tools = Join-Path $env:USERPROFILE 'tools'
$PgPassword = 'postgres'
$PgBin = 'C:\Program Files\PostgreSQL\16\bin'
$FlutterVersion = '3.47.3'
$FlutterDir = Join-Path $Tools 'flutter'
$Composer = Join-Path $Tools 'composer.phar'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "    $msg" -ForegroundColor Green }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    if (Test-Path "$FlutterDir\bin") { $env:Path += ";$FlutterDir\bin" }
    if (Test-Path $PgBin) { $env:Path += ";$PgBin" }
}

function Add-UserPath($dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($current -split ';') -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', "$current;$dir", 'User')
    }
}

function Winget-Install($id, $extra = @()) {
    $listed = winget list --id $id -e --accept-source-agreements 2>$null | Out-String
    if ($listed -match [regex]::Escape($id)) { Ok "$id já instalado"; return }
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements @extra
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar $id (winget código $LASTEXITCODE)." }
    Ok "$id instalado"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget não encontrado. Instale o "App Installer" pela Microsoft Store e execute de novo.'
}
New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# ---------------------------------------------------------------- Programas
Step 'Instalando Git, PHP 8.4 e PostgreSQL 16 (aceite as janelas de administrador)'
Winget-Install 'Git.Git'
Winget-Install 'PHP.PHP.8.4'
Winget-Install 'PostgreSQL.PostgreSQL.16' @('--override', "--mode unattended --unattendedmodeui minimal --superpassword $PgPassword --serverport 5432")
Refresh-Path

# ---------------------------------------------------------------- PHP
Step 'Configurando extensões do PHP'
$php = (Get-Command php -ErrorAction SilentlyContinue).Source
if (-not $php) { throw 'php não encontrado no PATH. Feche e abra o terminal e execute setup.cmd de novo.' }
# winget pode expor php.exe como link simbólico; o php.ini fica na pasta real.
$phpItem = Get-Item $php
if ($phpItem.LinkType -and $phpItem.Target) { $php = @($phpItem.Target)[0] }
$phpDir = Split-Path $php
$ini = Join-Path $phpDir 'php.ini'
if (-not (Test-Path $ini)) { Copy-Item (Join-Path $phpDir 'php.ini-development') $ini }
$content = Get-Content $ini -Raw
$content = $content -replace '(?m)^;\s*extension_dir\s*=\s*"ext"', 'extension_dir = "ext"'
foreach ($ext in 'curl', 'fileinfo', 'gd', 'intl', 'mbstring', 'openssl', 'pdo_pgsql', 'pgsql', 'zip', 'sodium') {
    $content = $content -replace "(?m)^;\s*extension\s*=\s*$ext\s*$", "extension=$ext"
}
Set-Content -Path $ini -Value $content -Encoding ASCII
$version = & php -r 'echo PHP_VERSION;'
if (-not ($version -like '8.4*')) { throw "PHP $version encontrado no PATH; é necessário 8.4. Remova versões antigas do PATH." }
$mods = (& php -m) -join ' '
if ($mods -notmatch 'pdo_pgsql') { throw "Extensão pdo_pgsql não carregou. Verifique $ini." }
Ok "PHP $version com pdo_pgsql ($ini)"

# ---------------------------------------------------------------- Composer
Step 'Baixando Composer'
if (-not (Test-Path $Composer)) {
    Invoke-WebRequest 'https://getcomposer.org/download/latest-stable/composer.phar' -OutFile $Composer
}
Ok $Composer

# ---------------------------------------------------------------- Flutter
Step "Instalando Flutter $FlutterVersion"
if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
    git clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $FlutterDir
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao clonar o Flutter.' }
}
Add-UserPath "$FlutterDir\bin"
Refresh-Path
flutter config --no-analytics | Out-Null
flutter --version
Ok 'Flutter pronto'

# ---------------------------------------------------------------- Banco
Step 'Criando bancos urimove e urimove_test'
$env:PGPASSWORD = $PgPassword
$svc = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($svc -and $svc.Status -ne 'Running') { Start-Service $svc.Name }
foreach ($db in 'urimove', 'urimove_test') {
    $exists = & psql -U postgres -h 127.0.0.1 -tAc "SELECT 1 FROM pg_database WHERE datname='$db'"
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível conectar ao PostgreSQL com a senha '$PgPassword'. Se você já tinha o PostgreSQL instalado com outra senha, altere `$PgPassword no início deste script." }
    if ($exists -ne '1') { & psql -U postgres -h 127.0.0.1 -c "CREATE DATABASE $db;" | Out-Null; Ok "$db criado" } else { Ok "$db já existe" }
}

# ---------------------------------------------------------------- Backend
Step 'Preparando o backend (composer install, .env, migrations e dados demo)'
Push-Location (Join-Path $Root 'backend')
try {
    & php $Composer install --no-interaction --no-progress
    if ($LASTEXITCODE -ne 0) { throw 'composer install falhou.' }
    if (-not (Test-Path '.env')) {
        (Get-Content '.env.example') -replace '^DB_PASSWORD=.*$', "DB_PASSWORD=$PgPassword" | Set-Content '.env' -Encoding UTF8
        & php artisan key:generate
    }
    & php artisan config:clear | Out-Null
    & php artisan migrate --seed --force
    if ($LASTEXITCODE -ne 0) { throw 'migrate --seed falhou.' }
} finally { Pop-Location }
Ok 'Backend pronto'

# ---------------------------------------------------------------- Front
Step 'Preparando o front (flutter pub get)'
Push-Location (Join-Path $Root 'front')
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou.' }
} finally { Pop-Location }

Write-Host "`nInstalação concluída. Para abrir o app: clique duplo em start.cmd" -ForegroundColor Green
