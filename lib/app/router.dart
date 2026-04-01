import 'package:flutter/material.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/auth/presentation/pages/login_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login' : return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/chat'  : return MaterialPageRoute(builder: (_) => const ChatPage());
      default       : return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}