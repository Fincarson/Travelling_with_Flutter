import 'package:flutter/material.dart';

import '../core/constants/app_routes.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/itinerary/presentation/pages/new_itinerary_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../shared/navigation/app_navigation_shell.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return MaterialPageRoute(builder: (_) => const AppNavigationShell());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.search:
        return MaterialPageRoute(builder: (_) => const SearchPage());
      case AppRoutes.newItinerary:
        return MaterialPageRoute(builder: (_) => const NewItineraryPage());
      case AppRoutes.chat:
        return MaterialPageRoute(builder: (_) => const ChatPage());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      default:
        return MaterialPageRoute(builder: (_) => const AppNavigationShell());
    }
  }
}
