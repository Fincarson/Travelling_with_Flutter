import 'package:flutter/material.dart';
import 'package:flutter_app/app/app_restart_scope.dart';
import 'package:flutter_app/core/errors/app_error.dart';
import 'package:flutter_app/shared/widgets/app_error_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('page error back arrow uses router fallback navigation', (
    tester,
  ) async {
    late GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => router.go('/broken'),
                child: const Text('Open broken page'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/broken',
          builder: (context, state) => const UnexpectedErrorView(
            error: AppErrorData(
              code: 'page-build-failed',
              details: 'The page could not be built.',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Open broken page'));
    await tester.pumpAndSettle();
    expect(
      find.text('An unexpected error has occurred. Please try again later.'),
      findsOneWidget,
    );
    final backButton = find.byTooltip('Back');
    expect(backButton, findsOneWidget);
    expect(tester.getTopLeft(backButton).dx, lessThan(32));
    expect(tester.getTopLeft(backButton).dy, lessThan(32));

    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.text('Open broken page'), findsOneWidget);
  });

  testWidgets('minor widget failures do not show the error page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 120,
              child: PageErrorFallback(
                error: AppErrorData(
                  code: 'minor-widget-failed',
                  details: 'A small widget could not be built.',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('An unexpected error has occurred. Please try again later.'),
      findsNothing,
    );
  });

  testWidgets('page-sized widget failures show the error page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PageErrorFallback(
          error: AppErrorData(
            code: 'page-build-failed',
            details: 'Most of the page could not be built.',
          ),
        ),
      ),
    );

    expect(
      find.text('An unexpected error has occurred. Please try again later.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Back'), findsOneWidget);
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
