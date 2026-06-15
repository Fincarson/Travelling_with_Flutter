import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/responsive_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.settings),
      ),
      body: ResponsivePage(
        child: ValueListenableBuilder<Locale>(
          valueListenable: AppLocaleController.locale,
          builder: (context, locale, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    l10n.settingsPage,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.language,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _LanguageButton(
                  label: l10n.english,
                  locale: AppLocaleController.english,
                  selectedLocale: locale,
                ),
                const SizedBox(height: 12),
                _LanguageButton(
                  label: l10n.traditionalChineseTaiwan,
                  locale: AppLocaleController.traditionalChineseTaiwan,
                  selectedLocale: locale,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.locale,
    required this.selectedLocale,
  });

  final String label;
  final Locale locale;
  final Locale selectedLocale;

  @override
  Widget build(BuildContext context) {
    final isSelected = locale == selectedLocale;

    if (isSelected) {
      return AppButton(text: label, onPressed: () {});
    }

    return AppButton.outlined(
      text: label,
      onPressed: () => AppLocaleController.setLocale(locale),
    );
  }
}
