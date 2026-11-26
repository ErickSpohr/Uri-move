import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Rota de carro calculada pelo servidor público do OSRM (dados OpenStreetMap).
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class RouteService {
  RouteService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  final http.Client _client;

  /// Retorna null se o serviço falhar; a tela usa a estimativa em linha reta.
  Future<RouteResult?> route(LatLng from, LatLng to) async {
    // OSRM recebe as coordenadas na ordem longitude,latitude.
    final uri = Uri.parse(
      '$_baseUrl/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}?overview=full&geometries=geojson',
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static RouteResult? parse(Map<String, dynamic> json) {
    final routes = json['routes'];
    if (json['code'] != 'Ok' || routes is! List || routes.isEmpty) {
      return null;
    }
    final route = routes.first as Map<String, dynamic>;
    final coordinates =
        (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    return RouteResult(
      points: [
        for (final c in coordinates)
          LatLng(
            ((c as List)[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
      ],
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}
