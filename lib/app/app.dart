import 'package:flutter/material.dart';

import '../core/localization/app_locale_controller.dart';
import '../core/performance/app_performance.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/pages/account_gate.dart';
import '../l10n/generated/app_localizations.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _performanceController = AppPerformanceController();

  @override
  void initState() {
    super.initState();
    _performanceController.load();
  }

  @override
  void dispose() {
    _performanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceScope(
      controller: _performanceController,
      child: Builder(
        builder: (context) {
          final performance = PerformanceScope.settingsOf(context);
          return ValueListenableBuilder<Locale>(
            valueListenable: AppLocaleController.locale,
            builder: (context, locale, _) {
              return TickerMode(
                enabled: performance.animationsEnabled,
                child: MaterialApp(
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context).appTitle,
                  debugShowCheckedModeBanner: false,
                  theme: TravelAgentTheme.light(),
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: widget.home ?? AccountGate(),
                  builder: (context, child) {
                    final mediaQuery = MediaQuery.of(context);
                    return MediaQuery(
                      data: mediaQuery.copyWith(
                        disableAnimations: !performance.animationsEnabled,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
