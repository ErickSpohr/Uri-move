import 'dart:convert';

import 'push_notifications_stub.dart'
    if (dart.library.js_interop) 'push_notifications_web.dart'
    as platform;

/// Web Push do navegador. Em plataformas sem suporte, todas as operações
/// são no-op e [pushSupported] retorna false.
bool pushSupported() => platform.supported();

/// 'granted', 'denied', 'default' ou 'unsupported'.
String pushPermission() => platform.permission();

/// Pede permissão e cria (ou reaproveita) a assinatura; null se negada.
Future<Map<String, dynamic>?> pushSubscribe(String publicKey) async =>
    _decode(await platform.subscribe(publicKey));

/// Assinatura existente neste navegador, sem pedir permissão.
Future<Map<String, dynamic>?> pushCurrentSubscription() async =>
    _decode(await platform.current());

/// Cancela a assinatura local e retorna o endpoint removido.
Future<String?> pushUnsubscribe() => platform.unsubscribe();

Map<String, dynamic>? _decode(String? json) =>
    json == null ? null : Map<String, dynamic>.from(jsonDecode(json) as Map);
