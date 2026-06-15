import 'dart:ui';

class AppCurrency {
  const AppCurrency._();

  static const fallbackCurrencyCode = 'USD';
  static const supportedCurrencyCodes = ['USD', 'TWD', 'IDR', 'JPY', 'EUR'];

  static String defaultForDevice({
    Iterable<String> supportedCurrencies = supportedCurrencyCodes,
  }) {
    final locales = PlatformDispatcher.instance.locales;
    if (locales.isNotEmpty) {
      return defaultForLocales(
        locales,
        supportedCurrencies: supportedCurrencies,
      );
    }

    return defaultForLocale(
      PlatformDispatcher.instance.locale,
      supportedCurrencies: supportedCurrencies,
    );
  }

  static String defaultForLocales(
    Iterable<Locale> locales, {
    Iterable<String> supportedCurrencies = supportedCurrencyCodes,
  }) {
    final supported = supportedCurrencies.toSet();
    for (final locale in locales) {
      final currency = currencyForLocale(locale);
      if (currency != null && supported.contains(currency)) return currency;
    }

    return _fallbackFor(supported);
  }

  static String defaultForLocale(
    Locale locale, {
    Iterable<String> supportedCurrencies = supportedCurrencyCodes,
  }) {
    final supported = supportedCurrencies.toSet();
    final currency = currencyForLocale(locale);
    if (currency != null && supported.contains(currency)) return currency;
    return _fallbackFor(supported);
  }

  static String? currencyForLocale(Locale locale) {
    final countryCurrency = currencyForCountryCode(locale.countryCode);
    if (countryCurrency != null) return countryCurrency;

    return switch (locale.languageCode.toLowerCase()) {
      'zh' => 'TWD',
      'id' => 'IDR',
      'ja' => 'JPY',
      _ => null,
    };
  }

  static String? currencyForCountryCode(String? countryCode) {
    final country = countryCode?.toUpperCase();
    if (country == null || country.isEmpty) return null;

    if (_euroCountries.contains(country)) return 'EUR';

    return switch (country) {
      'TW' => 'TWD',
      'US' || 'AS' || 'GU' || 'MP' || 'PR' || 'UM' || 'VI' => 'USD',
      'ID' => 'IDR',
      'JP' => 'JPY',
      _ => null,
    };
  }

  static String _fallbackFor(Set<String> supported) {
    if (supported.contains(fallbackCurrencyCode)) return fallbackCurrencyCode;
    return supported.isEmpty ? fallbackCurrencyCode : supported.first;
  }

  static const _euroCountries = {
    'AD',
    'AT',
    'BE',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MC',
    'MT',
    'NL',
    'PT',
    'SI',
    'SK',
    'SM',
    'VA',
  };
}
