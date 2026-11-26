import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/map_tiles.dart';

/// Ponto de encontro escolhido no mapa.
class PickupPoint {
  const PickupPoint(this.position, this.label);

  final LatLng position;
  final String? label;
}

/// O passageiro arrasta o mapa até o alfinete central ficar sobre o local de embarque.
class PickupPickerScreen extends StatefulWidget {
  const PickupPickerScreen({
    super.key,
    this.initial,
    this.title = 'Ponto de encontro',
    this.askLabel = true,
  });

  final PickupPoint? initial;
  final String title;

  /// Exibe o campo de referência (ex.: "em frente à padaria").
  final bool askLabel;

  @override
  State<PickupPickerScreen> createState() => _PickupPickerScreenState();
}

class _PickupPickerScreenState extends State<PickupPickerScreen> {
  // Santo Ângelo: centro inicial quando não há posição conhecida.
  static const _fallback = LatLng(-28.3007, -54.2669);

  final _mapController = MapController();
  late final TextEditingController _labelController;
  late LatLng _center;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _center = widget.initial?.position ?? _fallback;
    _labelController = TextEditingController(text: widget.initial?.label ?? '');
    if (widget.initial == null) {
      _useMyLocation();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Sem permissão de localização. Arraste o mapa até o local.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _center = here);
      _mapController.move(here, 17);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Não foi possível obter sua localização. Arraste o mapa até o local.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: widget.initial == null ? 14 : 17,
                    onPositionChanged: (camera, _) => _center = camera.center,
                  ),
                  children: [
                    AppMapTiles.layer(context),
                    AppMapTiles.attribution(),
                  ],
                ),
                // Alfinete fixo no centro; a ponta marca o ponto escolhido.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_pin, size: 48, color: scheme.error),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'pickup-locate',
                    tooltip: 'Usar minha localização',
                    onPressed: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
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
                    'Arraste o mapa até o alfinete ficar sobre o local.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 10),
                  if (widget.askLabel)
                  TextField(
                    controller: _labelController,
                    maxLength: 191,
                    decoration: const InputDecoration(
                      labelText: 'Referência (opcional)',
                      hintText: 'Ex.: em frente à padaria',
                      prefixIcon: Icon(Icons.edit_location_alt_outlined),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      PickupPoint(
                        _center,
                        _labelController.text.trim().isEmpty
                            ? null
                            : _labelController.text.trim(),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar ponto'),
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
