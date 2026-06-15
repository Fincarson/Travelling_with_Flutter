import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/errors/app_error.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_locale_controller.dart';
import '../core/localization/app_text.dart';
import '../core/performance/app_performance.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/pages/account_gate.dart';
import '../shared/widgets/app_error_widgets.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _performanceController = AppPerformanceController();
  late final Future<void> _languagePreparation;
  double _languageProgress = 0;

  @override
  void initState() {
    super.initState();
    _performanceController.load();
    _languagePreparation = widget.home == null
        ? _prepareLanguage()
        : Future<void>.value();
  }

  @override
  void dispose() {
    _performanceController.dispose();
    super.dispose();
  }

  Future<void> _prepareLanguage() async {
    while (true) {
      try {
        await AppLocaleController.prepareSavedLanguage(
          onProgress: (progress) {
            if (!mounted || progress == _languageProgress) return;
            setState(() => _languageProgress = progress);
          },
        );
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceScope(
      controller: _performanceController,
      child: Builder(
        builder: (context) {
          final performance = PerformanceScope.settingsOf(context);
          return FutureBuilder<void>(
            future: _languagePreparation,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: TravelAgentTheme.light(),
                  home: _LanguageLoadingScreen(progress: _languageProgress),
                );
              }
              return ValueListenableBuilder<Locale>(
                valueListenable: AppLocaleController.locale,
                builder: (context, locale, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: AppTextController.revision,
                    builder: (context, _, _) => MaterialApp(
                      onGenerateTitle: (context) =>
                          appText(context, 'Travel Agent'),
                      debugShowCheckedModeBanner: false,
                      theme: TravelAgentTheme.light(),
                      locale: locale,
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      supportedLocales: appSupportedLocales,
                      home: widget.home ?? const AccountGate(),
                      builder: (context, child) {
                        final mediaQuery = MediaQuery.of(context);
                        final content = MediaQuery(
                          data: mediaQuery.copyWith(
                            disableAnimations: !performance.animationsEnabled,
                          ),
                          child: child ?? const SizedBox.shrink(),
                        );
                        return ValueListenableBuilder<AppErrorData?>(
                          valueListenable: AppErrorController.current,
                          builder: (context, error, _) {
                            if (error != null) {
                              return UnexpectedErrorView(error: error);
                            }
                            return content;
                          },
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LanguageLoadingScreen extends StatelessWidget {
  const _LanguageLoadingScreen({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress.clamp(0, 1) * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 54),
                  const SizedBox(height: 22),
                  LinearProgressIndicator(
                    value: progress <= 0 ? null : progress.clamp(0, 1),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Loading selected language... $percentage%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The app will open when every interface label is ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
