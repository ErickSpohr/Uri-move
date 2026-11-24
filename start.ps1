# URI Move - inicia API (Laravel) e app (Flutter web) localmente.
# Pré-requisito: setup.cmd executado ao menos uma vez.

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ApiUrl = 'http://127.0.0.1:8000/api/v1'

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# PostgreSQL precisa estar em execução antes da API.
$svc = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($svc -and $svc.Status -ne 'Running') { Start-Service $svc.Name }

# API em janela separada; fechar a janela encerra o servidor.
$backend = Join-Path $Root 'backend'
Start-Process powershell -ArgumentList '-NoExit', '-Command', "Set-Location '$backend'; php artisan serve --host 127.0.0.1 --port 8000"

# Aguarda /up responder (até 30 s).
$ready = $false
for ($i = 0; $i -lt 30 -and -not $ready; $i++) {
    Start-Sleep -Seconds 1
    try { $ready = (Invoke-WebRequest 'http://127.0.0.1:8000/up' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch {}
}
if (-not $ready) { Write-Warning 'A API não respondeu em /up. Verifique a janela do servidor.' }
else { Write-Host 'API em http://127.0.0.1:8000' -ForegroundColor Green }

# Chrome se instalado; senão Edge.
$device = if ((flutter devices --machine | Out-String) -match '"id":\s*"chrome"') { 'chrome' } else { 'edge' }

Write-Host "Abrindo o app no $device. Códigos de verificação de e-mail: backend\storage\logs\laravel.log" -ForegroundColor Cyan
Set-Location (Join-Path $Root 'front')
flutter run -d $device --dart-define=API_URL=$ApiUrl
