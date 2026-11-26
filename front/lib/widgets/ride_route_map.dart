import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../services/place_search.dart';
import '../services/route_service.dart';
import 'map_tiles.dart';

/// Mapa do trajeto da carona (origem → destino) com a rota de carro.
/// Sem coordenadas salvas, tenta localizar origem e destino pelo texto.
class RideRouteMap extends StatefulWidget {
  const RideRouteMap({super.key, required this.ride, this.height = 220});

  final Ride ride;
  final double height;

  @override
  State<RideRouteMap> createState() => _RideRouteMapState();
}

class _RideRouteMapState extends State<RideRouteMap> {
  LatLng? _origin;
  LatLng? _destination;
  RouteResult? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RideRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O detalhe recarrega a carona periodicamente; só refaz se o trajeto mudou.
    if (oldWidget.ride.origin != widget.ride.origin ||
        oldWidget.ride.destination != widget.ride.destination) {
      _load();
    }
  }

  Future<LatLng?> _resolve(double? lat, double? lng, String text) async {
    if (lat != null && lng != null) return LatLng(lat, lng);
    final campus = PlaceSearch.matchCampuses(text).firstOrNull;
    if (campus != null) return LatLng(campus.latitude!, campus.longitude!);
    try {
      final found = (await PlaceSearch().search(text)).firstOrNull;
      return found == null ? null : LatLng(found.latitude!, found.longitude!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final ride = widget.ride;
    final results = await Future.wait([
      _resolve(ride.originLat, ride.originLng, ride.origin),
      _resolve(ride.destinationLat, ride.destinationLng, ride.destination),
    ]);
    final origin = results[0];
    final destination = results[1];
    final route = origin != null && destination != null
        ? await RouteService().route(origin, destination)
        : null;
    if (!mounted) return;
    setState(() {
      _origin = origin;
      _destination = destination;
      _route = route;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final origin = _origin;
    final destination = _destination;

    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (origin == null && destination == null) {
      return const SizedBox.shrink();
    }

    final points = [if (origin != null) origin, if (destination != null) destination];
    final route = _route;
    final summary = route == null
        ? null
        : '${(route.distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km · '
              'cerca de ${(route.durationSeconds / 60).ceil()} min de carro';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: widget.height,
            child: Semantics(
              label: 'Mapa do trajeto de ${widget.ride.origin} até ${widget.ride.destination}',
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 13,
                  initialCameraFit: points.length < 2
                      ? null
                      : CameraFit.coordinates(
                          coordinates: [...points, if (route != null) ...route.points],
                          padding: const EdgeInsets.all(36),
                          maxZoom: 16,
                        ),
                  // Sem arrastar: o gesto vertical continua rolando a página.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  AppMapTiles.layer(context),
                  if (route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.points,
                          strokeWidth: 5,
                          color: scheme.primary.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (origin != null)
                        Marker(
                          point: origin,
                          width: 30,
                          height: 30,
                          child: Icon(Icons.trip_origin, color: scheme.primary, size: 26),
                        ),
                      if (destination != null)
                        Marker(
                          point: destination,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.flag, color: Colors.red, size: 32),
                        ),
                    ],
                  ),
                  AppMapTiles.attribution(),
                ],
              ),
            ),
          ),
        ),
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              summary,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
