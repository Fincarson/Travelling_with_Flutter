import 'package:flutter/material.dart';

import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/itinerary/presentation/pages/new_itinerary_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/search/presentation/pages/search_page.dart';

enum AppNavigationLabel {
  home,
  search,
  itinerary,
  chat,
  profile,
}

class AppNavigationDestination {
  const AppNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final AppNavigationLabel label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

class AppNavigationDestinations {
  static const items = <AppNavigationDestination>[
    AppNavigationDestination(
      label: AppNavigationLabel.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      page: HomePage(),
    ),
    AppNavigationDestination(
      label: AppNavigationLabel.search,
      icon: Icons.search,
      selectedIcon: Icons.search,
      page: SearchPage(),
    ),
    AppNavigationDestination(
      label: AppNavigationLabel.itinerary,
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      page: NewItineraryPage(),
    ),
    AppNavigationDestination(
      label: AppNavigationLabel.chat,
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      page: ChatPage(),
    ),
    AppNavigationDestination(
      label: AppNavigationLabel.profile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      page: ProfilePage(),
    ),
  ];
}
