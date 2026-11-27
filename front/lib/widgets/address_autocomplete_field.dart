import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/permissions.dart';
import '../screens/pickup_picker_screen.dart';
import '../services/place_search.dart';

enum CurrentLocationMode {
  /// Sem opção de localização atual.
  none,

  /// Preenche o endereço (rua, número, bairro, cidade): para publicar carona.
  address,

  /// Preenche só a cidade: para a busca, que compara texto da origem.
  city,
}

/// Campo de endereço com sugestões (Photon/OpenStreetMap), atalhos dos câmpus
/// da URI, histórico, localização atual e escolha manual no mapa.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.onSelected,
    this.currentLocation = CurrentLocationMode.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// Coordenadas do lugar escolhido; (null, null) quando o texto é editado à mão.
  final void Function(double? latitude, double? longitude)? onSelected;

  final CurrentLocationMode currentLocation;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const _historyKey = 'address_history_v2';
  static const _userAgent = 'URI Move/1.0 (address autocomplete)';

  final _focusNode = FocusNode();
  final _places = PlaceSearch();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  List<PlaceSuggestion> _history = [];
  bool _loading = false;
  bool _locating = false;
  bool _showSuggestions = false;
  bool _searchFailed = false;
  int _requestId = 0;

  /// Campo em uso: mostra os atalhos (localização atual / marcar no mapa).
  bool _active = false;

  /// Último texto preenchido pelo app e ponto correspondente. Se o texto atual
  /// for esse, ele não foi digitado pelo usuário e não deve ser preservado.
  String? _filledLabel;
  LatLng? _lastPoint;

  /// Suprime a busca disparada pelo listener quando o texto é preenchido pelo app.
  bool _settingText = false;

  bool get _offersCurrentLocation =>
      widget.currentLocation != CurrentLocationMode.none;

  bool get _isEmpty => widget.controller.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_historyKey) ?? const [];
    final history = <PlaceSuggestion>[];
    for (final item in raw) {
      try {
        history.add(
          PlaceSuggestion.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {}
    }
    if (mounted) setState(() => _history = history);
  }

  Future<void> _remember(PlaceSuggestion place) async {
    final history = [
      place,
      ..._history.where((item) => item.label != place.label),
    ].take(6).toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _historyKey,
      [for (final item in history) jsonEncode(item.toJson())],
    );
    if (mounted) setState(() => _history = history);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() => _active = true);
      if (_isEmpty) _showHistory();
    } else {
      // Aguarda o toque na sugestão/atalho antes de ocultar.
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _showSuggestions = false;
            _active = false;
          });
        }
      });
    }
  }

  void _onTextChanged() {
    if (_settingText) return;
    widget.onSelected?.call(null, null);
    final query = widget.controller.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _showHistory();
      return;
    }
    setState(() {
      // Câmpus aparecem na hora; o restante chega após a busca.
      _suggestions = PlaceSearch.matchCampuses(query);
      _showSuggestions = true;
      _searchFailed = false;
      _loading = query.length >= 3;
    });
    if (query.length >= 3) {
      _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
    }
  }

  void _showHistory() {
    if (!_focusNode.hasFocus) return;
    setState(() {
      _suggestions = _history;
      _showSuggestions = true;
      _searchFailed = false;
      _loading = false;
    });
  }

  Future<(double, double)?> _lastKnownPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await _places.search(
        query,
        near: await _lastKnownPosition(),
      );
      if (!mounted || requestId != _requestId) return;
      final campuses = PlaceSearch.matchCampuses(query);
      setState(() {
        _suggestions = [
          ...campuses,
          ...results.where(
            (r) => !campuses.any((c) => c.label == r.label),
          ),
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _searchFailed = true;
        _loading = false;
      });
    }
  }

  void _fill(PlaceSuggestion place) {
    _filledLabel = place.label;
    _lastPoint = place.latitude == null
        ? null
        : LatLng(place.latitude!, place.longitude!);
    _settingText = true;
    widget.controller.value = TextEditingValue(
      text: place.label,
      selection: TextSelection.collapsed(offset: place.label.length),
    );
    _settingText = false;
    widget.onSelected?.call(place.latitude, place.longitude);
    _focusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _active = false;
    });
    if (place.latitude != null) _remember(place);
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _locating = true;
      _showSuggestions = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Ative a localização do celular.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await AppPermissions.requestLocation();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Permita o acesso à localização para usar esta opção.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      final label = await _reverseGeocode(point) ?? 'Minha localização';
      if (mounted) _fill(PlaceSuggestion(label, point.latitude, point.longitude));
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível obter sua localização.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Endereço não encontrado: o usuário marca o ponto no mapa. O texto já
  /// digitado é mantido (ex.: rua e número), ganhando as coordenadas marcadas.
  Future<void> _pickOnMap() async {
    final text = widget.controller.text.trim();
    // Só preserva texto digitado pelo usuário; um rótulo que o próprio app
    // preencheu (marcação anterior) é substituído pelo endereço do novo ponto.
    final typed = text == _filledLabel ? '' : text;
    _focusNode.unfocus();
    final picked = await Navigator.of(context).push<PickupPoint>(
      MaterialPageRoute(
        builder: (_) => PickupPickerScreen(
          title: widget.label,
          askLabel: false,
          // Reabre no ponto marcado antes, para ajustar em vez de recomeçar.
          initial: _lastPoint == null ? null : PickupPoint(_lastPoint!, null),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final label = typed.isNotEmpty
        ? typed
        : await _reverseGeocode(picked.position) ?? 'Local marcado no mapa';
    if (mounted) {
      _fill(
        PlaceSuggestion(label, picked.position.latitude, picked.position.longitude),
      );
    }
  }

  /// Endereço legível da posição (Nominatim /reverse); null se falhar.
  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final address =
          (jsonDecode(response.body) as Map<String, dynamic>)['address'] as Map?;
      if (address == null) return null;
      final city =
          address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
      if (widget.currentLocation == CurrentLocationMode.city) {
        return city as String?;
      }
      final street = [address['road'], address['house_number']]
          .whereType<String>()
          .join(', ');
      final parts = [
        if (street.isNotEmpty) street,
        address['suburb'] ?? address['neighbourhood'],
        city,
      ].whereType<String>().toList();
      return parts.isEmpty ? null : parts.join(' - ');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Rua, cidade ou "URI"',
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading || _locating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_active)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_offersCurrentLocation)
                  ActionChip(
                    avatar: Icon(Icons.my_location, size: 18, color: scheme.primary),
                    label: const Text('Minha localização'),
                    onPressed: _locating ? null : _useCurrentLocation,
                  ),
                ActionChip(
                  avatar: Icon(Icons.map_outlined, size: 18, color: scheme.primary),
                  label: const Text('Marcar no mapa'),
                  onPressed: _pickOnMap,
                ),
              ],
            ),
          ),
        if (_showSuggestions && (_suggestions.isNotEmpty || _searchFailed))
          Card(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              // Limita a altura para o teclado não esconder a lista toda.
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final suggestion in _suggestions)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        PlaceSearch.campuses.contains(suggestion)
                            ? Icons.school_outlined
                            : _history.contains(suggestion)
                            ? Icons.history
                            : Icons.location_on_outlined,
                      ),
                      title: Text(
                        suggestion.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _fill(suggestion),
                    ),
                  if (_searchFailed)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.wifi_off, color: scheme.error),
                      title: const Text('Não foi possível buscar sugestões agora.'),
                      subtitle: const Text('Use "Marcar no mapa" para escolher o local.'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
