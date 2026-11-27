import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../core/permissions.dart';
import '../services/native_push.dart';
import '../state/auth_controller.dart';
import 'create_ride_screen.dart';
import 'conversations_screen.dart';
import 'home_screen.dart';
import 'my_rides_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static const Duration _unreadPollInterval = Duration(seconds: 30);

  int _index = 0;
  ChatUnread _unread = const ChatUnread();
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _unreadTimer = Timer.periodic(_unreadPollInterval, (_) => _refreshUnread());
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthController>();
    // Retoma o envio da posição se o motorista tiver carona em andamento.
    auth.locationSharer.sync();
    // Primeiro a localização (mapa, endereço, rastreamento), depois as
    // notificações: o Android só exibe uma caixa de permissão por vez.
    unawaited(() async {
      await AppPermissions.requestLocation().catchError((_) => LocationPermission.denied);
      await NativePush.register(auth.api);
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = context.read<AuthController>();
      auth.locationSharer.sync();
      auth.notifyDataChanged();
      _refreshUnread();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    super.dispose();
  }

  /// Atualiza o resumo de não lidas; falhas são ignoradas (próxima consulta tenta de novo).
  Future<void> _refreshUnread() async {
    try {
      final unread = await context.read<AuthController>().api.chatUnread();
      if (mounted) {
        setState(() => _unread = unread);
      }
    } catch (_) {}
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _refreshUnread();
    // As abas ficam montadas no IndexedStack; o sinal faz cada uma recarregar.
    context.read<AuthController>().notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      const MyRidesScreen(),
      CreateRideScreen(onCreated: () => _goTo(1)),
      ConversationsScreen(
        active: _index == 3,
        unread: _unread,
        onConversationClosed: _refreshUnread,
      ),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: _index != 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          _goTo(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: screens),
        // Faixa acima da barra de navegação: não interfere na área da AppBar.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SharingBanner(),
            NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explorar',
            ),
            const NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Caronas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Publicar',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unread.total > 0,
                label: Text(_unread.total > 99 ? '99+' : '${_unread.total}'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unread.total > 0,
                label: Text(_unread.total > 99 ? '99+' : '${_unread.total}'),
                child: const Icon(Icons.chat_bubble),
              ),
              label: 'Conversas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

/// Faixa exibida ao motorista enquanto a posição é enviada aos passageiros.
class _SharingBanner extends StatelessWidget {
  const _SharingBanner();

  @override
  Widget build(BuildContext context) {
    final sharer = context.read<AuthController>().locationSharer;
    return ListenableBuilder(
      listenable: sharer,
      builder: (context, _) {
        if (!sharer.isSharing) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final error = sharer.error;
        return Material(
          color: error == null ? scheme.primaryContainer : scheme.errorContainer,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    error == null ? Icons.location_on : Icons.location_off,
                    size: 18,
                    color: error == null ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error ?? 'Carona em andamento: sua localização está sendo compartilhada.',
                      style: TextStyle(
                        fontSize: 13,
                        color: error == null ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                  if (error != null && sharer.rideId != null)
                    TextButton(
                      onPressed: () => sharer.start(sharer.rideId!),
                      child: const Text('Tentar de novo'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
