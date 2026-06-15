import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/performance/app_performance.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: const _FavoriteHomeHost(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('favorite place updates immediately and remains selected', (
    tester,
  ) async {
    await pumpHome(tester);
    final favoriteButton = find.byKey(
      const ValueKey('favorite-place-kyoto-japan'),
    );
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pump();

    expect(
      find.descendant(
        of: favoriteButton,
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('Kyoto, Japan saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('place details use a sliding responsive panel', (tester) async {
    await pumpHome(tester);
    final details = find.widgetWithText(OutlinedButton, 'Details').first;
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Add to a new trip'), findsOneWidget);
    expect(find.byTooltip('Close details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FavoriteHomeHost extends StatefulWidget {
  const _FavoriteHomeHost();

  @override
  State<_FavoriteHomeHost> createState() => _FavoriteHomeHostState();
}

class _FavoriteHomeHostState extends State<_FavoriteHomeHost> {
  var _user = const UserProfile(
    name: 'Nicolas',
    email: 'nicolas@example.com',
    interests: ['Culture'],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DashboardScreen(
        user: _user,
        trips: const [],
        activeTrip: null,
        onCreate: _doNothing,
        onOpenTrip: (_) {},
        onStartTrip: (_) {},
        onAskAi: (_) {},
        onOpenMap: _doNothing,
        onOpenInfo: _doNothing,
        onOpenTranslate: _doNothing,
        onOpenNotifications: _doNothing,
        onToggleFavoritePlace: (destination) async {
          setState(() {
            _user = _user.copyWith(
              favoritePlaces: [FavoritePlace.fromDestination(destination)],
            );
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${destination.name} saved')));
        },
      ),
    );
  }
}

void _doNothing() {}
