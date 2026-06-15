import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_text.dart';

class AppLocaleController {
  static const _savedLanguageKey = 'travel_agent.app_language';
  static const Locale english = Locale('en');
  static const Locale traditionalChineseTaiwan = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  );

  static final ValueNotifier<Locale> locale = ValueNotifier(english);
  static final ValueNotifier<String> profileLanguage = ValueNotifier('en');

  static void setLocale(Locale value) {
    locale.value = value;
  }

  static void setProfileLanguage(String language) {
    final option = appLanguageForCode(language);
    profileLanguage.value = option.code;
    AppTextController.activateLanguage(option.code);
    setLocale(option.resolvedLocale);
  }

  static Future<void> saveLanguageForRestart(String language) async {
    final option = appLanguageForCode(language);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_savedLanguageKey, option.code);
  }

  static Future<void> prepareSavedLanguage({
    ValueChanged<double>? onProgress,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_savedLanguageKey) ?? 'en';
    final option = appLanguageForCode(saved);
    await AppTextController.prepareLanguage(
      option.code,
      onProgress: onProgress,
    );
    profileLanguage.value = option.code;
    setLocale(option.resolvedLocale);
  }

  static Locale localeForProfileLanguage(String language) {
    return appLanguageForCode(language).resolvedLocale;
  }
}
