import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/ride_detail_screen.dart';
import '../widgets/in_app_notification.dart';
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
  static StreamSubscription<RemoteMessage>? _foreground;

  /// Navegador raiz: com o app aberto o Android não exibe a notificação na
  /// barra, então ela é mostrada no topo da tela (overlay do navegador).
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Último problema no registro, exibido no teste de notificações.
  static String? lastError;

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
  /// Retorna true se o aparelho ficou registrado.
  static Future<bool> register(ApiRepository api) async {
    try {
      if (!await _init()) {
        lastError = 'App sem configuração do Firebase.';
        return false;
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        lastError = 'Notificações bloqueadas nas configurações do Android.';
        return false;
      }
      final token = await messaging.getToken();
      if (token == null) {
        lastError = 'O Firebase não gerou o token do aparelho.';
        return false;
      }
      await api.registerDevice(token);
      _refresh ??= messaging.onTokenRefresh.listen(
        (token) => api.registerDevice(token).catchError((_) {}),
      );
      _foreground ??= FirebaseMessaging.onMessage.listen(_showInApp);
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'Falha ao registrar: $error';
      debugPrint('FCM indisponível: $error');
      return false;
    }
  }

  static void _showInApp(RemoteMessage message) {
    final notification = message.notification;
    final navigator = navigatorKey.currentState;
    if (notification == null || navigator == null) return;
    final rideId = int.tryParse('${message.data['ride_id'] ?? ''}');
    InAppNotification.show(
      navigator.overlay!,
      title: notification.title ?? 'URI Move',
      body: notification.body,
      type: message.data['type'] as String?,
      // Toque abre a carona relacionada, quando houver.
      onTap: rideId == null
          ? null
          : () => navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => RideDetailScreen(rideId: rideId),
              ),
            ),
    );
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
