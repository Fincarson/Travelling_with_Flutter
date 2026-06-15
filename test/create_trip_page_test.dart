import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/performance/app_performance.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preset in PerformancePreset.values) {
    testWidgets('create trip opens with ${preset.name} performance', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final performance = AppPerformanceController(
        initialSettings: AppPerformanceSettings.forPreset(preset),
      );
      addTearDown(performance.dispose);

      await tester.pumpWidget(
        PerformanceScope(
          controller: performance,
          child: MaterialApp(
            theme: TravelAgentTheme.light(),
            home: Scaffold(
              body: CreateTripScreen(
                profileLanguage: 'en',
                savedTrips: const [],
                onBack: () {},
                onGenerate: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('How do you want to start?'), findsOneWidget);
      expect(find.text('AI Trip Builder'), findsOneWidget);
      expect(find.text('Create Manually'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('create trip planning choices open without startup services', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    addTearDown(performance.dispose);

    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: Scaffold(
            body: CreateTripScreen(
              profileLanguage: 'en',
              savedTrips: const [],
              onBack: () {},
              onGenerate: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('AI Trip Builder'));
    await tester.pumpAndSettle();
    expect(find.text('AI setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('manual and template planners open from the landing page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    addTearDown(performance.dispose);

    Widget page() => PerformanceScope(
      controller: performance,
      child: MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(
          body: CreateTripScreen(
            profileLanguage: 'en',
            savedTrips: const [],
            onBack: () {},
            onGenerate: (_) async {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(page());
    await tester.pump();
    await tester.tap(find.text('Create Manually'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Basics'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(page());
    await tester.pump();
    final templateOption = find.widgetWithText(
      CreateOptionCard,
      'Use a Template',
    );
    await tester.ensureVisible(templateOption);
    await tester.pump();
    tester.widget<CreateOptionCard>(templateOption).onTap();
    await tester.pumpAndSettle();
    expect(find.text('Trip templates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggested destination opens directly in the AI builder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    addTearDown(performance.dispose);

    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: Scaffold(
            body: CreateTripScreen(
              profileLanguage: 'en',
              savedTrips: const [],
              initialDestination: 'Kyoto, Japan',
              onBack: () {},
              onGenerate: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI Trip Builder'), findsOneWidget);
    expect(find.text('Kyoto, Japan'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
