@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uri_move_app/core/token_storage.dart';
import 'package:web/web.dart' as web;

void main() {
  tearDown(() {
    web.window.localStorage.removeItem('auth_token');
    web.window.sessionStorage.removeItem('auth_token');
    web.window.localStorage.removeItem('flutter.auth_token');
  });

  test('mantém o login no localStorage entre sessões do navegador', () async {
    await TokenStorage().write('user-token');

    expect(web.window.localStorage.getItem('auth_token'), 'user-token');
    expect(await TokenStorage().read(), 'user-token');
  });

  test('migra o login salvo apenas na aba (versão anterior)', () async {
    web.window.sessionStorage.setItem('auth_token', 'tab-token');

    expect(await TokenStorage().read(), 'tab-token');
    expect(web.window.localStorage.getItem('auth_token'), 'tab-token');
    expect(web.window.sessionStorage.getItem('auth_token'), isNull);
  });

  test('logout remove o login salvo', () async {
    await TokenStorage().write('user-token');

    await TokenStorage().clear();

    expect(await TokenStorage().read(), isNull);
  });
}
