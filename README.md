# URI Move

**Licença:** [MIT](LICENSE).

Aplicativo de caronas para a comunidade acadêmica da URI. Reúne cadastro com verificação de e-mail institucional, veículos, oferta e solicitação de caronas e conversa em grupo entre motorista e passageiros confirmados.

Consulte o [backlog do projeto](BACKLOG.md) para acompanhar prioridades, critérios de aceite e validações pendentes.

## Estrutura

- `backend/`: API Laravel, autenticação com Sanctum e PostgreSQL.
- `front/`: aplicativo Flutter, com versão web hospedada na Vercel.
- `backend/app/Services/`: geração e validação de códigos separadas do transporte de e-mail.
- `backend/render.yaml`: modelo de deploy da API no Render, sem credenciais reais.

O chat consulta novas mensagens periodicamente; não utiliza WebSockets.

## Executar localmente

### Windows (automático)

1. Clique duas vezes em `setup.cmd` (uma vez). Instala Git, PHP 8.4, PostgreSQL 16 (senha `postgres`), Composer e Flutter, cria os bancos `urimove` e `urimove_test`, gera o `.env` e aplica migrações com dados demo.
2. Clique duas vezes em `start.cmd` sempre que for usar. Abre a API em `http://127.0.0.1:8000` e o app no navegador.

As contas demo estão em `backend/database/seeders/DemoSeeder.php`. Com `MAIL_MAILER=log`, os códigos de verificação ficam em `backend/storage/logs/laravel.log`.

### Manual

Requisitos: PHP 8.4.1 ou superior (exigido pelo Laravel 13/Symfony 8 do `composer.lock`) com as extensões exigidas pelo Composer, Composer, PostgreSQL e Flutter 3.47.3 (Dart 3.13.3).

Na pasta `backend`:

```sh
composer install
cp .env.example .env
php artisan key:generate
```

No PowerShell, use `Copy-Item .env.example .env` para copiar o arquivo. Crie um banco PostgreSQL chamado `urimove` e configure `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME` e `DB_PASSWORD` no `.env` local. Depois execute:

```sh
php artisan migrate --seed
php artisan serve
```

Os dados demonstrativos são criados somente em ambiente `local` ou `testing`. O seeder demo rejeita execução em produção, inclusive quando chamado diretamente. Com `MAIL_MAILER=log`, os códigos locais são registrados em `backend/storage/logs/laravel.log`.

Em outro terminal, na pasta `front`:

```sh
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api/v1
```

## Verificações

Crie um banco separado chamado `urimove_test`. As configurações padrão para testes estão em `backend/phpunit.xml`: PostgreSQL local, usuário e senha de teste `postgres`. Ajuste essas configurações para seu ambiente de testes, sem apontar para um banco com dados reais: os testes recriam as tabelas.

Na pasta `backend`:

```sh
php artisan config:clear
php artisan test
php vendor/bin/pint --test
```

Na pasta `front`:

```sh
flutter analyze
flutter test
```

## Deploy

A API usa o Dockerfile de `backend`. O modelo `backend/render.yaml` deve ser configurado com as credenciais de seu próprio PostgreSQL. Para Supabase, utilize os dados de conexão do pooler e `DB_SSLMODE=require`. O arquivo `.env.production.example` mostra as variáveis disponíveis sem armazenar segredos.

Configure `APP_ENV=production`, `APP_DEBUG=false` e uma chave persistente `APP_KEY` ou `APP_KEY_BASE64` no provedor. `RUN_MIGRATIONS=true` aplica migrações e os cadastros de campus e cursos durante a inicialização. Esse processo não cria usuários demo. A rota `/up` verifica a disponibilidade da API.

Para enviar códigos pela Brevo, configure no servidor `MAIL_MAILER=brevo`, `BREVO_API_KEY`, `MAIL_FROM_ADDRESS` e `MAIL_FROM_NAME`. O remetente precisa estar verificado na sua conta Brevo. Se sua conta restringir IPs, configure os intervalos de saída do seu provedor na própria Brevo.

Na Vercel, selecione `front` como diretório raiz. Configure `API_URL` com o endereço HTTPS da sua API, incluindo `/api/v1`. O arquivo `front/vercel.json` utiliza `front/scripts/vercel-build.sh` para compilar o aplicativo.

## Credenciais e dados locais

Guarde senhas, chaves de API e conexões reais somente no `.env` local ou nas variáveis secretas do provedor. Esses arquivos, logs e capturas locais dos painéis estão excluídos do Git. Nenhuma chave do servidor deve ser passada ao Flutter: `API_URL` é um endereço público, compilado no aplicativo.

Antes de publicar novos arquivos, revise o conteúdo de `git diff --cached`. Os arquivos de exemplo devem continuar contendo somente valores genéricos.

## Licença

Este projeto é distribuído sob a licença [MIT](LICENSE). Copyright (c) 2026 foxx054. As dependências mantêm suas respectivas licenças.
