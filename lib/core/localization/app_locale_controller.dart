import 'package:flutter/material.dart';

class AppLocaleController {
  static const Locale english = Locale('en');
  static const Locale traditionalChineseTaiwan = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  );

  static final ValueNotifier<Locale> locale = ValueNotifier(english);

  static const supportedLocales = [english, traditionalChineseTaiwan];

  static void setLocale(Locale value) {
    if (!supportedLocales.contains(value)) {
      return;
    }

    locale.value = value;
  }

  static void setProfileLanguage(String language) {
    setLocale(localeForProfileLanguage(language));
  }

  static Locale localeForProfileLanguage(String language) {
    return switch (language) {
      'zh' || 'zh_Hant_TW' || 'zh-TW' => traditionalChineseTaiwan,
      _ => english,
    };
  }
}
