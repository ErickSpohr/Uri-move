import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/in_app_notification.dart';
import '../widgets/push_toggle.dart';
import 'ride_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _items = [];
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
      final items = await api.notifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Falha ao carregar notificações.';
        _loading = false;
      });
    }
  }

  Future<void> _markAll() async {
    try {
      await context.read<AuthController>().api.markAllNotificationsRead();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = [
          for (final n in _items)
            NotificationItem(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              payload: n.payload,
              isRead: true,
              createdAt: n.createdAt,
            ),
        ];
      });
    } catch (_) {
      if (mounted) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_items.any((n) => !n.isRead))
            TextButton(onPressed: _markAll, child: const Text('Ler todas')),
        ],
      ),
      body: Column(
        children: [
          const PushToggleTile(),
          const NativePushTile(),
          const _RideAlertsTile(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              message: 'Nenhuma notificação por enquanto.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final rideId = item.payload?['ride_id'];
                  return _NotificationCard(
                    item: item,
                    onTap: rideId is int
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RideDetailScreen(rideId: rideId),
                            ),
                          )
                        : null,
                  );
                },
              ),
            );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, this.onTap});

  final NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
        decoration: item.isRead
            ? null
            : BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.isRead
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                // Mesmo ícone por tipo usado no aviso do topo da tela.
                InAppNotification.iconFor(item.type),
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.body.isNotEmpty
                        ? item.body
                        : notificationTypeLabel(item.type),
                    style: TextStyle(
                      fontWeight: item.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatDate(item.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead)
              Semantics(
                label: 'Não lida',
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Avisos "Me avise quando aparecer" ativos, com opção de apagar.
class _RideAlertsTile extends StatefulWidget {
  const _RideAlertsTile();

  @override
  State<_RideAlertsTile> createState() => _RideAlertsTileState();
}

class _RideAlertsTileState extends State<_RideAlertsTile> {
  List<RideAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final alerts = await context.read<AuthController>().api.rideAlerts();
      if (mounted) setState(() => _alerts = alerts);
    } catch (_) {
      // Lista opcional: sem conexão, simplesmente não aparece.
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Avisos de carona',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Você recebe uma notificação quando alguém publicar uma carona '
                  'parecida. Cada aviso vale por 30 dias.',
                  textAlign: TextAlign.center,
                ),
              ),
              if (_alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum aviso ativo.'),
                ),
              for (final alert in _alerts)
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(alert.description),
                  trailing: IconButton(
                    tooltip: 'Apagar aviso',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await context
                          .read<AuthController>()
                          .api
                          .deleteRideAlert(alert.id)
                          .catchError((_) {});
                      setState(
                        () => _alerts = _alerts
                            .where((a) => a.id != alert.id)
                            .toList(),
                      );
                      setSheetState(() {});
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_alerts.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.manage_search),
        title: const Text('Avisos de carona'),
        subtitle: Text(
          _alerts.length == 1
              ? '1 aviso ativo'
              : '${_alerts.length} avisos ativos',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openSheet,
      ),
    );
  }
}
