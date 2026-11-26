import 'package:web/web.dart' as web;

/// Mantém o login no navegador (localStorage): sobrevive a fechar a aba,
/// reiniciar o navegador e ao app instalado (PWA). Removido apenas no logout
/// ou quando a API rejeita o token.
class TokenStorage {
  static const _key = 'auth_token';

  /// Chave usada por versões anteriores, que guardavam o login só na aba.
  static const _legacySessionKey = 'auth_token';

  /// Chave antiga do shared_preferences, sem uso.
  static const _legacyPrefsKey = 'flutter.auth_token';

  Future<String?> read() async {
    final storage = web.window.localStorage;
    var token = storage.getItem(_key);

    // Migra o login de uma aba aberta antes da mudança, sem exigir novo login.
    final sessionToken = web.window.sessionStorage.getItem(_legacySessionKey);
    if ((token == null || token.isEmpty) &&
        sessionToken != null &&
        sessionToken.isNotEmpty) {
      token = sessionToken;
      storage.setItem(_key, token);
    }
    web.window.sessionStorage.removeItem(_legacySessionKey);
    storage.removeItem(_legacyPrefsKey);

    return token;
  }

  Future<void> write(String token) async {
    web.window.localStorage.setItem(_key, token);
  }

  Future<void> clear() async {
    web.window.localStorage.removeItem(_key);
    web.window.sessionStorage.removeItem(_legacySessionKey);
  }
}
