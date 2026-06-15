import 'package:flutter/material.dart';
import 'package:flutter_app/app/app_restart_scope.dart';
import 'package:flutter_app/core/errors/app_error.dart';
import 'package:flutter_app/shared/widgets/app_error_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unexpected error hides raw details until expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnexpectedErrorView(
          error: AppErrorData(
            code: 'invalid-set-state',
            details: 'setState() called after dispose',
          ),
        ),
      ),
    );

    expect(
      find.text('An unexpected error has occurred. Please try again later.'),
      findsOneWidget,
    );
    expect(find.text('Error code: invalid-set-state'), findsOneWidget);
    expect(find.text('setState() called after dispose'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('setState() called after dispose'), findsOneWidget);
  });

  testWidgets('unexpected error can return to home', (tester) async {
    var wentHome = false;

    await tester.pumpWidget(
      MaterialApp(
        home: UnexpectedErrorView(
          error: const AppErrorData(code: 'unexpected-error', details: 'Boom'),
          onGoHome: () => wentHome = true,
        ),
      ),
    );

    await tester.tap(find.text('Back to home'));
    await tester.pump();

    expect(wentHome, isTrue);
  });

  testWidgets('restart scope recreates the full child tree', (tester) async {
    var initializationCount = 0;

    await tester.pumpWidget(
      AppRestartScope(
        child: MaterialApp(
          home: _RestartProbe(onInitialize: () => initializationCount++),
        ),
      ),
    );

    expect(initializationCount, 1);
    await tester.tap(find.text('Restart'));
    await tester.pump();
    expect(initializationCount, 2);
  });
}

class _RestartProbe extends StatefulWidget {
  const _RestartProbe({required this.onInitialize});

  final VoidCallback onInitialize;

  @override
  State<_RestartProbe> createState() => _RestartProbeState();
}

class _RestartProbeState extends State<_RestartProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInitialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => AppRestartScope.restart(context),
          child: const Text('Restart'),
        ),
      ),
    );
  }
}
