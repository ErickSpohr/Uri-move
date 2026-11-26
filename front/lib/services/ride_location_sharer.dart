import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api.dart';
import 'api_repository.dart';

/// Envia a posição do motorista enquanto ele tem uma carona em andamento,
/// em qualquer tela do app. Para sozinho quando a carona termina ou é cancelada.
class RideLocationSharer extends ChangeNotifier {
  RideLocationSharer(this._api);

  static const interval = Duration(seconds: 10);

  final ApiRepository _api;
  Timer? _timer;
  bool _sending = false;

  int? _rideId;
  String? _error;

  /// Carona cuja posição está sendo enviada (null se nenhuma).
  int? get rideId => _rideId;

  /// Último problema de GPS/permissão; null quando o envio está funcionando.
  String? get error => _error;

  bool get isSharing => _rideId != null;

  /// Procura uma carona em andamento do usuário como motorista e começa ou
  /// encerra o envio conforme o caso.
  Future<void> sync() async {
    try {
      final rides = await _api.myRides();
      final active = rides.where((r) => r.isActive).firstOrNull;
      if (active != null) {
        start(active.id);
      } else if (_rideId != null) {
        await stop(notifyServer: false);
      }
    } catch (_) {
      // Sem conexão: tenta de novo na próxima sincronização.
    }
  }

  void start(int rideId) {
    if (_rideId == rideId && _timer != null) {
      _send(); // "Tentar de novo": envia já, mantendo o temporizador.
      return;
    }
    _timer?.cancel();
    _rideId = rideId;
    _error = null;
    notifyListeners();
    _send();
    _timer = Timer.periodic(interval, (_) => _send());
  }

  Future<void> stop({bool notifyServer = true}) async {
    final rideId = _rideId;
    _timer?.cancel();
    _timer = null;
    _rideId = null;
    _error = null;
    notifyListeners();
    if (notifyServer && rideId != null) {
      try {
        await _api.stopRideLocation(rideId);
      } catch (_) {}
    }
  }

  Future<void> _send() async {
    final rideId = _rideId;
    if (_sending || rideId == null) return;
    _sending = true;
    try {
      final position = await _position();
      await _api.updateRideLocation(
        rideId,
        position.latitude,
        position.longitude,
        position.accuracy.round().clamp(0, 10000),
      );
      _setError(null);
    } on ApiException catch (e) {
      // 403/404/422: a carona não está mais em andamento.
      if (e.statusCode == 403 || e.statusCode == 404 || e.statusCode == 422) {
        await stop(notifyServer: false);
      } else if (!e.isConnectionError) {
        _setError(e.message);
      }
    } on StateError catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Não foi possível obter sua localização.');
    } finally {
      _sending = false;
    }
  }

  void _setError(String? value) {
    if (_error == value) return;
    _error = value;
    notifyListeners();
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do celular para os passageiros verem o carro.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Permita o acesso à localização para os passageiros verem o carro.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      ),
    ).timeout(const Duration(seconds: 25));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
