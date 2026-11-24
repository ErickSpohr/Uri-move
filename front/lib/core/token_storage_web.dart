import 'package:web/web.dart' as web;

/// Mantém a autenticação na aba atual, inclusive após atualizar a página.
class TokenStorage {
  static const _key = 'auth_token';

  Future<String?> read() async {
    // Não migra o token compartilhado: cada aba deve fazer seu próprio login.
    web.window.localStorage.removeItem('flutter.auth_token');
    return web.window.sessionStorage.getItem(_key);
  }

  Future<void> write(String token) async {
    web.window.sessionStorage.setItem(_key, token);
  }

  Future<void> clear() async {
    web.window.sessionStorage.removeItem(_key);
  }
}
