import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trip = Trip(
    id: 'map-test',
    destination: 'Taipei',
    startDate: '2026-06-14',
    endDate: '2026-06-18',
    budget: 1000,
    spent: 0,
    groupType: 'Solo',
    status: TripStatus.upcoming,
    images: [],
    items: [
      ScheduleItem(
        1,
        '09:00 AM',
        'Taipei 101 Observatory',
        Icons.place_rounded,
        600,
        placeId: 'taipei-101',
        formattedAddress: 'No. 7, Section 5, Xinyi Road, Taipei',
        latitude: 25.0330,
        longitude: 121.5654,
      ),
      ScheduleItem(
        2,
        '10:00 AM',
        'National Palace Museum',
        Icons.museum_rounded,
        350,
        placeId: 'palace-museum',
        formattedAddress: 'Shilin District, Taipei',
        latitude: 25.1024,
        longitude: 121.5485,
      ),
      ScheduleItem(
        1,
        '11:30 AM',
        'Chiang Kai-shek Memorial Hall',
        Icons.account_balance_rounded,
        0,
        placeId: 'cks-memorial',
        formattedAddress: 'Zhongzheng District, Taipei',
        latitude: 25.0347,
        longitude: 121.5219,
      ),
      ScheduleItem(
        1,
        '01:30 PM',
        'Lunch near Ximending',
        Icons.restaurant_rounded,
        250,
      ),
      ScheduleItem(
        2,
        '10:00 AM',
        'Beitou Hot Spring Museum',
        Icons.spa_rounded,
        0,
        placeId: 'beitou-museum',
        formattedAddress: 'Beitou District, Taipei',
        latitude: 25.1366,
        longitude: 121.5071,
      ),
    ],
    bookings: [],
    checklist: [],
    latitude: 25.0330,
    longitude: 121.5654,
  );

  Future<void> pumpMap(WidgetTester tester, {required Size size}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(trip: trip, onBack: _doNothing, useGoogleMaps: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders map overlays at phone width', (tester) async {
    await pumpMap(tester, size: const Size(390, 844));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Taipei 101 Observatory'), findsWidgets);
    expect(find.text('Chiang Kai-shek Memorial Hall'), findsOneWidget);
    expect(find.text('Lunch near Ximending'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.byTooltip('Transit'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-itinerary-list')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('map-itinerary-stop-1')),
        matching: find.byIcon(Icons.location_on_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders map overlays at desktop width', (tester) async {
    await pumpMap(tester, size: const Size(1280, 800));

    expect(find.text('Taipei'), findsOneWidget);
    expect(find.text('Taipei 101 Observatory'), findsWidgets);
    expect(find.byTooltip('Ask AI'), findsOneWidget);
    expect(find.byTooltip('Center on my location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom map panel swipes down and back up', (tester) async {
    await pumpMap(tester, size: const Size(390, 844));

    final panel = find.byKey(const ValueKey('map-bottom-panel'));
    final handle = find.byKey(const ValueKey('map-panel-handle'));
    final initialHeight = tester.getSize(panel).height;
    expect(initialHeight, closeTo(422, 2));

    await tester.drag(handle, const Offset(0, 260));
    await tester.pump();

    final collapsedHeight = tester.getSize(panel).height;
    expect(collapsedHeight, lessThan(initialHeight));
    expect(find.text('Taipei 101 Observatory'), findsWidgets);
    expect(find.byTooltip('Transit'), findsNothing);
    expect(find.byKey(const ValueKey('map-itinerary-list')), findsNothing);

    await tester.drag(handle, const Offset(0, -420));
    await tester.pump();

    final halfHeight = tester.getSize(panel).height;
    expect(halfHeight, closeTo(initialHeight, 2));
    expect(find.byTooltip('Transit'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-itinerary-list')), findsOneWidget);

    await tester.drag(handle, const Offset(0, -420));
    await tester.pump();

    expect(tester.getSize(panel).height, greaterThan(700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting an itinerary row highlights that stop', (
    tester,
  ) async {
    await pumpMap(tester, size: const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('map-itinerary-stop-2')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('map-itinerary-stop-2')),
        matching: find.byIcon(Icons.location_on_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('map-itinerary-stop-1')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows itinerary rows before their coordinates are resolved', (
    tester,
  ) async {
    await pumpMap(tester, size: const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('map-itinerary-stop-3')));
    await tester.pump();

    expect(find.text('Lunch near Ximending'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('map-itinerary-stop-3')),
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Directions'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}
