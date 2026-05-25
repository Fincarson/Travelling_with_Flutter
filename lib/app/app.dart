import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/account_gate.dart';
import '../features/travel_clone/travel_agent_app.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remix Travel Agent',
      debugShowCheckedModeBanner: false,
      theme: TravelAgentTheme.light(),
      home: AccountGate(),
    );
  }
}
