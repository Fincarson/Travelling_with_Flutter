import 'package:flutter/material.dart';

import '../../core/localization/app_localizations_extension.dart';
import 'app_navigation_destination.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const destinations = AppNavigationDestinations.items;
    final l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (final destination in destinations) destination.page,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: switch (destination.label) {
                AppNavigationLabel.home => l10n.home,
                AppNavigationLabel.search => l10n.search,
                AppNavigationLabel.itinerary => l10n.itinerary,
                AppNavigationLabel.chat => l10n.chat,
                AppNavigationLabel.profile => l10n.profile,
              },
            ),
        ],
      ),
    );
  }
}
