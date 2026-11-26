# URI Move — aplicativo Flutter

Interface de cadastro, veículos, caronas e chat em grupo. Consulte o [README do projeto](../README.md) para configurar a API Laravel e o banco de dados.

## Desenvolvimento

Utilize Flutter 3.47.3 e Dart 3.13.3, conforme a versão usada pelo script de deploy.

```sh
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api/v1
```

## Validação

```sh
flutter analyze
flutter test
```

## Versão web

```sh
flutter build web --release --dart-define=API_URL=https://SUA-API/api/v1
```

Na Vercel, configure `front` como diretório raiz e `API_URL` como variável de ambiente. O `vercel.json` executa o script de build e configura as rotas da aplicação.

O login web fica salvo no navegador (localStorage) até o usuário sair da conta; para testar duas contas ao mesmo tempo, use uma janela anônima ou outro navegador. As contas demonstrativas aparecem somente em modo de desenvolvimento. Credenciais da Brevo e do banco pertencem ao servidor; nunca devem ser incluídas no aplicativo.
