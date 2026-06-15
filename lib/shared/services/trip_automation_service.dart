part of travel_agent_app;

class TripAutomationService {
  const TripAutomationService({http.Client? client}) : _client = client;

  static const _weatherEndpoint = 'https://api.open-meteo.com/v1/forecast';
  static const _guardianCategory = 'AI Trip Guardian';
  static const _weatherReminderPrefix = 'AI weather check:';

  final http.Client? _client;

  Future<Trip?> enrichTrip(Trip trip) async {
    if (!_canAutomate(trip)) return null;

    final rainyDays = await _loadRainyTripDays(trip);
    if (rainyDays.isEmpty) return null;

    final checklist = _withRainChecklist(trip.checklist, rainyDays);
    final items = _withRainScheduleItems(trip.items, rainyDays)
      ..sort(_compareRuntimeScheduleItems);

    if (_sameChecklist(trip.checklist, checklist) &&
        _sameSchedule(trip.items, items)) {
      return null;
    }

    return trip.copyWith(checklist: checklist, items: items);
  }

  bool _canAutomate(Trip trip) {
    if (trip.status == TripStatus.past) return false;
    if (trip.latitude == null || trip.longitude == null) return false;

    final start = _parseTripDate(trip.startDate);
    final end = _parseTripDate(trip.endDate);
    if (start == null || end == null || end.isBefore(start)) return false;

    final today = _dateOnly(_travelAgentNow());
    final forecastLimit = today.add(const Duration(days: 15));
    return !end.isBefore(today) && !start.isAfter(forecastLimit);
  }

  Future<List<_WeatherTripDay>> _loadRainyTripDays(Trip trip) async {
    final start = _parseTripDate(trip.startDate);
    final end = _parseTripDate(trip.endDate);
    final latitude = trip.latitude;
    final longitude = trip.longitude;
    if (start == null || end == null || latitude == null || longitude == null) {
      return const [];
    }

    final uri = Uri.parse(_weatherEndpoint).replace(
      queryParameters: {
        'latitude': latitude.toStringAsFixed(5),
        'longitude': longitude.toStringAsFixed(5),
        'daily': 'weather_code,precipitation_sum,precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '16',
      },
    );

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final daily = decoded['daily'];
      if (daily is! Map<String, dynamic>) return const [];

      final dates = (daily['time'] as List<dynamic>?) ?? const [];
      final codes = (daily['weather_code'] as List<dynamic>?) ?? const [];
      final precipitation =
          (daily['precipitation_sum'] as List<dynamic>?) ?? const [];
      final probabilities =
          (daily['precipitation_probability_max'] as List<dynamic>?) ??
          const [];

      final today = _dateOnly(_travelAgentNow());
      final rainyDays = <_WeatherTripDay>[];
      for (var index = 0; index < dates.length; index++) {
        final dateText = dates[index] as String?;
        if (dateText == null) continue;

        final date = _parseTripDate(dateText);
        if (date == null || date.isBefore(today)) continue;
        if (date.isBefore(start) || date.isAfter(end)) continue;

        final day = date.difference(start).inDays + 1;
        final weatherDay = _WeatherTripDay(
          day: day,
          date: date,
          weatherCode: _numAt(codes, index)?.round(),
          precipitationSum: _numAt(precipitation, index),
          precipitationProbability: _numAt(probabilities, index)?.round(),
        );
        if (weatherDay.isRainy) rainyDays.add(weatherDay);
      }
      return rainyDays;
    } catch (_) {
      return const [];
    } finally {
      if (ownsClient) client.close();
    }
  }

  List<ChecklistCategory> _withRainChecklist(
    List<ChecklistCategory> checklist,
    List<_WeatherTripDay> rainyDays,
  ) {
    final next = checklist
        .map(
          (category) =>
              ChecklistCategory(category.category, [...category.items]),
        )
        .toList();
    final index = next.indexWhere(
      (category) =>
          category.category.trim().toLowerCase() ==
          _guardianCategory.toLowerCase(),
    );
    final guardian = index == -1
        ? const ChecklistCategory(_guardianCategory, [])
        : next[index];

    final existing = guardian.items.map(_checklistCompareText).toSet();
    final additions = <String>[
      'Umbrella or light raincoat',
      'Waterproof pouch for phone, passport, and tickets',
      _rainSummaryChecklistItem(rainyDays),
    ];

    final items = [...guardian.items];
    for (final addition in additions) {
      if (existing.add(_checklistCompareText(addition))) {
        items.add(_aiChecklistItem(addition));
      }
    }

    final updatedGuardian = ChecklistCategory(guardian.category, items);
    if (index == -1) {
      next.add(updatedGuardian);
    } else {
      next[index] = updatedGuardian;
    }
    return next;
  }

  List<ScheduleItem> _withRainScheduleItems(
    List<ScheduleItem> items,
    List<_WeatherTripDay> rainyDays,
  ) {
    final next = [...items];
    for (final day in rainyDays) {
      final alreadyAdded = next.any(
        (item) =>
            item.day == day.day &&
            item.activity.trimLeft().toLowerCase().startsWith(
              _weatherReminderPrefix.toLowerCase(),
            ),
      );
      if (alreadyAdded) continue;

      next.add(
        ScheduleItem(
          day.day,
          '07:30',
          '$_weatherReminderPrefix ${day.summary}. Pack umbrella/raincoat, '
              'protect tickets and electronics, and keep an indoor backup '
              'ready if showers build.',
          Icons.cloud_rounded,
          0,
        ),
      );
    }
    return next;
  }

  String _rainSummaryChecklistItem(List<_WeatherTripDay> rainyDays) {
    final peakProbability = rainyDays
        .map((day) => day.precipitationProbability)
        .whereType<int>()
        .fold<int?>(
          null,
          (max, value) => max == null || value > max ? value : max,
        );
    final rainyDayText = rainyDays.length == 1
        ? 'Rain is possible on one trip day'
        : 'Rain is possible on ${rainyDays.length} trip days';
    if (peakProbability == null) return '$rainyDayText; keep shoes dry';
    return '$rainyDayText, up to $peakProbability%; keep shoes dry';
  }

  bool _sameChecklist(
    List<ChecklistCategory> current,
    List<ChecklistCategory> next,
  ) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].category != next[i].category) return false;
      if (current[i].items.length != next[i].items.length) return false;
      for (var j = 0; j < current[i].items.length; j++) {
        if (current[i].items[j] != next[i].items[j]) return false;
      }
    }
    return true;
  }

  bool _sameSchedule(List<ScheduleItem> current, List<ScheduleItem> next) {
    if (current.length != next.length) return false;
    final currentSorted = [...current]..sort(_compareRuntimeScheduleItems);
    final nextSorted = [...next]..sort(_compareRuntimeScheduleItems);
    for (var i = 0; i < currentSorted.length; i++) {
      final a = currentSorted[i];
      final b = nextSorted[i];
      if (a.day != b.day ||
          a.time != b.time ||
          a.activity != b.activity ||
          a.type != b.type ||
          a.cost != b.cost) {
        return false;
      }
    }
    return true;
  }

  num? _numAt(List<dynamic> values, int index) {
    if (index < 0 || index >= values.length) return null;
    final value = values[index];
    return value is num ? value : null;
  }
}

class _WeatherTripDay {
  const _WeatherTripDay({
    required this.day,
    required this.date,
    required this.weatherCode,
    required this.precipitationSum,
    required this.precipitationProbability,
  });

  final int day;
  final DateTime date;
  final int? weatherCode;
  final num? precipitationSum;
  final int? precipitationProbability;

  bool get isRainy {
    final code = weatherCode;
    return (code != null && _rainWeatherCodes.contains(code)) ||
        (precipitationSum != null && precipitationSum! >= 1) ||
        (precipitationProbability != null && precipitationProbability! >= 50);
  }

  String get summary {
    final probability = precipitationProbability;
    final amount = precipitationSum;
    final parts = <String>[];
    if (probability != null) parts.add('$probability% rain chance');
    if (amount != null && amount > 0) {
      parts.add('${amount.toStringAsFixed(amount >= 10 ? 0 : 1)} mm expected');
    }
    if (parts.isEmpty) return 'rain is possible today';
    return parts.join(', ');
  }
}

const _rainWeatherCodes = {
  51,
  53,
  55,
  56,
  57,
  61,
  63,
  65,
  66,
  67,
  80,
  81,
  82,
  95,
  96,
  99,
};
