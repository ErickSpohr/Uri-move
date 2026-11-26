import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
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

class _MainShellState extends State<MainShell> {
  static const Duration _unreadPollInterval = Duration(seconds: 30);

  int _index = 0;
  ChatUnread _unread = const ChatUnread();
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _unreadTimer = Timer.periodic(_unreadPollInterval, (_) => _refreshUnread());
  }

  @override
  void dispose() {
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
        bottomNavigationBar: NavigationBar(
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
              label: 'Minhas caronas',
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
      ),
    );
  }
}
