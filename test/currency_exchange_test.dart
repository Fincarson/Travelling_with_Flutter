import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts through USD base rates without changing source values', () {
    final data = CurrencyExchangeData(
      baseCurrency: 'USD',
      asOf: '2026-06-14',
      fetchedAt: DateTime(2026, 6, 14),
      rates: const {'USD': 1, 'TWD': 32, 'JPY': 160},
      currencies: CurrencyExchangeData.fallback.currencies,
    );

    expect(
      data.convert(amount: 3200, fromCurrency: 'TWD', toCurrency: 'USD'),
      100,
    );
    expect(
      data.convert(amount: 100, fromCurrency: 'USD', toCurrency: 'JPY'),
      16000,
    );
    expect(
      data.convert(amount: 100, fromCurrency: 'ABC', toCurrency: 'USD'),
      isNull,
    );
  });

  test('old profiles default to USD and are marked for migration', () {
    final profile = UserProfile.fromMap({
      'name': 'Traveler',
      'email': 'traveler@example.com',
      'settings': {'language': 'en'},
    });

    expect(profile.displayCurrencyCode, 'USD');
    expect(profile.currencyUpdateMode, CurrencyUpdateMode.automatic);
    expect(profile.currencySettingsVersion, 0);
  });
}
