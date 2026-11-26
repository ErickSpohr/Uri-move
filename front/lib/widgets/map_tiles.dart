import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mapas base da CARTO (dados OpenStreetMap), sem chave de acesso:
/// Voyager no tema claro e Dark Matter no tema escuro.
class AppMapTiles {
  AppMapTiles._();

  static const _subdomains = ['a', 'b', 'c', 'd'];
  static const _voyager =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const _darkMatter =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  static final Uri _osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
  static final Uri _cartoAttribution = Uri.parse(
    'https://carto.com/attributions',
  );

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Camada de mapa conforme o tema atual.
  static TileLayer layer(BuildContext context, {double maxZoom = 19}) {
    return TileLayer(
      urlTemplate: _isDark(context) ? _darkMatter : _voyager,
      subdomains: _subdomains,
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'br.urimove.uri_move_app',
      maxZoom: maxZoom,
    );
  }

  /// Créditos exigidos pelos termos de uso da CARTO e do OpenStreetMap.
  static Widget attribution() {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(_osmCopyright),
        ),
        TextSourceAttribution('CARTO', onTap: () => launchUrl(_cartoAttribution)),
      ],
    );
  }
}
