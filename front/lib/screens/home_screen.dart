import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/loading_indicator.dart';
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

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _auth.dataVersion.addListener(_reloadSilently);
    _load();
  }

  void _reloadSilently() => _load(silent: true);

  /// [silent] mantém a lista atual na tela enquanto recarrega.
  Future<void> _load({bool silent = false}) async {
    setState(() {
      _loading = !silent || _rides.isEmpty;
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
    _auth.dataVersion.removeListener(_reloadSilently);
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
      body: Builder(
        builder: (context) {
          // A página inteira rola: busca, mapa e lista. Antes a busca e o mapa
          // ficavam fixos e a lista sobrava numa faixa estreita no rodapé.
          // Com o teclado aberto mapa e lista somem para as sugestões caberem;
          // a busca é o primeiro sliver nos dois estados, então mantém o foco.
          final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
          return RefreshIndicator(
            onRefresh: _load,
            color: AppTheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildSearchBar(context)),
                if (!typing) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: LocationMap(height: 140, scrollFriendly: true),
                    ),
                  ),
                  ..._buildListSlivers(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Um campo por linha: lado a lado o texto e a lista de sugestões
          // ficavam espremidos em meia largura no celular.
          AddressAutocompleteField(
            controller: _originController,
            label: 'Origem',
            icon: Icons.trip_origin,
            currentLocation: CurrentLocationMode.city,
          ),
          const SizedBox(height: 10),
          AddressAutocompleteField(
            controller: _destinationController,
            label: 'Destino',
            icon: Icons.location_on_outlined,
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

  List<Widget> _buildListSlivers() {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const [
        SliverToBoxAdapter(child: Center(child: LoadingIndicator())),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }
    if (_rides.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              EmptyState(
                icon: Icons.no_transfer_rounded,
                message:
                    'Nenhuma carona encontrada a partir de '
                    '${formatDate(_date.toIso8601String().split('T').first)}.\n'
                    'Tente outro dia, horário ou destino.',
              ),
              if (_hasExtraFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpar filtros'),
                ),
            ],
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            _rides.length == 1
                ? '1 carona disponível'
                : '${_rides.length} caronas disponíveis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.separated(
          itemCount: _rides.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ride = _rides[index];
            return RideCard(
              ride: ride,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RideDetailScreen(rideId: ride.id),
                ),
              ),
            );
          },
        ),
      ),
    ];
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
