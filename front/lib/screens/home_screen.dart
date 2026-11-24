import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
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
    }
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LocationMap(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF3D5A80),
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
        children: const [
          SizedBox(height: 100),
          EmptyState(
            icon: Icons.no_transfer_rounded,
            message: 'Nenhuma carona encontrada para hoje.\nAjuste os filtros e tente de novo.',
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
