import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/theme/app_theme.dart';

void main() {
  testWidgets('filters notifications by feature type', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(
          body: NotificationsScreen(
            archivedNotificationIds: const {},
            onArchive: (_) {},
            onRestore: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.text('9 shown'), findsOneWidget);
    expect(find.text('Your flight gate changed'), findsOneWidget);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('notification-filter-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group chats').last);
    await tester.pumpAndSettle();

    expect(find.text('1 shown'), findsOneWidget);
    expect(find.text('New message from Maya'), findsOneWidget);
    expect(find.text('Your flight gate changed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping right archives a notification', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final archivedIds = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: TravelAgentTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: NotificationsScreen(
              archivedNotificationIds: archivedIds,
              onArchive: (id) => setState(() => archivedIds.add(id)),
              onRestore: (id) => setState(() => archivedIds.remove(id)),
              onBack: () {},
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.text('Your flight gate changed'),
      const Offset(360, 0),
    );
    await tester.pumpAndSettle();

    expect(archivedIds, contains('flight-gate-change'));
    expect(find.text('Your flight gate changed'), findsNothing);
    expect(find.text('Notification archived'), findsOneWidget);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    final archivedToggle = find.byKey(const ValueKey('show-archived-toggle'));
    await tester.ensureVisible(archivedToggle);
    tester.widget<SwitchListTile>(archivedToggle).onChanged!(true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Your flight gate changed'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Your flight gate changed'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
