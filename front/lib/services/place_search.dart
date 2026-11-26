import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lugar sugerido no autocompletar de endereço.
class PlaceSuggestion {
  const PlaceSuggestion(this.label, this.latitude, this.longitude);

  final String label;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': latitude,
    'lng': longitude,
  };

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        json['label'] as String? ?? '',
        (json['lat'] as num?)?.toDouble(),
        (json['lng'] as num?)?.toDouble(),
      );
}

/// Busca de lugares pelo Photon (OpenStreetMap), tolerante a texto parcial,
/// com atalhos fixos para os câmpus da URI.
class PlaceSearch {
  PlaceSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Câmpus da URI com coordenadas conferidas no OpenStreetMap.
  static const campuses = [
    PlaceSuggestion('URI Santo Ângelo - Rua Universidade das Missões, Santo Ângelo', -28.27718, -54.27096),
    PlaceSuggestion('URI Cerro Largo - Cerro Largo', -28.14805, -54.73450),
    PlaceSuggestion('URI São Luiz Gonzaga - São Luiz Gonzaga', -28.41091, -54.94894),
    PlaceSuggestion('URI Frederico Westphalen - Frederico Westphalen', -27.36031, -53.40768),
    PlaceSuggestion('URI Erechim - Avenida Sete de Setembro, Erechim', -27.64850, -52.26901),
    PlaceSuggestion('URI Santiago - Santiago', -29.19409, -54.88536),
  ];

  /// Centro padrão do viés de proximidade (Santo Ângelo).
  static const defaultBias = (-28.2994, -54.2632);

  /// Câmpus cujo nome contém todas as palavras da busca (sem acento/caixa).
  static List<PlaceSuggestion> matchCampuses(String query) {
    final words = normalize(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return const [];
    return [
      for (final campus in campuses)
        if (words.every((w) => normalize('${campus.label} campus universidade').contains(w)))
          campus,
    ];
  }

  static String normalize(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString().toLowerCase();
  }

  Future<List<PlaceSuggestion>> search(
    String query, {
    (double, double)? near,
  }) async {
    final bias = near ?? defaultBias;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '8',
      'lat': '${bias.$1}',
      'lon': '${bias.$2}',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Busca de lugares falhou (${response.statusCode}).');
    }
    return parsePhoton(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Converte o GeoJSON do Photon em sugestões legíveis, só do Brasil e sem repetição.
  static List<PlaceSuggestion> parsePhoton(Map<String, dynamic> json) {
    final seen = <String>{};
    final results = <PlaceSuggestion>[];
    for (final feature in (json['features'] as List? ?? const [])) {
      final properties = Map<String, dynamic>.from(
        (feature as Map)['properties'] as Map? ?? const {},
      );
      if ((properties['countrycode'] as String?)?.toUpperCase() != 'BR') continue;
      final coordinates = (feature['geometry'] as Map?)?['coordinates'] as List?;
      if (coordinates == null || coordinates.length < 2) continue;

      final name = properties['name'] as String?;
      final street = properties['street'] as String?;
      final number = properties['housenumber'] as String?;
      final district = (properties['district'] ?? properties['locality']) as String?;
      final city = (properties['city'] ?? properties['county']) as String?;
      final state = properties['state'] as String?;

      final streetLine = [street, number].whereType<String>().join(', ');
      final parts = <String>[
        if (name != null && name != street) name,
        if (streetLine.isNotEmpty) streetLine else if (name == street && name != null) name,
        if (district != null) district,
        if (city != null && city != name) city,
        if (city == null && state != null) state,
      ];
      final label = parts.join(' - ');
      if (label.isEmpty || !seen.add(label)) continue;
      results.add(
        PlaceSuggestion(
          label,
          (coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble(),
        ),
      );
    }
    return results;
  }
}
