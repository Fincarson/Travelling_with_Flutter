import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/account_gate.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => AccountGate());
  }
}
