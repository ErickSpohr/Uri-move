import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mapa base do OpenStreetMap (sem chave de acesso). No tema escuro, os tiles
/// são escurecidos no próprio app com o `darkModeTileBuilder` do flutter_map.
class AppMapTiles {
  AppMapTiles._();

  static const _openStreetMap = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static final Uri _osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  /// Camada de mapa conforme o tema atual.
  static TileLayer layer(BuildContext context, {double maxZoom = 19}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: _openStreetMap,
      userAgentPackageName: 'br.urimove.uri_move_app',
      maxZoom: maxZoom,
      tileBuilder: isDark ? darkModeTileBuilder : null,
    );
  }

  /// Créditos exigidos pelos termos de uso do OpenStreetMap.
  static Widget attribution() {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(_osmCopyright),
        ),
      ],
    );
  }
}
