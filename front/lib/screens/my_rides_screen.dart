import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/ride_card.dart';
import 'ride_detail_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _DrivenList _driven;
  late final _JoinedList _joined;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _driven = _DrivenList(key: const ValueKey('driven'));
    _joined = _JoinedList(key: const ValueKey('joined'));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas caronas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Como motorista'),
            Tab(text: 'Como passageiro'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_driven, _joined],
      ),
    );
  }
}

class _RideListBase extends StatefulWidget {
  const _RideListBase({super.key, required this.load});

  final Future<List<Ride>> Function(AuthController auth) load;

  @override
  State<_RideListBase> createState() => _RideListBaseState();
}

class _RideListBaseState extends State<_RideListBase> {
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
      final auth = context.read<AuthController>();
      final rides = await widget.load(auth);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_rides.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_car_outlined,
        message: 'Nenhuma carona encontrada.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}

class _DrivenList extends _RideListBase {
  _DrivenList({super.key}) : super(load: (auth) => auth.api.myRides());
}

class _JoinedList extends _RideListBase {
  _JoinedList({super.key}) : super(load: (auth) => auth.api.myJoinedRides());
}
