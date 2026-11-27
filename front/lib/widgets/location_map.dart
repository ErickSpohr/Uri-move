import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/permissions.dart';
import '../core/theme.dart';
import 'map_tiles.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({super.key, this.height = 210, this.scrollFriendly = false});

  final double height;

  /// Dentro de uma página rolável: sem arrastar o mapa (o gesto rola a página).
  final bool scrollFriendly;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  static const _fallbackCenter = LatLng(-28.3007, -54.2669);

  final _mapController = MapController();

  Position? _position;
  bool _locating = false;

  /// MapController só pode ser usado depois que o FlutterMap foi desenhado.
  bool _mapReady = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateUser());
  }

  Future<void> _locateUser() async {
    if (_locating) {
      return;
    }

    setState(() {
      _locating = true;
      _locationMessage = null;
    });

    try {
      final position = await _determinePosition();
      if (!mounted) {
        return;
      }

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _position = position;
        _locating = false;
      });
      if (_mapReady) _mapController.move(point, 16);
    } on _LocationFailure catch (error) {
      _showLocationError(error.message);
    } on TimeoutException {
      _showLocationError(
        'Não foi possível obter sua localização a tempo. Tente novamente.',
      );
    } catch (_) {
      _showLocationError(
        'Não foi possível acessar sua localização. Verifique a permissão.',
      );
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _LocationFailure(
        'Ative a localização do dispositivo para ver onde você está.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await AppPermissions.requestLocation();
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationFailure(
        'Permita o acesso à localização para centralizar o mapa.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationFailure(
        'A localização foi bloqueada. Libere a permissão no navegador.',
      );
    }

    final requestTimeout = kIsWeb
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        // Navegadores em computadores normalmente estimam a posição pela
        // rede e podem nunca atender a uma solicitação de alta precisão.
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: requestTimeout,
      ),
    ).timeout(requestTimeout + const Duration(seconds: 5));
  }

  void _showLocationError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      _locationMessage = message;
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final currentPoint = position == null
        ? null
        : LatLng(position.latitude, position.longitude);

    return Semantics(
      label: 'Mapa interativo da sua localização',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _fallbackCenter,
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    final position = _position;
                    if (position != null) {
                      _mapController.move(
                        LatLng(position.latitude, position.longitude),
                        16,
                      );
                    }
                  },
                  interactionOptions: InteractionOptions(
                    flags: widget.scrollFriendly
                        ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                        : InteractiveFlag.all,
                  ),
                ),
                children: [
                  AppMapTiles.layer(context),
                  if (currentPoint != null) ...[
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: currentPoint,
                          radius: position!.accuracy.clamp(10, 500),
                          useRadiusInMeter: true,
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderColor: AppTheme.primary.withValues(alpha: 0.35),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentPoint,
                          width: 46,
                          height: 46,
                          child: const _CurrentLocationMarker(),
                        ),
                      ],
                    ),
                  ],
                  AppMapTiles.attribution(),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Usar minha localização',
                    onPressed: _locating ? null : _locateUser,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: AppTheme.primary,
                          ),
                  ),
                ),
              ),
              if (_locationMessage != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            size: 20,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationMessage!,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          TextButton(
                            onPressed: _locateUser,
                            child: const Text('Tentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sua localização atual',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.message);

  final String message;
}
