import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/performance/app_performance.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _noopBackgroundGeneration({
  required PlaceSuggestion place,
  required DateTime startDate,
  required DateTime endDate,
  required int budget,
  required String groupType,
  required List<String> preferences,
  required String currency,
  required AppDeviceContext appContext,
  required TripStartLocation? startLocation,
  required List<String> fallbackImages,
  String airline = '',
  String flightCode = '',
}) async {}

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
                onGenerateInBackground: _noopBackgroundGeneration,
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
              onGenerateInBackground: _noopBackgroundGeneration,
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

    Widget page(Key key) => PerformanceScope(
      controller: performance,
      child: MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(
          body: CreateTripScreen(
            key: key,
            profileLanguage: 'en',
            savedTrips: const [],
            onBack: () {},
            onGenerate: (_) async {},
            onGenerateInBackground: _noopBackgroundGeneration,
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(const ValueKey('manual-planner-test')));
    await tester.pump();
    final manualOption = find.widgetWithText(
      CreateOptionCard,
      'Create Manually',
    );
    await tester.ensureVisible(manualOption);
    await tester.pump();
    tester.widget<CreateOptionCard>(manualOption).onTap();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('create-trip-manual-page')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(page(const ValueKey('template-planner-test')));
    await tester.pump();
    final templateOption = find.byKey(
      const ValueKey('create-trip-template-option'),
    );
    await tester.scrollUntilVisible(
      templateOption,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    tester.widget<CreateOptionCard>(templateOption).onTap();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('create-trip-template-page')),
      findsOneWidget,
    );
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
              onGenerateInBackground: _noopBackgroundGeneration,
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
