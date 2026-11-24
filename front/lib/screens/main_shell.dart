import 'package:flutter/material.dart';

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
  int _index = 0;

  void _goTo(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      const MyRidesScreen(),
      CreateRideScreen(onCreated: () => _goTo(1)),
      ConversationsScreen(active: _index == 3),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explorar',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Minhas caronas',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Publicar',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Conversas',
            ),
            NavigationDestination(
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
