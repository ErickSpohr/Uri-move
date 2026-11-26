import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final void Function(double? latitude, double? longitude)? onSelected;

  /// Oferece "Usar minha localização atual" e define o texto preenchido.
  final CurrentLocationMode currentLocation;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

enum CurrentLocationMode {
  /// Sem opção de localização atual.
  none,

  /// Preenche o endereço (rua, número, bairro, cidade): para publicar carona.
  address,

  /// Preenche só a cidade: para a busca, que compara texto da origem.
  city,
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  static const _historyKey = 'address_search_history';
  static const _userAgent = 'URI Move/1.0 (address autocomplete)';

  final _focusNode = FocusNode();
  Timer? _debounce;
  List<String> _suggestions = [];
  Map<String, (double, double)> _coordinates = {};
  List<String> _history = [];
  bool _loading = false;
  bool _locating = false;
  bool _showSuggestions = false;

  /// Suprime a busca disparada pelo listener ao preencher o texto via GPS.
  bool _settingText = false;
  int _requestId = 0;

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
    if (mounted) {
      setState(() {
        _history = preferences.getStringList(_historyKey) ?? [];
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && widget.controller.text.trim().isEmpty) {
      _showHistory();
    } else if (!_focusNode.hasFocus) {
      // Aguarda o toque na sugestão antes de ocultar a lista.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showSuggestions = false);
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
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _showSuggestions = true;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  bool get _offersCurrentLocation =>
      widget.currentLocation != CurrentLocationMode.none;

  void _showHistory() {
    if (!_focusNode.hasFocus) return;
    setState(() {
      _suggestions = _history.take(5).toList();
      // Com campo vazio a lista também mostra "Usar minha localização atual".
      _showSuggestions = _suggestions.isNotEmpty || _offersCurrentLocation;
      _loading = false;
    });
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
        permission = await Geolocator.requestPermission();
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
      final label = await _reverseGeocode(position) ?? 'Minha localização';
      if (!mounted) return;
      _settingText = true;
      widget.controller.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      _settingText = false;
      widget.onSelected?.call(position.latitude, position.longitude);
      _focusNode.unfocus();
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

  /// Endereço legível da posição (Nominatim /reverse); null se falhar.
  Future<String?> _reverseGeocode(Position position) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${position.latitude}',
        'lon': '${position.longitude}',
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
      final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
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

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    Position? position;
    try {
      if (await Geolocator.isLocationServiceEnabled() &&
          await Geolocator.checkPermission() != LocationPermission.denied &&
          await Geolocator.checkPermission() !=
              LocationPermission.deniedForever) {
        position = await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      // As sugestões continuam funcionando sem usar a localização.
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      'countrycodes': 'br',
      if (position != null) 'viewbox': _viewbox(position),
      if (position != null) 'bounded': '0',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('Place search failed');
      final places = (jsonDecode(response.body) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final results = places
          .map((place) => place['display_name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      final coordinates = <String, (double, double)>{};
      for (final place in places) {
        final name = place['display_name'] as String?;
        final latitude = double.tryParse('${place['lat']}');
        final longitude = double.tryParse('${place['lon']}');
        if (name != null && latitude != null && longitude != null) {
          coordinates[name] = (latitude, longitude);
        }
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = results;
        _coordinates = coordinates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = [];
        _loading = false;
      });
    }
  }

  String _viewbox(Position position) {
    const delta = 0.5;
    final west = position.longitude - delta;
    final east = position.longitude + delta;
    final north = position.latitude + delta;
    final south = position.latitude - delta;
    return '$west,$north,$east,$south';
  }

  Future<void> _select(String suggestion) async {
    widget.controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    final coordinates = _coordinates[suggestion];
    widget.onSelected?.call(coordinates?.$1, coordinates?.$2);
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);

    final history = [
      suggestion,
      ..._history.where((item) => item != suggestion),
    ].take(8).toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_historyKey, history);
    if (mounted) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading || _locating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _offersCurrentLocation
                ? IconButton(
                    tooltip: 'Usar minha localização atual',
                    icon: const Icon(Icons.my_location),
                    onPressed: _useCurrentLocation,
                  )
                : null,
          ),
        ),
        if (_showSuggestions &&
            (_suggestions.isNotEmpty ||
                (_offersCurrentLocation && widget.controller.text.trim().isEmpty)))
          Card(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_offersCurrentLocation && widget.controller.text.trim().isEmpty)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.my_location,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Usar minha localização atual'),
                    onTap: _useCurrentLocation,
                  ),
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      _history.contains(suggestion)
                          ? Icons.history
                          : Icons.location_on_outlined,
                    ),
                    title: Text(
                      suggestion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _select(suggestion),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
