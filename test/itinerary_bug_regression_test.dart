import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('budget spending dialog saves without framework assertions', (
    tester,
  ) async {
    var trip = _testTrip(
      budgetCategories: const [
        BudgetCategory(id: 'food', category: 'Food', planned: 100, actual: 0),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BudgetTab(
                trip: trip,
                onSave: (updated) => setState(() => trip = updated),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new spending'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Dinner');
    await tester.enterText(find.byType(TextField).at(1), '42');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(trip.budgetCategories.single.spendings.single.title, 'Dinner');
    expect(trip.budgetCategories.single.spendings.single.amount, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule tab does not build raw tooltip controllers', (
    tester,
  ) async {
    final trip = _testTrip(
      items: const [
        ScheduleItem(1, '10:00 AM', 'Museum visit', Icons.museum_rounded, 0),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(
          body: ScheduleTab(trip: trip, onSave: (_) {}),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ScheduleTab),
        matching: find.byType(RawTooltip),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Trip _testTrip({
  List<ScheduleItem> items = const [],
  List<BudgetCategory> budgetCategories = const [],
}) {
  return Trip(
    id: 'trip-test',
    destination: 'Kyoto',
    startDate: '2026-07-01',
    endDate: '2026-07-03',
    budget: 1000,
    spent: 0,
    numOfTravelers: 2,
    status: TripStatus.upcoming,
    images: const [],
    items: items,
    bookings: const [],
    checklist: const [],
    budgetCategories: budgetCategories,
  );
}
