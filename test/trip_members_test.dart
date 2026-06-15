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
            onOpenChat: () {},
            onOpenBudget: () {},
            onOpenPacking: () {},
            onOpenSettings: () {},
            onUpdateTrip: (_) {},
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
