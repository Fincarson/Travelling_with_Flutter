import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/theme/app_theme.dart';

void main() {
  testWidgets('travel info shows safety and emergency notices', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: TravelAgentTheme.light(),
        home: Scaffold(body: InfoScreen(onBack: () {})),
      ),
    );

    expect(find.text('Important notices'), findsOneWidget);
    expect(find.text('Entry and immigration'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Emergency contacts'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Emergency contacts'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('110'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('110'), findsOneWidget);
    expect(find.text('119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
