import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../models/models.dart';
import '../core/api.dart';
import '../services/api_repository.dart';
import '../services/ride_location_sharer.dart';
import '../services/route_service.dart';
import '../state/auth_controller.dart';
import '../widgets/map_tiles.dart';

/// Ponto de encontro de um passageiro aceito, vindo de GET /rides/{id}/location.
class TrackingStop {
  const TrackingStop({
    required this.passengerId,
    required this.passengerName,
    required this.position,
    this.label,
    this.pickedUp = false,
  });

  final int passengerId;
  final String passengerName;
  final LatLng position;
  final String? label;
  final bool pickedUp;

  factory TrackingStop.fromJson(Map<String, dynamic> json) => TrackingStop(
    passengerId: json['passenger_id'] as int? ?? 0,
    passengerName: json['passenger_name'] as String? ?? 'Passageiro',
    position: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    label: json['label'] as String?,
    pickedUp: json['picked_up'] as bool? ?? false,
  );
}

/// Acompanhamento da carona em andamento: posição do motorista animada,
/// rota até o próximo ponto e paradas dos passageiros.
class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key, required this.ride});

  final Ride ride;

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _fallbackCenter = LatLng(-28.3007, -54.2669);

  /// Recalcula a rota quando o carro se afasta disto da origem da rota atual.
  static const _rerouteMeters = 150.0;
  static const _rerouteInterval = Duration(seconds: 60);

  final _mapController = MapController();
  final _routes = RouteService();
  final _distance = const Distance();
  late final ApiRepository _api;
  late final bool _isDriver;
  late final int? _myId;

  // Interpolação da posição do carro entre duas leituras do servidor.
  late final AnimationController _carAnimation;
  LatLng? _carFrom;
  LatLng? _carTo;
  double _heading = 0;

  Timer? _refreshTimer;
  LatLng? _me;
  LatLng? _destination;
  List<TrackingStop> _stops = const [];
  DateTime? _updatedAt;

  RouteResult? _route;
  LatLng? _routeFrom;
  LatLng? _routeTarget;
  DateTime? _routeAt;
  bool _routing = false;

  bool _mapReady = false;
  bool _follow = true;
  bool _fetching = false;
  bool _locating = false;

  /// Carona concluída ou cancelada enquanto a tela estava aberta.
  bool _ended = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _api = auth.api;
    _myId = auth.user?.id;
    _isDriver = widget.ride.driver.id == _myId;
    if (_isDriver) {
      // Garante o envio automático mesmo se a tela for aberta direto.
      unawaited(auth.locationSharer.sync());
    }
    // Duração próxima do intervalo de envio do motorista (10 s): o carro anda
    // continuamente em vez de saltar entre leituras.
    _carAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_onCarTick);
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _carAnimation.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ Posição do carro

  LatLng? get _car {
    final from = _carFrom;
    final to = _carTo;
    if (to == null) return null;
    if (from == null) return to;
    final t = Curves.linear.transform(_carAnimation.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  void _onCarTick() {
    final car = _car;
    if (_follow && _mapReady && car != null) {
      _mapController.move(car, _mapController.camera.zoom);
    }
  }

  /// Inicia a animação da posição exibida até [next].
  void _moveCarTo(LatLng? next) {
    if (next == null) {
      _carAnimation.stop();
      _carFrom = null;
      _carTo = null;
      return;
    }
    final current = _car;
    if (current == null) {
      _carFrom = null;
      _carTo = next;
      if (_mapReady) _mapController.move(next, 16);
      return;
    }
    if (_distance.as(LengthUnit.Meter, current, next) < 3) {
      return; // Ruído do GPS: mantém o carro parado.
    }
    _heading = _distance.bearing(current, next);
    _carFrom = current;
    _carTo = next;
    _carAnimation.forward(from: 0);
  }

  // ------------------------------------------------------------ Dados do servidor

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
      final destinationLat = (location['destination_lat'] as num?)?.toDouble();
      final destinationLng = (location['destination_lng'] as num?)?.toDouble();
      setState(() {
        _moveCarTo(
          latitude == null || longitude == null
              ? null
              : LatLng(latitude, longitude),
        );
        _destination = destinationLat == null || destinationLng == null
            ? null
            : LatLng(destinationLat, destinationLng);
        _stops = [
          for (final stop in (location['stops'] as List? ?? const []))
            TrackingStop.fromJson(Map<String, dynamic>.from(stop as Map)),
        ];
        _updatedAt = DateTime.tryParse(location['updated_at'] as String? ?? '');
        _error = null;
      });
      if (_carTo == null && _mapReady) {
        final focus = _target?.position ?? _destination;
        if (focus != null) _mapController.move(focus, 13);
      }
      unawaited(_updateRoute());
    } on ApiException catch (e) {
      if (!mounted) return;
      // 422: o rastreamento só existe com a carona em andamento.
      if (e.statusCode == 422 || e.statusCode == 403) {
        _refreshTimer?.cancel();
        setState(() {
          _ended = true;
          _moveCarTo(null);
          _route = null;
          _error = null;
        });
      } else {
        setState(() => _error = 'Não foi possível atualizar a posição.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível atualizar a posição.');
      }
    } finally {
      _fetching = false;
    }
  }

  /// Próximo ponto relevante: para o motorista, a parada pendente mais próxima;
  /// para o passageiro, o próprio ponto de encontro (ou a posição dele).
  ({LatLng position, String label})? get _target {
    final car = _carTo;
    final pending = _stops.where((s) => !s.pickedUp).toList();
    if (_isDriver) {
      if (pending.isNotEmpty) {
        if (car != null) {
          pending.sort(
            (a, b) => _distance(car, a.position).compareTo(_distance(car, b.position)),
          );
        }
        final next = pending.first;
        return (
          position: next.position,
          label: 'Até ${next.passengerName.split(' ').first}',
        );
      }
    } else {
      final mine = pending.where((s) => s.passengerId == _myId).firstOrNull;
      if (mine != null) {
        return (position: mine.position, label: 'Até o seu ponto de encontro');
      }
      if (_me != null && !_stops.any((s) => s.passengerId == _myId)) {
        return (position: _me!, label: 'Até você');
      }
    }
    final destination = _destination;
    return destination == null
        ? null
        : (position: destination, label: 'Até o destino');
  }

  Future<void> _updateRoute() async {
    final car = _carTo;
    final target = _target?.position;
    if (_routing || car == null || target == null) {
      if (car == null || target == null) _route = null;
      return;
    }
    final stale =
        _route == null ||
        _routeTarget != target ||
        _routeFrom == null ||
        _distance(car, _routeFrom!) > _rerouteMeters ||
        DateTime.now().difference(_routeAt!) > _rerouteInterval;
    if (!stale) return;

    _routing = true;
    try {
      final route = await _routes.route(car, target);
      if (!mounted) return;
      setState(() {
        _route = route;
        _routeFrom = car;
        _routeTarget = target;
        _routeAt = DateTime.now();
      });
    } finally {
      _routing = false;
    }
  }

  // ------------------------------------------------------------ GPS

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do dispositivo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await AppPermissions.requestLocation();
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
        unawaited(_updateRoute());
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

  // ------------------------------------------------------------ Interface

  /// Tempo e distância até o alvo: pela rota quando disponível, senão em linha
  /// reta com fator de sinuosidade 1,3 a 30 km/h.
  String? _eta(LatLng? target) {
    final car = _carTo;
    if (car == null || target == null) return null;
    final route = _route;
    if (route != null && _routeTarget == target) {
      final minutes = max(1, (route.durationSeconds / 60).ceil());
      final km = (route.distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '$minutes min · $km km';
    }
    final km = _distance.as(LengthUnit.Kilometer, car, target) * 1.3;
    final minutes = max(1, (km / 30 * 60).ceil());
    return '~$minutes min · ${km.toStringAsFixed(1).replaceAll('.', ',')} km (estimado)';
  }

  void _recenter() {
    final focus = _car ?? _target?.position ?? _destination;
    setState(() => _follow = true);
    if (focus != null) _mapController.move(focus, 16);
  }

  List<Marker> _stopMarkers(ColorScheme scheme) => [
    for (final stop in _stops)
      Marker(
        point: stop.position,
        width: 120,
        height: 64,
        alignment: Alignment.topCenter,
        child: Semantics(
          label:
              'Ponto de encontro de ${stop.passengerName}${stop.pickedUp ? ', embarcado' : ''}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isDriver)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
                  ),
                  child: Text(
                    stop.passengerName.split(' ').first,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Icon(
                stop.pickedUp ? Icons.check_circle : Icons.person_pin_circle,
                color: stop.pickedUp ? Colors.grey : Colors.green.shade700,
                size: 34,
              ),
            ],
          ),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = _target;
    final destination = _destination;

    return Scaffold(
      appBar: AppBar(title: const Text('Rastreamento da carona')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _carTo ?? destination ?? _fallbackCenter,
                    initialZoom: 14,
                    // Sem rotação do mapa: a seta do carro indica a direção real.
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () => _mapReady = true,
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && _follow) setState(() => _follow = false);
                    },
                  ),
                  children: [
                    AppMapTiles.layer(context),
                    if (_route != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route!.points,
                            strokeWidth: 5,
                            color: scheme.primary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (destination != null)
                          Marker(
                            point: destination,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.flag, color: Colors.red, size: 34),
                          ),
                        ..._stopMarkers(scheme),
                        if (_me != null)
                          Marker(
                            point: _me!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Carro em camada própria, redesenhada a cada quadro da animação.
                    AnimatedBuilder(
                      animation: _carAnimation,
                      builder: (context, _) {
                        final car = _car;
                        if (car == null) return const SizedBox.shrink();
                        return MarkerLayer(
                          markers: [
                            Marker(
                              point: car,
                              width: 44,
                              height: 44,
                              child: Semantics(
                                label: 'Carro do motorista',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: scheme.primary, width: 2),
                                    boxShadow: const [
                                      BoxShadow(blurRadius: 4, color: Colors.black38),
                                    ],
                                  ),
                                  child: Transform.rotate(
                                    angle: _heading * pi / 180,
                                    child: Icon(
                                      Icons.navigation,
                                      color: scheme.primary,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    AppMapTiles.attribution(),
                  ],
                ),
                if (!_follow)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'tracking-recenter',
                      tooltip: 'Centralizar no carro',
                      onPressed: _recenter,
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _ended
                        ? 'A carona foi encerrada ou cancelada.'
                        : _carTo == null
                        ? (_isDriver
                              ? 'Obtendo sua localização...'
                              : 'Aguardando a localização do motorista.')
                        : 'Carro localizado${_updatedAt == null ? '' : ' · atualizado às ${TimeOfDay.fromDateTime(_updatedAt!.toLocal()).format(context)}'}',
                  ),
                  if (target != null && _eta(target.position) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${target.label}: ${_eta(target.position)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_isDriver && _stops.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Paradas: ${_stops.where((s) => s.pickedUp).length} de ${_stops.length} concluídas',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_error!, style: TextStyle(color: scheme.error)),
                    ),
                  const SizedBox(height: 10),
                  if (_isDriver)
                    _DriverSharingStatus(
                      sharer: context.read<AuthController>().locationSharer,
                    )
                  else if (!_stops.any((s) => s.passengerId == _myId))
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _locateMe,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Mostrar minha posição e tempo até mim'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Situação do envio automático da posição, mostrada ao motorista.
class _DriverSharingStatus extends StatelessWidget {
  const _DriverSharingStatus({required this.sharer});

  final RideLocationSharer sharer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sharer,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final error = sharer.error;
        if (error != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(error, style: TextStyle(color: scheme.error)),
              if (sharer.rideId != null)
                TextButton.icon(
                  onPressed: () => sharer.start(sharer.rideId!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
            ],
          );
        }
        return Text(
          sharer.isSharing
              ? 'Sua localização é compartilhada automaticamente enquanto a '
                    'carona estiver em andamento. Mantenha o app aberto.'
              : 'O compartilhamento começa quando a carona é iniciada.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        );
      },
    );
  }
}
