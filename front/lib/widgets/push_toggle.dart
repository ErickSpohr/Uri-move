import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/push_notifications.dart';
import '../state/auth_controller.dart';

/// Ativa/desativa notificações do navegador com o app fechado (Web Push).
class PushToggleTile extends StatefulWidget {
  const PushToggleTile({super.key});

  @override
  State<PushToggleTile> createState() => _PushToggleTileState();
}

class _PushToggleTileState extends State<PushToggleTile> {
  bool _enabled = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// Se já existe assinatura no navegador, reenvia ao servidor para mantê-la
  /// associada à conta atual.
  Future<void> _sync() async {
    if (!pushSupported()) {
      setState(() => _busy = false);
      return;
    }
    final api = context.read<AuthController>().api;
    try {
      final subscription = await pushCurrentSubscription();
      if (subscription != null) {
        await api.savePushSubscription(subscription);
      }
      if (mounted) {
        setState(() => _enabled = subscription != null);
      }
    } catch (_) {
      // Falha silenciosa: o usuário ainda pode ativar manualmente.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggle(bool value) async {
    final api = context.read<AuthController>().api;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (value) {
        final subscription = await pushSubscribe(await api.pushPublicKey());
        if (subscription == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão negada. Libere as notificações nas '
                'configurações do navegador.',
              ),
            ),
          );
        } else {
          await api.savePushSubscription(subscription);
          _enabled = true;
        }
      } else {
        final endpoint = await pushUnsubscribe();
        if (endpoint != null) {
          await api.deletePushSubscription(endpoint);
        }
        _enabled = false;
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar as notificações.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!pushSupported()) {
      return const SizedBox.shrink();
    }
    final denied = pushPermission() == 'denied';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications_active_outlined),
        title: const Text('Avisar com o app fechado'),
        subtitle: Text(
          denied
              ? 'Bloqueado no navegador. Libere nas configurações do site.'
              : 'Receba avisos de solicitações, respostas e cancelamentos. '
                    'No iPhone, adicione o app à tela inicial primeiro.',
        ),
        value: _enabled,
        onChanged: _busy || denied ? null : _toggle,
      ),
    );
  }
}
