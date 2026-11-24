import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_repository.dart';
import '../state/auth_controller.dart';

/// Exibe a última posição compartilhada pelo motorista durante a carona.
class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key, required this.ride});

  final Ride ride;

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with WidgetsBindingObserver {
  static const _fallbackCenter = LatLng(-28.3007, -54.2669);
  final _mapController = MapController();
  late final ApiRepository _api;
  late final bool _isDriver;
  Timer? _refreshTimer;
  Timer? _shareTimer;
  LatLng? _car;
  LatLng? _me;
  DateTime? _updatedAt;
  bool _sharing = false;
  bool _fetching = false;
  bool _sending = false;
  bool _locating = false;
  String? _error;

  LatLng? get _destination {
    final location = _lastLocation;
    final latitude = (location?['destination_lat'] as num?)?.toDouble();
    final longitude = (location?['destination_lng'] as num?)?.toDouble();
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
  }

  Map<String, dynamic>? _lastLocation;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _api = auth.api;
    _isDriver = widget.ride.driver.id == auth.user?.id;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopSharing();
    } else {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _shareTimer?.cancel();
    if (_sharing) {
      unawaited(_api.stopRideLocation(widget.ride.id).catchError((_) {}));
    }
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final location = await _api
          .rideLocation(widget.ride.id)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final latitude = (location['latitude'] as num?)?.toDouble();
      final longitude = (location['longitude'] as num?)?.toDouble();
      final car = latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude);
      setState(() {
        _lastLocation = location;
        _car = car;
        _updatedAt = DateTime.tryParse(location['updated_at'] as String? ?? '');
        _error = null;
      });
      final focus = car ?? _destination;
      if (focus != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(focus, car == null ? 12 : 15);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível atualizar a posição.');
      }
    } finally {
      _fetching = false;
    }
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do dispositivo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Permita o acesso à localização nas configurações do navegador ou dispositivo.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      ),
    ).timeout(const Duration(seconds: 25));
  }

  Future<void> _startSharing() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    await _sendPosition();
    if (_sharing && mounted) {
      _shareTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendPosition(),
      );
    }
  }

  Future<void> _sendPosition() async {
    if (_sending || !_sharing) return;
    _sending = true;
    try {
      final position = await _position();
      if (!_sharing) return;
      await _api.updateRideLocation(
        widget.ride.id,
        position.latitude,
        position.longitude,
        position.accuracy.round().clamp(0, 10000),
      );
      await _refresh();
    } catch (error) {
      _shareTimer?.cancel();
      _sharing = false;
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Não foi possível compartilhar a localização.',
        );
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _stopSharing() async {
    if (!_sharing) return;
    _sharing = false;
    _shareTimer?.cancel();
    if (mounted) setState(() {});
    try {
      while (_sending) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await _api.stopRideLocation(widget.ride.id);
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível interromper o compartilhamento.',
        );
      }
    }
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await _position();
      if (mounted) {
        setState(() {
          _me = LatLng(position.latitude, position.longitude);
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Não foi possível obter sua localização.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _estimate(LatLng? target) {
    if (_car == null || target == null) return null;
    final kilometers = const Distance().as(LengthUnit.Kilometer, _car!, target);
    final minutes = max(1, (kilometers * 1.3 / 30 * 60).ceil());
    final roadKilometers = (kilometers * 1.3).toStringAsFixed(1);
    return 'Aproximadamente $minutes min ($roadKilometers km estimados)';
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    final center = _car ?? destination ?? _fallbackCenter;
    final markers = <Marker>[
      if (_car != null)
        Marker(
          point: _car!,
          width: 48,
          height: 48,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 36),
        ),
      if (destination != null)
        Marker(
          point: destination,
          width: 48,
          height: 48,
          child: const Icon(Icons.flag, color: Colors.red, size: 34),
        ),
      if (_me != null)
        Marker(
          point: _me!,
          width: 48,
          height: 48,
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.green,
            size: 36,
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Rastreamento da carona')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'br.urimove.uri_move_app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          const Text('© OpenStreetMap contributors'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _car == null
                      ? 'Aguardando posição do motorista.'
                      : 'Carro localizado${_updatedAt == null ? '' : ' · atualizado às ${TimeOfDay.fromDateTime(_updatedAt!.toLocal()).format(context)}'}',
                ),
                if (_estimate(destination) case final estimate?)
                  Text('Até o destino: $estimate'),
                if (_estimate(_me) case final estimate?)
                  Text('Até você: $estimate'),
                const Text(
                  'Estimativa baseada na distância; trânsito e trajeto podem alterar o tempo.',
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 10),
                if (_isDriver)
                  FilledButton.icon(
                    onPressed: _sharing ? _stopSharing : _startSharing,
                    icon: Icon(
                      _sharing ? Icons.location_off : Icons.location_on,
                    ),
                    label: Text(
                      _sharing
                          ? 'Parar de compartilhar'
                          : 'Compartilhar minha localização',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _locateMe,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Mostrar minha posição e tempo até mim'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
