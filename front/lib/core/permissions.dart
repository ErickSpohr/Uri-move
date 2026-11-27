import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Pedidos de permissão do sistema feitos um de cada vez.
///
/// O Android mostra só uma caixa de permissão por vez: pedidos simultâneos
/// (mapa, campo de endereço, notificações) falham em silêncio e a permissão
/// parece negada. Aqui os pedidos entram numa fila, e o de localização é
/// compartilhado por quem pedir ao mesmo tempo.
class AppPermissions {
  AppPermissions._();

  static Future<void> _queue = Future<void>.value();
  static Future<LocationPermission>? _locationRequest;

  /// Executa [task] depois que o pedido anterior da fila terminar.
  static Future<T> serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Verifica e, se ainda não decidido, pede a permissão de localização.
  static Future<LocationPermission> requestLocation() async {
    final current = await Geolocator.checkPermission();
    if (current != LocationPermission.denied) return current;
    return _locationRequest ??= serial(() async {
      // Outro pedido da fila pode já ter resolvido.
      final again = await Geolocator.checkPermission();
      if (again != LocationPermission.denied) return again;
      return Geolocator.requestPermission();
    }).whenComplete(() => _locationRequest = null);
  }
}
