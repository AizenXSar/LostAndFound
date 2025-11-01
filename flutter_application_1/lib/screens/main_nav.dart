import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'lost_items_screen.dart';
import 'found_items_screen.dart';
import 'profile_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    LostItemsScreen(),
    FoundItemsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No per-page app bars here; each page can have its own if needed
      body: IndexedStack(index: _currentIndex, children: _pages),
      // Floating-style persistent bottom nav
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: 'Lost',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inbox_outlined),
                    selectedIcon: Icon(Icons.inbox),
                    label: 'Found',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
