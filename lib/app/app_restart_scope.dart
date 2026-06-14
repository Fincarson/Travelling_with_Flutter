import 'package:flutter/material.dart';

import '../core/errors/app_error.dart';

class AppRestartScope extends StatefulWidget {
  const AppRestartScope({required this.child, super.key});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartScopeState>()?._restart();
  }

  @override
  State<AppRestartScope> createState() => _AppRestartScopeState();
}

class _AppRestartScopeState extends State<AppRestartScope> {
  Key _restartKey = UniqueKey();

  void _restart() {
    AppErrorController.clear();
    setState(() => _restartKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _restartKey, child: widget.child);
  }
}
