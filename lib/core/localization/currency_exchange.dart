part of travel_agent_app;

enum CurrencyUpdateMode {
  automatic,
  manual;

  static CurrencyUpdateMode fromName(Object? value) {
    return values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => automatic,
    );
  }
}

class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  factory CurrencyInfo.fromMap(Map<String, dynamic> map) {
    final code = ((map['code'] as String?) ?? '').trim().toUpperCase();
    return CurrencyInfo(
      code: code,
      name: ((map['name'] as String?) ?? code).trim(),
      symbol: ((map['symbol'] as String?) ?? code).trim(),
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'symbol': symbol,
  };
}

class CurrencyExchangeData {
  const CurrencyExchangeData({
    required this.baseCurrency,
    required this.asOf,
    required this.fetchedAt,
    required this.rates,
    required this.currencies,
  });

  final String baseCurrency;
  final String asOf;
  final DateTime fetchedAt;
  final Map<String, double> rates;
  final List<CurrencyInfo> currencies;

  static final fallback = CurrencyExchangeData(
    baseCurrency: 'USD',
    asOf: '',
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    rates: const {'USD': 1},
    currencies: const [
      CurrencyInfo(code: 'USD', name: 'United States Dollar', symbol: r'$'),
      CurrencyInfo(code: 'TWD', name: 'New Taiwan Dollar', symbol: r'NT$'),
      CurrencyInfo(code: 'EUR', name: 'Euro', symbol: 'EUR'),
      CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: 'GBP'),
      CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: 'JPY'),
      CurrencyInfo(code: 'KRW', name: 'South Korean Won', symbol: 'KRW'),
      CurrencyInfo(code: 'CNY', name: 'Chinese Renminbi Yuan', symbol: 'CNY'),
      CurrencyInfo(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'IDR'),
      CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: 'AUD'),
      CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'CAD'),
      CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: 'SGD'),
      CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: 'THB'),
      CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: 'INR'),
    ],
  );

  factory CurrencyExchangeData.fromMap(Map<String, dynamic> map) {
    final ratesMap = Map<String, dynamic>.from(
      (map['rates'] as Map?) ?? const <String, dynamic>{},
    );
    final currencies =
        ((map['currencies'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => CurrencyInfo.fromMap(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.code.isNotEmpty)
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    final rates = <String, double>{
      for (final entry in ratesMap.entries)
        if (entry.value is num)
          entry.key.toUpperCase(): (entry.value as num).toDouble(),
    };
    rates.putIfAbsent('USD', () => 1);

    return CurrencyExchangeData(
      baseCurrency: ((map['baseCurrency'] as String?) ?? 'USD').toUpperCase(),
      asOf: (map['asOf'] as String?) ?? '',
      fetchedAt:
          DateTime.tryParse((map['fetchedAt'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      rates: rates,
      currencies: currencies.isEmpty
          ? CurrencyExchangeData.fallback.currencies
          : currencies,
    );
  }

  Map<String, dynamic> toMap() => {
    'baseCurrency': baseCurrency,
    'asOf': asOf,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'rates': rates,
    'currencies': currencies.map((item) => item.toMap()).toList(),
  };

  double? convert({
    required num amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    final source = fromCurrency.trim().toUpperCase();
    final target = toCurrency.trim().toUpperCase();
    if (source == target) return amount.toDouble();
    final sourceRate = rates[source];
    final targetRate = rates[target];
    if (sourceRate == null ||
        sourceRate <= 0 ||
        targetRate == null ||
        targetRate <= 0) {
      return null;
    }
    return amount.toDouble() / sourceRate * targetRate;
  }
}

class CurrencyExchangeService {
  CurrencyExchangeService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _cacheKey = 'app.currency.exchange.v1';
  static const _cacheLifetime = Duration(hours: 24);
  final FirebaseFunctions _functions;

  Future<CurrencyExchangeData> loadDailyRates() async {
    final cached = await _loadCached();
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheLifetime) {
      return cached;
    }

    try {
      final callable = _functions.httpsCallable('getExchangeRates');
      final response = await callable.call<Map<String, dynamic>>();
      final data = CurrencyExchangeData.fromMap(response.data);
      await _saveCached(data);
      return data;
    } catch (_) {
      return cached ?? CurrencyExchangeData.fallback;
    }
  }

  Future<CurrencyExchangeData?> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return CurrencyExchangeData.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await prefs.remove(_cacheKey);
      return null;
    }
  }

  Future<void> _saveCached(CurrencyExchangeData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data.toMap()));
  }
}

class CurrencyScope extends InheritedWidget {
  const CurrencyScope({
    required this.displayCurrencyCode,
    required this.exchangeData,
    required super.child,
    super.key,
  });

  final String displayCurrencyCode;
  final CurrencyExchangeData exchangeData;

  static CurrencyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CurrencyScope>();
    assert(scope != null, 'CurrencyScope is missing above this context.');
    return scope!;
  }

  static CurrencyScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>();

  List<CurrencyInfo> get currencies => exchangeData.currencies;

  List<String> get supportedCodes =>
      currencies.map((item) => item.code).toList(growable: false);

  String format(
    num amount, {
    required String sourceCurrency,
    bool includeOriginal = true,
  }) {
    final source = sourceCurrency.trim().toUpperCase();
    final target = displayCurrencyCode.trim().toUpperCase();
    final converted = exchangeData.convert(
      amount: amount,
      fromCurrency: source,
      toCurrency: target,
    );
    final original = _formatCurrencyAmount(amount.toDouble(), source);
    if (converted == null || source == target) return original;

    final display = _formatCurrencyAmount(converted, target);
    return includeOriginal ? '$display (original $original)' : display;
  }

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) {
    return displayCurrencyCode != oldWidget.displayCurrencyCode ||
        exchangeData != oldWidget.exchangeData;
  }
}

String _formatCurrencyAmount(double amount, String currencyCode) {
  final absolute = amount.abs();
  final decimalDigits = absolute >= 100 ? 0 : 2;
  final pattern = decimalDigits == 0 ? '#,##0' : '#,##0.00';
  return '${currencyCode.toUpperCase()} '
      '${NumberFormat(pattern, 'en').format(amount)}';
}

String _displayMoney(
  BuildContext context,
  num amount,
  String sourceCurrency, {
  bool includeOriginal = true,
}) {
  final scope = CurrencyScope.maybeOf(context);
  if (scope == null) {
    return _formatCurrencyAmount(amount.toDouble(), sourceCurrency);
  }
  return scope.format(
    amount,
    sourceCurrency: sourceCurrency,
    includeOriginal: includeOriginal,
  );
}

String? _currencyForCountryCode(String? countryCode) {
  final country = countryCode?.trim().toUpperCase();
  if (country == null || country.length != 2) return null;

  for (final entry in _sharedCurrencyCountries.entries) {
    if (entry.value.contains(country)) return entry.key;
  }
  return _individualCountryCurrencies[country];
}

const _sharedCurrencyCountries = <String, Set<String>>{
  'EUR': {
    'AD',
    'AT',
    'AX',
    'BE',
    'BL',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GF',
    'GP',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MC',
    'ME',
    'MF',
    'MQ',
    'MT',
    'NL',
    'PM',
    'PT',
    'RE',
    'SI',
    'SK',
    'SM',
    'TF',
    'VA',
    'YT',
  },
  'USD': {
    'AS',
    'BQ',
    'EC',
    'FM',
    'GU',
    'IO',
    'MH',
    'MP',
    'PA',
    'PR',
    'PW',
    'SV',
    'TC',
    'TL',
    'UM',
    'US',
    'VG',
    'VI',
  },
  'AUD': {'AU', 'CC', 'CX', 'HM', 'KI', 'NF', 'NR', 'TV'},
  'NZD': {'CK', 'NU', 'NZ', 'PN', 'TK'},
  'GBP': {'GB', 'GG', 'IM', 'JE'},
  'DKK': {'DK', 'FO', 'GL'},
  'NOK': {'BV', 'NO', 'SJ'},
  'CHF': {'CH', 'LI'},
  'XCD': {'AI', 'AG', 'DM', 'GD', 'KN', 'LC', 'MS', 'VC'},
  'XOF': {'BJ', 'BF', 'CI', 'GW', 'ML', 'NE', 'SN', 'TG'},
  'XAF': {'CF', 'CG', 'CM', 'GA', 'GQ', 'TD'},
  'XPF': {'NC', 'PF', 'WF'},
};

const _individualCountryCurrencies = <String, String>{
  'AE': 'AED',
  'AF': 'AFN',
  'AL': 'ALL',
  'AM': 'AMD',
  'AO': 'AOA',
  'AR': 'ARS',
  'AW': 'AWG',
  'AZ': 'AZN',
  'BA': 'BAM',
  'BB': 'BBD',
  'BD': 'BDT',
  'BH': 'BHD',
  'BI': 'BIF',
  'BM': 'BMD',
  'BN': 'BND',
  'BO': 'BOB',
  'BR': 'BRL',
  'BS': 'BSD',
  'BT': 'BTN',
  'BW': 'BWP',
  'BY': 'BYN',
  'BZ': 'BZD',
  'CA': 'CAD',
  'CD': 'CDF',
  'CL': 'CLP',
  'CN': 'CNY',
  'CO': 'COP',
  'CR': 'CRC',
  'CU': 'CUP',
  'CV': 'CVE',
  'CW': 'XCG',
  'CZ': 'CZK',
  'DJ': 'DJF',
  'DO': 'DOP',
  'DZ': 'DZD',
  'EG': 'EGP',
  'ER': 'ERN',
  'ET': 'ETB',
  'FJ': 'FJD',
  'FK': 'FKP',
  'GE': 'GEL',
  'GH': 'GHS',
  'GI': 'GIP',
  'GM': 'GMD',
  'GN': 'GNF',
  'GT': 'GTQ',
  'GY': 'GYD',
  'HK': 'HKD',
  'HN': 'HNL',
  'HT': 'HTG',
  'HU': 'HUF',
  'ID': 'IDR',
  'IL': 'ILS',
  'IN': 'INR',
  'IQ': 'IQD',
  'IR': 'IRR',
  'IS': 'ISK',
  'JM': 'JMD',
  'JO': 'JOD',
  'JP': 'JPY',
  'KE': 'KES',
  'KG': 'KGS',
  'KH': 'KHR',
  'KM': 'KMF',
  'KP': 'KPW',
  'KR': 'KRW',
  'KW': 'KWD',
  'KY': 'KYD',
  'KZ': 'KZT',
  'LA': 'LAK',
  'LB': 'LBP',
  'LK': 'LKR',
  'LR': 'LRD',
  'LS': 'LSL',
  'LY': 'LYD',
  'MA': 'MAD',
  'MD': 'MDL',
  'MG': 'MGA',
  'MK': 'MKD',
  'MM': 'MMK',
  'MN': 'MNT',
  'MO': 'MOP',
  'MR': 'MRU',
  'MU': 'MUR',
  'MV': 'MVR',
  'MW': 'MWK',
  'MX': 'MXN',
  'MY': 'MYR',
  'MZ': 'MZN',
  'NA': 'NAD',
  'NG': 'NGN',
  'NI': 'NIO',
  'NP': 'NPR',
  'OM': 'OMR',
  'PE': 'PEN',
  'PG': 'PGK',
  'PH': 'PHP',
  'PK': 'PKR',
  'PL': 'PLN',
  'PY': 'PYG',
  'QA': 'QAR',
  'RO': 'RON',
  'RS': 'RSD',
  'RU': 'RUB',
  'RW': 'RWF',
  'SA': 'SAR',
  'SB': 'SBD',
  'SC': 'SCR',
  'SD': 'SDG',
  'SE': 'SEK',
  'SG': 'SGD',
  'SH': 'SHP',
  'SL': 'SLE',
  'SO': 'SOS',
  'SR': 'SRD',
  'SS': 'SSP',
  'ST': 'STN',
  'SX': 'XCG',
  'SY': 'SYP',
  'SZ': 'SZL',
  'TH': 'THB',
  'TJ': 'TJS',
  'TM': 'TMT',
  'TN': 'TND',
  'TO': 'TOP',
  'TR': 'TRY',
  'TT': 'TTD',
  'TW': 'TWD',
  'TZ': 'TZS',
  'UA': 'UAH',
  'UG': 'UGX',
  'UY': 'UYU',
  'UZ': 'UZS',
  'VE': 'VES',
  'VN': 'VND',
  'VU': 'VUV',
  'WS': 'WST',
  'YE': 'YER',
  'ZA': 'ZAR',
  'ZM': 'ZMW',
  'ZW': 'ZWG',
};
