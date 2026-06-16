import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/performance/app_performance.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

const _favoriteTrip = Trip(
  id: 'upcoming',
  destination: 'Taipei',
  startDate: '2026-07-10',
  endDate: '2026-07-14',
  budget: 1200,
  spent: 450,
  numOfTravelers: 1,
  status: TripStatus.upcoming,
  images: [],
  items: [],
  bookings: [],
  checklist: [],
);

void main() {
  const upcoming = Trip(
    id: 'upcoming',
    destination: 'Taipei',
    startDate: '2026-07-10',
    endDate: '2026-07-14',
    budget: 1200,
    spent: 450,
    numOfTravelers: 1,
    status: TripStatus.upcoming,
    images: [],
    items: [ScheduleItem(1, '09:00 AM', 'Taipei 101', Icons.place_rounded, 20)],
    bookings: [],
    checklist: [],
  );

  const friendsTrip = Trip(
    id: 'friends',
    destination: 'Paris',
    startDate: '2026-08-01',
    endDate: '2026-08-07',
    budget: 2400,
    spent: 900,
    numOfTravelers: 2,
    status: TripStatus.upcoming,
    images: [],
    items: [],
    bookings: [],
    checklist: [],
  );

  const past = Trip(
    id: 'past',
    destination: 'Kyoto',
    startDate: '2025-10-12',
    endDate: '2025-10-18',
    budget: 1800,
    spent: 1500,
    numOfTravelers: 4,
    status: TripStatus.past,
    images: [],
    items: [],
    bookings: [],
    checklist: [],
  );

  Future<void> pumpTrips(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<Trip> trips = const [upcoming, friendsTrip, past],
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: TripsScreen(
            trips: trips,
            memories: const [],
            onCreate: _doNothing,
            onOpenTrip: (_) {},
            onStartTrip: (_) {},
            onDeleteTrip: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('categorizes upcoming and past trips', (tester) async {
    await pumpTrips(tester);

    expect(find.text('Your Trips'), findsNothing);
    expect(find.byKey(const ValueKey('trip-control-bar')), findsOneWidget);
    expect(find.text('Taipei'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Kyoto'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-tab-past')));
    await tester.pumpAndSettle();

    expect(find.text('Kyoto'), findsOneWidget);
    expect(find.text('Taipei'), findsNothing);
    expect(find.text('Paris'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters upcoming trips by traveler count', (tester) async {
    await pumpTrips(tester);

    await tester.tap(find.byKey(const ValueKey('trip-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-filter-panel')), findsOneWidget);

    final travelerFilter = find.widgetWithText(ChoiceChip, '2 travelers');
    await tester.ensureVisible(travelerFilter);
    await tester.pumpAndSettle();
    await tester.tap(travelerFilter);
    await tester.pumpAndSettle();

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Taipei'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('FILTER'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-filter-button')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorts upcoming trips by latest date and spending', (
    tester,
  ) async {
    await pumpTrips(tester);

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('trip-upcoming'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('trip-friends'))).dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('trip-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-sort-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latest first').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('trip-friends'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('trip-upcoming'))).dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('trip-sort-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highest spending').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('trip-friends'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('trip-upcoming'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite trip heart updates immediately and stays selected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: const _FavoriteTripsHost(),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(const ValueKey('trip-upcoming'));
    final favoriteButton = find.descendant(
      of: card,
      matching: find.byTooltip('Favorite trip'),
    );
    await tester.tap(favoriteButton);
    await tester.pump();

    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.favorite_rounded)),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.favorite_rounded)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid view can be selected on a phone and hides favorite heart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: const _FavoriteTripsHost(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Favorite trip'), findsOneWidget);

    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Favorite trip'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping either direction requires deletion confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: const _DeleteTripsHost(),
        ),
      ),
    );
    await tester.pump();

    final trip = find.byKey(const ValueKey('trip-upcoming'));
    final firstSwipeStart = tester.getTopLeft(trip) + const Offset(24, 80);
    await tester.dragFrom(firstSwipeStart, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Taipei?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(trip, findsOneWidget);

    final secondSwipeStart = tester.getTopRight(trip) + const Offset(-24, 80);
    await tester.dragFrom(secondSwipeStart, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(trip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip controls remain responsive on a narrow phone', (
    tester,
  ) async {
    await pumpTrips(tester, size: const Size(320, 720));

    expect(find.byKey(const ValueKey('trip-filter-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-control-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-tab-upcoming')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-tab-past')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FavoriteTripsHost extends StatefulWidget {
  const _FavoriteTripsHost();

  @override
  State<_FavoriteTripsHost> createState() => _FavoriteTripsHostState();
}

class _FavoriteTripsHostState extends State<_FavoriteTripsHost> {
  var favoriteTripIds = <String>[];

  @override
  Widget build(BuildContext context) {
    return TripsScreen(
      trips: const [_favoriteTrip],
      memories: const [],
      onCreate: _doNothing,
      onOpenTrip: (_) {},
      onStartTrip: (_) {},
      onDeleteTrip: (_) {},
      favoriteTripIds: favoriteTripIds,
      onToggleFavoriteTrip: (trip) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        setState(() {
          final ids = {...favoriteTripIds};
          if (!ids.add(trip.id)) ids.remove(trip.id);
          favoriteTripIds = ids.toList()..sort();
        });
      },
    );
  }
}

class _DeleteTripsHost extends StatefulWidget {
  const _DeleteTripsHost();

  @override
  State<_DeleteTripsHost> createState() => _DeleteTripsHostState();
}

class _DeleteTripsHostState extends State<_DeleteTripsHost> {
  var trips = const [
    Trip(
      id: 'upcoming',
      destination: 'Taipei',
      startDate: '2026-07-10',
      endDate: '2026-07-14',
      budget: 1200,
      spent: 450,
      numOfTravelers: 1,
      status: TripStatus.upcoming,
      images: [],
      items: [],
      bookings: [],
      checklist: [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TripsScreen(
      trips: trips,
      memories: const [],
      onCreate: _doNothing,
      onOpenTrip: (_) {},
      onStartTrip: (_) {},
      onDeleteTrip: (trip) {
        setState(() {
          trips = trips.where((item) => item.id != trip.id).toList();
        });
      },
    );
  }
}

void _doNothing() {}
