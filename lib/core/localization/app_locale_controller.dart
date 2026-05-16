import 'package:flutter/material.dart';

class AppLocaleController {
  static const Locale english = Locale('en');
  static const Locale indonesian = Locale('id');

  static final ValueNotifier<Locale> locale = ValueNotifier(english);

  static const supportedLocales = [
    english,
    indonesian,
  ];

  static void setLocale(Locale value) {
    if (!supportedLocales.contains(value)) {
      return;
    }

    locale.value = value;
  }
}
