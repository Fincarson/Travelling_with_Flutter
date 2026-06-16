import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerTrip = Trip(
    id: 'trip-1',
    title: 'Taipei week',
    destination: 'Taipei',
    startDate: '2026-07-01',
    endDate: '2026-07-07',
    budget: 1000,
    spent: 100,
    numOfTravelers: 2,
    status: TripStatus.upcoming,
    images: ['https://example.com/taipei.jpg'],
    items: [
      ScheduleItem(
        1,
        '10:00 AM',
        'City walk',
        Icons.directions_walk_rounded,
        0,
      ),
    ],
    bookings: [],
    checklist: [],
  );

  test('trip role controls editing access', () {
    expect(ownerTrip.isOwner, isTrue);
    expect(ownerTrip.canEdit, isTrue);
    expect(ownerTrip.copyWith(currentUserRole: 'editor').canEdit, isTrue);
    expect(ownerTrip.copyWith(currentUserRole: 'viewer').canEdit, isFalse);
  });

  testWidgets('viewer trip detail is read-only and includes Members tab', (
    tester,
  ) async {
    final repository = _FakeTravelDataRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripDetailScreen(
            trip: ownerTrip.copyWith(currentUserRole: 'viewer'),
            accountId: 'viewer-1',
            repository: repository,
            onLeftTrip: () {},
            onBack: () {},
            onOpenChat: (_) {},
            onOpenBudget: () {},
            onOpenPacking: () {},
            onOpenSettings: () {},
            onUpdateTrip: (_) {},
            user: const UserProfile(name: 'Viewer', email: '', interests: []),
            initialTabIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('View only: the trip owner manages this plan.'),
      findsOneWidget,
    );
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Add destination'), findsNothing);
    expect(find.byTooltip('Remove activity'), findsNothing);
  });

  testWidgets('trip detail stays visible after adding stops and bookings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _EditableTripDetailHost(
            initialTrip: ownerTrip,
            initialTabIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('ADD DESTINATION'));
    await tester.tap(find.text('ADD DESTINATION'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Activity'),
      'Museum stop',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Museum stop'), findsOneWidget);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Trip'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: _BookingTabHost(initialTrip: ownerTrip)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ADD BOOKING'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Hotel confirmation',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Hotel confirmation'), findsOneWidget);
    expect(find.text('ADD BOOKING'), findsOneWidget);
    expect(find.text('Trip'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip owner can remove members but cannot leave', (tester) async {
    final repository = _FakeTravelDataRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripMembersTab(
            trip: ownerTrip,
            accountId: 'owner-1',
            repository: repository,
            onLeftTrip: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Remove member'), findsOneWidget);
    expect(find.text('Leave trip'), findsNothing);
  });

  testWidgets('viewer can leave but cannot remove trip members', (
    tester,
  ) async {
    final repository = _FakeTravelDataRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripMembersTab(
            trip: ownerTrip.copyWith(currentUserRole: 'viewer'),
            accountId: 'viewer-1',
            repository: repository,
            onLeftTrip: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Remove member'), findsNothing);
    expect(find.text('Leave trip'), findsOneWidget);
  });
}

class _EditableTripDetailHost extends StatefulWidget {
  const _EditableTripDetailHost({
    required this.initialTrip,
    required this.initialTabIndex,
  });

  final Trip initialTrip;
  final int initialTabIndex;

  @override
  State<_EditableTripDetailHost> createState() =>
      _EditableTripDetailHostState();
}

class _EditableTripDetailHostState extends State<_EditableTripDetailHost> {
  late Trip _trip = widget.initialTrip;

  @override
  Widget build(BuildContext context) {
    return TripDetailScreen(
      trip: _trip,
      accountId: 'owner-1',
      repository: _FakeTravelDataRepository(),
      onLeftTrip: () {},
      onBack: () {},
      onOpenChat: (_) {},
      onOpenBudget: () {},
      onOpenPacking: () {},
      onOpenSettings: () {},
      onUpdateTrip: (trip) => setState(() => _trip = trip),
      user: const UserProfile(name: 'Owner', email: '', interests: []),
      initialTabIndex: widget.initialTabIndex,
    );
  }
}

class _BookingTabHost extends StatefulWidget {
  const _BookingTabHost({required this.initialTrip});

  final Trip initialTrip;

  @override
  State<_BookingTabHost> createState() => _BookingTabHostState();
}

class _BookingTabHostState extends State<_BookingTabHost> {
  late Trip _trip = widget.initialTrip;

  @override
  Widget build(BuildContext context) {
    return BookingTab(
      trip: _trip,
      onSave: (trip) => setState(() => _trip = trip),
    );
  }
}

class _FakeTravelDataRepository extends Fake implements TravelDataRepository {
  @override
  Stream<List<TripMember>> watchTripMembers(String tripId) {
    return Stream.value(const [
      TripMember(
        uid: 'owner-1',
        role: 'owner',
        status: 'active',
        displayNameSnapshot: 'Taylor',
      ),
      TripMember(
        uid: 'viewer-1',
        role: 'viewer',
        status: 'active',
        displayNameSnapshot: 'Morgan',
      ),
    ]);
  }
}
