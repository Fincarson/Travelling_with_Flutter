import 'package:flutter/material.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/core/performance/app_performance.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/data/account_auth_service.dart';
import 'package:flutter_app/features/auth/presentation/pages/account_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ValueChanged<PreAccountOnboardingData>? onComplete,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: PreAccountOnboardingFlow(
            onBack: () {},
            onComplete: onComplete ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<_FakeAccountAuthService> pumpAccountGate(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final performance = AppPerformanceController();
    final authService = _FakeAccountAuthService();

    await tester.pumpWidget(
      PerformanceScope(
        controller: performance,
        child: MaterialApp(
          theme: TravelAgentTheme.light(),
          home: AccountGate(authService: authService),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return authService;
  }

  testWidgets('collects onboarding details and draft terms consent', (
    tester,
  ) async {
    PreAccountOnboardingData? result;
    await pumpOnboarding(tester, onComplete: (data) => result = data);

    expect(find.text('Plan smarter. Travel faster.'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-plane-logo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Nicolas',
    );
    await tester.tap(find.text('25-34'));
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    final customInterest = find.byKey(
      const ValueKey('onboarding-custom-interest'),
    );
    await tester.ensureVisible(customInterest);
    await tester.enterText(customInterest, 'Architecture');
    await tester.tap(find.byKey(const ValueKey('onboarding-add-interest')));
    await tester.pumpAndSettle();
    final fastPace = find.text('Fast');
    await tester.ensureVisible(fastPace);
    await tester.pumpAndSettle();
    await tester.tap(fastPace);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('View draft terms and conditions'), findsOneWidget);
    expect(find.text('1. Prototype status'), findsNothing);
    await tester.tap(find.text('View draft terms and conditions'));
    await tester.pumpAndSettle();
    expect(find.text('1. Prototype status'), findsOneWidget);

    final consent = find.byKey(const ValueKey('onboarding-terms-checkbox'));
    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    await tester.tap(consent);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Nicolas');
    expect(result!.ageRange, '25-34');
    expect(result!.interests, contains('Food'));
    expect(result!.interests, contains('Architecture'));
    expect(result!.travelPace, 'Fast');
    expect(result!.termsVersion, 'draft-2026-06-15');
    expect(tester.takeException(), isNull);
  });

  testWidgets('remains usable on a narrow phone', (tester) async {
    await pumpOnboarding(tester, size: const Size(320, 568));

    expect(find.text('Plan smarter. Travel faster.'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-continue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plane logo grows into place with a hero tween', (tester) async {
    await pumpOnboarding(tester);

    expect(find.byType(Hero), findsOneWidget);
    final logo = find.byKey(const ValueKey('onboarding-plane-logo'));
    final tween = tester.widget<TweenAnimationBuilder<double>>(logo).tween;
    expect(tween.begin, 0);
    expect(tween.end, 1);

    await tester.pumpAndSettle();
    final settledTransform = tester.widget<Transform>(
      find.descendant(of: logo, matching: find.byType(Transform)).last,
    );
    expect(settledTransform.transform.getMaxScaleOnAxis(), closeTo(1, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('account gate starts on sign in for every fresh launch', (
    tester,
  ) async {
    final authService = await pumpAccountGate(tester);

    expect(find.byKey(const ValueKey('pre-account-onboarding')), findsNothing);
    expect(find.text('Travel Agent'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(authService.freshSignInPreparations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding opens only after create account is selected', (
    tester,
  ) async {
    await pumpAccountGate(tester);

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pre-account-onboarding')),
      findsOneWidget,
    );
    expect(find.text('Plan smarter. Travel faster.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Travel Agent'), findsOneWidget);
    expect(find.byKey(const ValueKey('pre-account-onboarding')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing account sign in does not open onboarding', (
    tester,
  ) async {
    final authService = await pumpAccountGate(tester);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'existing@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(authService.emailSignIns, 1);
    expect(authService.lastEmail, 'existing@example.com');
    expect(find.byKey(const ValueKey('pre-account-onboarding')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable provider button gives feedback', (tester) async {
    await pumpAccountGate(tester);

    await tester.tap(find.text('Facebook coming later'));
    await tester.pump();

    expect(find.text('Facebook sign-in is not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('onboarding metadata survives local profile serialization', () {
    final acceptedAt = DateTime.utc(2026, 6, 15, 8, 30);
    final profile = UserProfile(
      name: 'Nicolas',
      email: 'nicolas@example.com',
      interests: const ['Food', 'Nature'],
      ageRange: '25-34',
      travelPace: 'Fast',
      termsAcceptedVersion: 'draft-2026-06-15',
      termsAcceptedAt: acceptedAt,
      tutorialCompleted: true,
      favoriteTripIds: const ['trip-kyoto'],
      favoritePlaces: const [
        FavoritePlace(
          id: 'kyoto',
          name: 'Kyoto',
          description: 'Temples and quiet streets',
          imageUrl: 'https://example.com/kyoto.jpg',
          tags: ['Culture'],
        ),
      ],
    );

    final restored = UserProfile.fromMap(profile.toLocalMap());

    expect(restored.ageRange, '25-34');
    expect(restored.travelPace, 'Fast');
    expect(restored.termsAcceptedVersion, 'draft-2026-06-15');
    expect(restored.termsAcceptedAt, acceptedAt);
    expect(restored.tutorialCompleted, isTrue);
    expect(restored.favoriteTripIds, ['trip-kyoto']);
    expect(restored.favoritePlaces.single.name, 'Kyoto');
  });
}

class _FakeAccountAuthService implements AccountAuthService {
  int freshSignInPreparations = 0;
  int emailSignIns = 0;
  String? lastEmail;

  @override
  Stream<AuthenticatedAccount?> get accountChanges =>
      const Stream<AuthenticatedAccount?>.empty();

  @override
  Future<void> prepareForFreshSignIn() async {
    freshSignInPreparations++;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailSignIns++;
    lastEmail = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
