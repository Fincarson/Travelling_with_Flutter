part of travel_agent_app;

GeneratedTripPlan _fallbackTripPlan({
  required PlaceSuggestion place,
  required DateTime startDate,
  required DateTime endDate,
  required int budget,
  required List<String> preferences,
  required String currency,
  TripStartLocation? startLocation,
}) {
  final dayCount = _tripDayCount(startDate, endDate);
  final placeName = place.name.split(',').first;
  final wantsFood = preferences.any(
    (item) => item.toLowerCase().contains('food'),
  );
  final wantsNature = preferences.any(
    (item) =>
        item.toLowerCase().contains('nature') ||
        item.toLowerCase().contains('adventure'),
  );
  final wantsShopping = preferences.any(
    (item) => item.toLowerCase().contains('shopping'),
  );
  final wantsLowWalking = preferences.any((item) {
    final lower = item.toLowerCase();
    return lower.contains('low walking') ||
        lower.contains('less walking') ||
        lower.contains('reduce walking');
  });
  final wantsRainReady = preferences.any((item) {
    final lower = item.toLowerCase();
    return lower.contains('rain') ||
        lower.contains('indoor') ||
        lower.contains('weather');
  });
  final wantsEasyPace = preferences.any((item) {
    final lower = item.toLowerCase();
    return lower.contains('easy pace') ||
        lower.contains('buffer') ||
        lower.contains('comfortable');
  });

  final items = [
    ScheduleItem(
      1,
      '09:30 AM',
      wantsLowWalking
          ? '$placeName arrival and easy transit orientation'
          : '$placeName arrival and neighborhood orientation',
      wantsLowWalking ? Icons.train_rounded : Icons.directions_walk_rounded,
      0,
    ),
    ScheduleItem(
      1,
      '12:30 PM',
      wantsFood ? '$placeName local food crawl' : 'Central cafe lunch stop',
      wantsFood ? Icons.restaurant_rounded : Icons.local_cafe_rounded,
      (budget * .03).round(),
    ),
    ScheduleItem(
      1,
      '03:00 PM',
      wantsRainReady
          ? 'Indoor museum or cultural backup plan'
          : wantsShopping
          ? 'Market and boutique shopping route'
          : 'Historic district walk',
      wantsRainReady
          ? Icons.museum_rounded
          : wantsShopping
          ? Icons.shopping_bag_rounded
          : Icons.museum_rounded,
      (budget * .02).round(),
    ),
    if (dayCount > 1) ...[
      ScheduleItem(
        2,
        wantsEasyPace ? '10:30 AM' : '09:00 AM',
        wantsLowWalking
            ? 'Accessible landmark and cafe route'
            : wantsNature
            ? 'Scenic outdoor viewpoint and easy trail'
            : 'Signature landmark visit',
        wantsLowWalking
            ? Icons.place_rounded
            : wantsNature
            ? Icons.hiking_rounded
            : Icons.place_rounded,
        (budget * .02).round(),
      ),
      ScheduleItem(
        2,
        '06:00 PM',
        '$placeName evening dinner plan',
        Icons.restaurant_rounded,
        (budget * .04).round(),
      ),
    ],
  ];

  final bookings = [
    if (dayCount > 1)
      Booking(
        '$placeName stay placeholder',
        _dateKey(startDate),
        '15:00',
        'HOTEL-TBD',
        (budget * .28).round(),
        Icons.hotel_rounded,
      ),
    Booking(
      '$placeName transport placeholder',
      _dateKey(startDate),
      '09:00',
      'TRANSIT-TBD',
      (budget * .12).round(),
      Icons.train_rounded,
    ),
  ];

  final checklist = [
    const ChecklistCategory('Essentials', [
      'Passport or ID',
      'Wallet and payment cards',
      'Phone charger',
      'Travel adapter',
    ]),
    ChecklistCategory('Trip Style', [
      if (wantsNature) 'Comfortable walking shoes',
      if (wantsFood) 'Restaurant reservation notes',
      if (wantsShopping) 'Extra tote bag',
      'Reusable water bottle',
    ]),
    const ChecklistCategory('Moving days', [
      'Pack up before changing city or district',
      'Keep return transport tickets and payment ready',
    ]),
  ];

  return _planWithTripTransport(
    GeneratedTripPlan(items: items, bookings: bookings, checklist: checklist),
    place: place,
    startDate: startDate,
    endDate: endDate,
    startLocation: startLocation,
    currency: currency,
  );
}

GeneratedTripPlan _planWithTripTransport(
  GeneratedTripPlan plan, {
  required PlaceSuggestion place,
  required DateTime startDate,
  required DateTime endDate,
  required TripStartLocation? startLocation,
  required String currency,
}) {
  final dateDayCount = _tripDayCount(startDate, endDate);
  final finalDay = math.max(
    dateDayCount,
    plan.items.fold<int>(1, (maxDay, item) => math.max(maxDay, item.day)),
  );
  final originItem = _originTransportItem(
    place: place,
    startLocation: startLocation,
    currency: currency,
    firstStop: plan.items.where((item) => item.day == 1).firstOrNull,
  );
  final returnItem = _returnTransportItem(
    place: place,
    startLocation: startLocation,
    currency: currency,
    finalDay: finalDay,
    finalDayItems: plan.items.where((item) => item.day == finalDay),
  );
  final items = [
    if (originItem != null && !_hasOriginTransport(plan.items)) originItem,
    ...plan.items,
    if (returnItem != null && !_hasReturnTransport(plan.items, finalDay))
      returnItem,
  ];

  return GeneratedTripPlan(
    items: items,
    bookings: _bookingsForTripLength(plan.bookings, dayCount: dateDayCount),
    checklist: _checklistWithDeparturePrep(plan.checklist),
  );
}

ScheduleItem? _originTransportItem({
  required PlaceSuggestion place,
  required TripStartLocation? startLocation,
  required String currency,
  required ScheduleItem? firstStop,
}) {
  final originLat = startLocation?.latitude;
  final originLng = startLocation?.longitude;
  if (originLat == null ||
      originLng == null ||
      place.latitude == 0 ||
      place.longitude == 0) {
    return null;
  }

  final km = _distanceKm(originLat, originLng, place.latitude, place.longitude);
  if (km < 3) return null;

  final profile = _transportProfileForDistance(km, currency);
  final firstStopMinutes =
      _parseActivityTimeMinutes(firstStop?.time ?? '') ?? 9 * 60 + 30;
  final travelMinutes = profile.travelMinutes;
  final startMinutes = math.max(5 * 60 + 30, firstStopMinutes - travelMinutes);

  return ScheduleItem(
    1,
    _minutesToTimeLabel(startMinutes),
    profile.activity(place.name.split(',').first),
    profile.icon,
    profile.cost,
  );
}

ScheduleItem? _returnTransportItem({
  required PlaceSuggestion place,
  required TripStartLocation? startLocation,
  required String currency,
  required int finalDay,
  required Iterable<ScheduleItem> finalDayItems,
}) {
  final originLat = startLocation?.latitude;
  final originLng = startLocation?.longitude;
  if (originLat == null ||
      originLng == null ||
      place.latitude == 0 ||
      place.longitude == 0) {
    return null;
  }

  final km = _distanceKm(originLat, originLng, place.latitude, place.longitude);
  if (km < 3) return null;

  final profile = _transportProfileForDistance(km, currency);
  final latestStopMinutes = finalDayItems
      .map((item) => _parseActivityTimeMinutes(item.time))
      .whereType<int>()
      .fold<int?>(null, (latest, minutes) {
        if (latest == null) return minutes;
        return math.max(latest, minutes);
      });
  final startMinutes = math.min(
    22 * 60,
    math.max(12 * 60, (latestStopMinutes ?? 16 * 60) + 90),
  );

  return ScheduleItem(
    finalDay,
    _minutesToTimeLabel(startMinutes),
    profile.returnActivity(place.name.split(',').first),
    profile.icon,
    profile.cost,
  );
}

bool _hasOriginTransport(List<ScheduleItem> items) {
  return items.where((item) => item.day == 1).take(2).any((item) {
    final activity = item.activity.toLowerCase();
    return activity.contains('travel to') ||
        activity.contains('arrive in') ||
        activity.contains('train to') ||
        activity.contains('bus to') ||
        activity.contains('transit to') ||
        activity.contains('flight to') ||
        activity.contains('get to ');
  });
}

bool _hasReturnTransport(List<ScheduleItem> items, int finalDay) {
  return items.where((item) => item.day == finalDay).toList().reversed.any((
    item,
  ) {
    final activity = item.activity.toLowerCase();
    return activity.contains('go home') ||
        activity.contains('return home') ||
        activity.contains('travel home') ||
        activity.contains('fly home') ||
        activity.contains('train home') ||
        activity.contains('bus home') ||
        activity.contains('return from');
  });
}

List<Booking> _bookingsForTripLength(
  List<Booking> bookings, {
  required int dayCount,
}) {
  if (dayCount > 1) return bookings;
  return bookings
      .where((booking) => booking.icon != Icons.hotel_rounded)
      .toList();
}

List<ChecklistCategory> _checklistWithDeparturePrep(
  List<ChecklistCategory> checklist,
) {
  const packUpItem = 'Pack up before changing city or district';
  const returnItem = 'Keep return transport tickets and payment ready';
  final alreadyHasPackUp = checklist.any(
    (category) =>
        category.items.any((item) => item.toLowerCase().contains('pack up')),
  );
  final alreadyHasReturnPrep = checklist.any(
    (category) => category.items.any((item) {
      final lower = item.toLowerCase();
      return lower.contains('return') && lower.contains('ticket');
    }),
  );
  if (alreadyHasPackUp && alreadyHasReturnPrep) return checklist;

  return [
    ...checklist,
    ChecklistCategory('Moving days', [
      if (!alreadyHasPackUp) packUpItem,
      if (!alreadyHasReturnPrep) returnItem,
    ]),
  ];
}

_TransportProfile _transportProfileForDistance(double km, String currency) {
  if (km < 15) {
    return _TransportProfile(
      icon: Icons.train_rounded,
      travelMinutes: math.max(25, (km * 5).round()),
      cost: _transportCost(currency, local: true),
      activity: (destination) =>
          'Get to the first $destination stop by local transit or taxi',
      returnActivity: (destination) =>
          'Pack up, then go home from $destination by local transit or taxi',
    );
  }
  if (km < 150) {
    return _TransportProfile(
      icon: Icons.train_rounded,
      travelMinutes: math.max(50, (km * 1.4).round()),
      cost: _transportCost(currency, regional: true),
      activity: (destination) =>
          'Travel to $destination by train or intercity bus',
      returnActivity: (destination) =>
          'Pack up, then return home from $destination by train or intercity bus',
    );
  }
  if (km < 700) {
    return _TransportProfile(
      icon: Icons.train_rounded,
      travelMinutes: math.max(120, (km * .75).round()),
      cost: _transportCost(currency, rail: true),
      activity: (destination) =>
          'Travel to $destination by rail or coach before sightseeing',
      returnActivity: (destination) =>
          'Pack up, then return home from $destination by rail or coach',
    );
  }
  return _TransportProfile(
    icon: Icons.flight_takeoff_rounded,
    travelMinutes: math.max(240, (km * .18).round()),
    cost: _transportCost(currency, flight: true),
    activity: (destination) => 'Fly to $destination and transfer into the city',
    returnActivity: (destination) => 'Pack up, then fly home from $destination',
  );
}

int _transportCost(
  String currency, {
  bool local = false,
  bool regional = false,
  bool rail = false,
  bool flight = false,
}) {
  switch (currency) {
    case 'TWD':
      if (local) return 120;
      if (regional) return 180;
      if (rail) return 900;
      if (flight) return 4500;
      return 0;
    case 'JPY':
      if (local) return 700;
      if (regional) return 1800;
      if (rail) return 8000;
      if (flight) return 18000;
      return 0;
    case 'EUR':
      if (local) return 8;
      if (regional) return 18;
      if (rail) return 60;
      if (flight) return 160;
      return 0;
    case 'IDR':
      if (local) return 50000;
      if (regional) return 150000;
      if (rail) return 450000;
      if (flight) return 1500000;
      return 0;
    default:
      if (local) return 5;
      if (regional) return 12;
      if (rail) return 45;
      if (flight) return 150;
      return 0;
  }
}

double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const radiusKm = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLng = _degreesToRadians(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

int _tripDayCount(DateTime startDate, DateTime endDate) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  return math.max(1, end.difference(start).inDays + 1);
}

String _minutesToTimeLabel(int minutes) {
  var hour = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

class _TransportProfile {
  const _TransportProfile({
    required this.icon,
    required this.travelMinutes,
    required this.cost,
    required this.activity,
    required this.returnActivity,
  });

  final IconData icon;
  final int travelMinutes;
  final int cost;
  final String Function(String destination) activity;
  final String Function(String destination) returnActivity;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

List<String> _imagesForDestination(String destination) {
  final lower = destination.toLowerCase();
  for (final option in destinations) {
    final optionName = option.name.toLowerCase();
    if (lower.contains(optionName.split(',').first) ||
        optionName.contains(lower.split(',').first)) {
      return [option.image, ...mockKyotoTrip.images.take(2)];
    }
  }
  return mockKyotoTrip.images;
}

List<BudgetCategory> _defaultBudgetCategories({
  required int budget,
  required int actual,
  required List<ScheduleItem> items,
  required List<Booking> bookings,
}) {
  final activityCost = items.fold<int>(0, (total, item) => total + item.cost);
  final transportCost = bookings
      .where(
        (item) =>
            item.icon == Icons.flight_takeoff_rounded ||
            item.icon == Icons.train_rounded,
      )
      .fold<int>(0, (total, item) => total + item.cost);
  final stayCost = bookings
      .where((item) => item.icon == Icons.hotel_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final foodCost = items
      .where((item) => item.type == Icons.restaurant_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final fallback = math.max(0, budget - transportCost - stayCost - foodCost);
  final otherActual = math.max(0, actual);

  return [
    BudgetCategory(
      id: 'transport',
      category: 'Transport',
      planned: math.max(transportCost, (budget * .25).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'stay',
      category: 'Stay',
      planned: math.max(stayCost, (budget * .28).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'food',
      category: 'Food',
      planned: math.max(foodCost, (budget * .18).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'activities',
      category: 'Activities',
      planned: math.max(activityCost, fallback ~/ 2),
      actual: 0,
    ),
    BudgetCategory(
      id: 'other',
      category: 'Other',
      planned: math.max(0, budget ~/ 10),
      actual: otherActual,
    ),
  ];
}
