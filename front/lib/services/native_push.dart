import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_repository.dart';

/// Notificações do app Android via Firebase Cloud Messaging.
///
/// A configuração do projeto Firebase chega por --dart-define no build do APK
/// (valores públicos do google-services.json). Sem ela, ou fora do Android,
/// tudo é no-op e o app segue funcionando.
class NativePush {
  NativePush._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static StreamSubscription<String>? _refresh;

  static bool get configured =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static Future<bool> _init() async {
    if (!configured) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
    }
    return true;
  }

  /// Pede permissão (Android 13+) e registra o token do aparelho na API.
  static Future<void> register(ApiRepository api) async {
    try {
      if (!await _init()) return;
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await api.registerDevice(token);
      _refresh ??= messaging.onTokenRefresh.listen(
        (token) => api.registerDevice(token).catchError((_) {}),
      );
    } catch (error) {
      debugPrint('FCM indisponível: $error');
    }
  }

  /// Remove o aparelho da conta (logout), para o próximo usuário não receber
  /// avisos da conta anterior.
  static Future<void> unregister(ApiRepository api) async {
    try {
      if (!configured || Firebase.apps.isEmpty) return;
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) await api.unregisterDevice(token);
      await messaging.deleteToken();
      await _refresh?.cancel();
      _refresh = null;
    } catch (_) {}
  }
}
