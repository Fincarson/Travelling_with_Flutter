import 'package:flutter/material.dart';

import '../core/localization/app_locale_controller.dart';
import '../core/localization/app_localizations_extension.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/navigation/app_navigation_shell.dart';
import 'router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: MaterialTheme(Theme.of(context).textTheme).light(),
          darkTheme: MaterialTheme(Theme.of(context).textTheme).dark(),
          themeMode: ThemeMode.light,
          onGenerateRoute: AppRouter.generateRoute,
          home: const AppNavigationShell(),
        );
      },
    );
  }
}
