@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uri_move_app/core/token_storage.dart';
import 'package:web/web.dart' as web;

void main() {
  tearDown(() {
    web.window.sessionStorage.removeItem('auth_token');
    web.window.localStorage.removeItem('flutter.auth_token');
  });

  test('does not restore the shared login from another tab', () async {
    web.window.sessionStorage.removeItem('auth_token');
    web.window.localStorage.setItem('flutter.auth_token', 'other-user');

    expect(await TokenStorage().read(), isNull);
  });

  test('restores the tab login independently of shared storage', () async {
    await TokenStorage().write('tab-user');
    web.window.localStorage.setItem('flutter.auth_token', 'other-user');

    expect(await TokenStorage().read(), 'tab-user');
    expect(web.window.sessionStorage.getItem('auth_token'), 'tab-user');
  });

  test('logout clears only the tab token', () async {
    await TokenStorage().write('tab-user');
    web.window.localStorage.setItem('flutter.auth_token', 'other-user');

    await TokenStorage().clear();

    expect(web.window.sessionStorage.getItem('auth_token'), isNull);
    expect(web.window.localStorage.getItem('flutter.auth_token'), 'other-user');
  });
}
