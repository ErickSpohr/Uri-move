import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/location_map.dart';
import '../widgets/ride_card.dart';
import 'notifications_screen.dart';
import 'ride_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime _date = DateTime.now();

  // Filtros adicionais da busca.
  _Period? _period;
  double? _priceMax;
  bool _womenOnly = false;

  bool get _hasExtraFilters =>
      _period != null || _priceMax != null || _womenOnly;

  List<Ride> _rides = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().api;
      final rides = await api.rides(
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        date: _date.toIso8601String().split('T').first,
        fromTime: _period?.from,
        toTime: _period?.to,
        priceMax: _priceMax,
        womenOnly: _womenOnly,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rides = rides;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Falha de conexão com o servidor.';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
      helpText: 'Data da carona',
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _pickPriceMax() async {
    const options = [0.0, 5.0, 10.0, 15.0, 20.0];
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Preço máximo por vaga',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final value in options)
              ListTile(
                title: Text(value == 0 ? 'Só gratuitas' : 'Até ${formatPrice(value)}'),
                trailing: _priceMax == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
            ListTile(
              title: const Text('Qualquer preço'),
              trailing: _priceMax == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(sheetContext).pop(-1),
            ),
          ],
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    setState(() => _priceMax = picked < 0 ? null : picked);
    _load();
  }

  void _clearFilters() {
    setState(() {
      _originController.clear();
      _destinationController.clear();
      _date = DateTime.now();
      _period = null;
      _priceMax = null;
      _womenOnly = false;
    });
    _load();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar caronas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificações',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          // Com o teclado aberto o mapa é ocultado para manter a lista visível
          // em telas pequenas.
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LocationMap(),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AddressAutocompleteField(
                  controller: _originController,
                  label: 'Origem',
                  icon: Icons.trip_origin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AddressAutocompleteField(
                  controller: _destinationController,
                  label: 'Destino',
                  icon: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    formatDate(_date.toIso8601String().split('T').first),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Buscar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFilterChips(context),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final isWoman = context.watch<AuthController>().user?.isWoman ?? false;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in _Period.values) ...[
            FilterChip(
              label: Text(period.label),
              tooltip: period.description,
              selected: _period == period,
              onSelected: (selected) {
                setState(() => _period = selected ? period : null);
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
          FilterChip(
            avatar: const Icon(Icons.attach_money, size: 18),
            label: Text(
              _priceMax == null
                  ? 'Preço'
                  : _priceMax == 0
                  ? 'Gratuitas'
                  : 'Até ${formatPrice(_priceMax)}',
            ),
            selected: _priceMax != null,
            onSelected: (_) => _pickPriceMax(),
          ),
          if (isWoman) ...[
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.female, size: 18),
              label: const Text('Só mulheres'),
              selected: _womenOnly,
              onSelected: (selected) {
                setState(() => _womenOnly = selected);
                _load();
              },
            ),
          ],
          if (_hasExtraFilters ||
              _originController.text.isNotEmpty ||
              _destinationController.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Limpar'),
              onPressed: _clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    if (_rides.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.no_transfer_rounded,
            message:
                'Nenhuma carona encontrada a partir de '
                '${formatDate(_date.toIso8601String().split('T').first)}.\n'
                'Tente outro dia, horário ou destino.',
          ),
          if (_hasExtraFilters)
            Center(
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpar filtros'),
              ),
            ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = _rides[index];
        return RideCard(
          ride: ride,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RideDetailScreen(rideId: ride.id),
              ),
            );
          },
        );
      },
    );
  }
}

/// Faixas de horário de partida usadas no filtro da busca.
enum _Period {
  morning('Manhã', 'Partidas das 05:00 às 11:59', '05:00', '11:59'),
  afternoon('Tarde', 'Partidas das 12:00 às 17:59', '12:00', '17:59'),
  night('Noite', 'Partidas das 18:00 às 23:59', '18:00', '23:59');

  const _Period(this.label, this.description, this.from, this.to);

  final String label;
  final String description;
  final String from;
  final String to;
}
