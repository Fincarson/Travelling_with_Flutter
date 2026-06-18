part of travel_agent_app;

// Builds a finished Trip from a completed background preview job, mirroring the
// synchronous trip assembly in CreateTripScreen so background generation
// produces the same shape of trip.
Trip _tripFromPreviewJob(TripPreviewJob job) {
  final plan = job.plan ?? const GeneratedTripPlan(
    items: [],
    bookings: [],
    checklist: [],
  );
  final place = job.place;
  final start = job.startDate ?? DateTime.now();
  final end = job.endDate ?? start;
  final bookings = plan.bookings;
  final budgetCategories = _defaultBudgetCategories(
    budget: job.budget,
    actual: 0,
    items: plan.items,
    bookings: bookings,
  );
  final budgetLimit = _budgetLimitForCategories(
    budget: job.budget,
    categories: budgetCategories,
  );
  final destination = place?.name ?? 'New trip';
  final images = job.images.isNotEmpty
      ? job.images
      : _imagesForDestination(destination);
  return Trip(
    id: 't-${DateTime.now().millisecondsSinceEpoch}',
    destination: destination,
    placeId: place?.placeId ?? destination,
    formattedAddress: place?.formatted ?? destination,
    latitude: place?.latitude ?? 0,
    longitude: place?.longitude ?? 0,
    originLabel: job.startLocation?.displayLabel,
    originLatitude: job.startLocation?.latitude,
    originLongitude: job.startLocation?.longitude,
    startDate: _dateKey(start),
    endDate: _dateKey(end),
    budget: budgetLimit,
    spent: 0,
    numOfTravelers: _travelerCountForGroupType(job.groupType),
    currency: job.currency,
    status: TripStatus.upcoming,
    images: images,
    items: plan.items,
    bookings: bookings,
    checklist: plan.checklist,
    preferences: job.preferences,
    budgetCategories: budgetCategories,
  );
}

// ignore: unused_element
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
  final placeName = _destinationShortLabel(place);
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
      wantsFood
          ? '$placeName local food crawl'
          : 'Central $placeName cafe lunch stop',
      wantsFood ? Icons.restaurant_rounded : Icons.local_cafe_rounded,
      (budget * .03).round(),
    ),
    ScheduleItem(
      1,
      '03:00 PM',
      wantsRainReady
          ? 'Indoor museum or cultural stop in $placeName'
          : wantsShopping
          ? '$placeName market and boutique shopping route'
          : 'Historic district walk in $placeName',
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
            ? 'Accessible landmark and cafe route in $placeName'
            : wantsNature
            ? 'Scenic $placeName viewpoint and easy trail'
            : 'Signature $placeName landmark visit',
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
    preferences: preferences,
  );
}

GeneratedTripPlan _planWithTripTransport(
  GeneratedTripPlan plan, {
  required PlaceSuggestion place,
  required DateTime startDate,
  required DateTime endDate,
  required TripStartLocation? startLocation,
  required String currency,
  required List<String> preferences,
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
  final items = [
    if (originItem != null && !_hasOriginTransport(plan.items)) originItem,
    ...plan.items,
  ];
  final preferenceItems = _planWithPreferenceStops(
    items,
    preferences: preferences,
    destination: _destinationShortLabel(place),
    dayCount: dateDayCount,
    currency: currency,
  );
  final balancedItems = _ensureDailyScheduleCoverage(
    preferenceItems,
    place: place,
    dayCount: dateDayCount,
    currency: currency,
  );
  final returnItem = _returnTransportItem(
    place: place,
    startLocation: startLocation,
    currency: currency,
    finalDay: finalDay,
    finalDayItems: balancedItems.where((item) => item.day == finalDay),
  );
  final transportCompleteItems = [
    ...balancedItems,
    if (returnItem != null && !_hasReturnTransport(balancedItems, finalDay))
      returnItem,
  ];
  final connectedItems = _planWithLocalTransfers(
    transportCompleteItems,
    currency: currency,
  );

  return GeneratedTripPlan(
    items: connectedItems,
    bookings: _bookingsForTripLength(plan.bookings, dayCount: dateDayCount),
    checklist: _checklistWithDeparturePrep(plan.checklist),
  );
}

List<ScheduleItem> _planWithLocalTransfers(
  List<ScheduleItem> items, {
  required String currency,
}) {
  final next = [...items]..sort(_compareRuntimeScheduleItems);
  final additions = <ScheduleItem>[];
  final days = next.map((item) => item.day).toSet().toList()..sort();

  for (final day in days) {
    final dayItems = next.where((item) => item.day == day).toList()
      ..sort(_compareRuntimeScheduleItems);
    for (var i = 0; i < dayItems.length - 1; i++) {
      final current = dayItems[i];
      final following = dayItems[i + 1];
      if (_isConnectorItem(current) || _isConnectorItem(following)) continue;

      final currentMinutes = _parseActivityTimeMinutes(current.time);
      final followingMinutes = _parseActivityTimeMinutes(following.time);
      if (currentMinutes == null || followingMinutes == null) continue;
      final gap = followingMinutes - currentMinutes;
      if (gap < 45 || gap > 240) continue;
      if (_hasConnectorBetween(dayItems, currentMinutes, followingMinutes)) {
        continue;
      }

      final transferMinutes = math
          .max(
            currentMinutes + 20,
            followingMinutes - math.min(35, math.max(15, (gap * .35).round())),
          )
          .toInt();
      additions.add(
        ScheduleItem(
          day,
          _minutesToTimeLabel(transferMinutes),
          'Move to the next area for ${_shortStopLabel(following.activity)}',
          Icons.directions_walk_rounded,
          _transportCost(currency, local: true),
        ),
      );
    }
  }

  return [...next, ...additions]..sort(_compareRuntimeScheduleItems);
}

List<ScheduleItem> _planWithPreferenceStops(
  List<ScheduleItem> items, {
  required List<String> preferences,
  required String destination,
  required int dayCount,
  required String currency,
}) {
  final next = [...items];
  final uniquePreferences = preferences
      .map((preference) => preference.trim())
      .where((preference) => preference.isNotEmpty)
      .toSet()
      .toList();
  var added = 0;

  for (final preference in uniquePreferences) {
    if (added >= 5) break;
    if (_preferenceAlreadyCovered(next, preference)) continue;
    final day = math.min(math.max(1, added + 1), math.max(1, dayCount));
    final stop = _preferenceStop(
      preference: preference,
      destination: destination,
      day: day,
      time: _openPreferenceStopTime(next, day, added),
      currency: currency,
    );
    if (stop == null) continue;
    next.add(stop);
    added++;
  }

  return next..sort(_compareRuntimeScheduleItems);
}

bool _preferenceAlreadyCovered(List<ScheduleItem> items, String preference) {
  final normalized = _normalizedPreference(preference);
  if (normalized.isEmpty) return true;
  final related = _preferenceKeywords(normalized);
  return items.any((item) {
    final activity = item.activity.toLowerCase();
    return related.any(activity.contains);
  });
}

ScheduleItem? _preferenceStop({
  required String preference,
  required String destination,
  required int day,
  required String time,
  required String currency,
}) {
  final normalized = _normalizedPreference(preference);
  final activityCost = _localActivityCost(currency);
  final mealCost = _localMealCost(currency);

  if (_containsAny(normalized, const [
    'anime',
    'manga',
    'cosplay',
    'otaku',
    'popculture',
  ])) {
    return ScheduleItem(
      day,
      time,
      'Anime convention or pop-culture event calendar check, then anime shops, arcades, or themed cafes in $destination',
      Icons.movie_rounded,
      activityCost,
    );
  }
  if (_containsAny(normalized, const ['game', 'gaming', 'arcade', 'esport'])) {
    return ScheduleItem(
      day,
      time,
      'Gaming arcade, character goods, or esports cafe stop in $destination',
      Icons.sports_esports_rounded,
      activityCost,
    );
  }
  if (_containsAny(normalized, const ['halal', 'muslim'])) {
    return ScheduleItem(
      day,
      time,
      'Halal restaurant or Muslim-friendly food area in $destination',
      Icons.restaurant_rounded,
      mealCost,
    );
  }
  if (_containsAny(normalized, const [
    'wheelchair',
    'accessible',
    'accessibility',
    'stepfree',
    'mobility',
  ])) {
    return ScheduleItem(
      day,
      time,
      'Step-free transit route and wheelchair-accessible landmark in $destination',
      Icons.accessible_rounded,
      _transportCost(currency, local: true),
    );
  }
  if (_containsAny(normalized, const ['vegan', 'vegetarian', 'plantbased'])) {
    return ScheduleItem(
      day,
      time,
      'Vegetarian or plant-based local meal stop in $destination',
      Icons.restaurant_rounded,
      mealCost,
    );
  }
  if (_containsAny(normalized, const ['coffee', 'cafe', 'tea'])) {
    return ScheduleItem(
      day,
      time,
      'Specialty cafe or tea stop shaped around $preference',
      Icons.local_cafe_rounded,
      mealCost,
    );
  }
  if (_containsAny(normalized, const ['shopping', 'fashion', 'thrift'])) {
    return ScheduleItem(
      day,
      time,
      'Shopping district matched to $preference in $destination',
      Icons.shopping_bag_rounded,
      activityCost,
    );
  }
  if (_isGenericPreference(normalized)) return null;

  return ScheduleItem(
    day,
    time,
    _focusStopActivity(preference, destination),
    Icons.place_rounded,
    activityCost,
  );
}

// Builds a clean, location-anchored stop name from a preference tag, stripping
// trailing qualifiers ("Food-focused" -> "food") so we never produce labels
// like "Food-focused-focused" or "Japan-wide-focused".
String _focusStopActivity(String preference, String destination) {
  final label = preference
      .trim()
      .replaceAll(
        RegExp(
          r'[-\s]*(focused|focus|wide|themed|oriented)$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (label.isEmpty || label.toLowerCase() == destination.toLowerCase()) {
    return 'Explore standout local spots around $destination';
  }
  return 'Explore the best ${label.toLowerCase()} spots around $destination';
}

String _openPreferenceStopTime(List<ScheduleItem> items, int day, int offset) {
  const times = ['11:00 AM', '02:30 PM', '05:00 PM', '07:30 PM'];
  final used = items
      .where((item) => item.day == day)
      .map((item) => item.time)
      .toSet();
  for (final time in [...times.skip(offset % times.length), ...times]) {
    if (!used.contains(time)) return time;
  }
  return times[offset % times.length];
}

List<String> _preferenceKeywords(String normalized) {
  if (_containsAny(normalized, const [
    'anime',
    'manga',
    'cosplay',
    'otaku',
    'popculture',
  ])) {
    return const ['anime', 'manga', 'cosplay', 'arcade', 'themed cafe'];
  }
  if (_containsAny(normalized, const ['halal', 'muslim'])) {
    return const ['halal', 'muslim-friendly'];
  }
  if (_containsAny(normalized, const [
    'wheelchair',
    'accessible',
    'accessibility',
    'stepfree',
    'mobility',
  ])) {
    return const ['wheelchair', 'accessible', 'step-free'];
  }
  return [normalized.replaceAll(' ', '')];
}

bool _containsAny(String value, List<String> keywords) {
  return keywords.any(value.contains);
}

bool _isGenericPreference(String normalized) {
  return const {
    'culture',
    'food',
    'nature',
    'relax',
    'walking',
    'luxury',
    'adventure',
    'museums',
    'nightlife',
    'budgetfriendly',
  }.contains(normalized);
}

String _normalizedPreference(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

List<ScheduleItem> _ensureDailyScheduleCoverage(
  List<ScheduleItem> items, {
  required PlaceSuggestion place,
  required int dayCount,
  required String currency,
}) {
  if (dayCount <= 1) return items..sort(_compareRuntimeScheduleItems);

  final destination = _destinationShortLabel(place);
  final next = [...items];
  for (var day = 1; day <= dayCount; day++) {
    final dayItems = next.where((item) => item.day == day).toList();
    if (dayItems.length >= _minimumStopsForDay(day, dayCount)) continue;
    final needed = _minimumStopsForDay(day, dayCount) - dayItems.length;
    next.addAll(
      _dailyCoverageStops(
        day: day,
        dayCount: dayCount,
        destination: destination.isEmpty ? place.name : destination,
        currency: currency,
        count: needed,
        existingItems: dayItems,
      ),
    );
  }
  return next..sort(_compareRuntimeScheduleItems);
}

int _minimumStopsForDay(int day, int dayCount) {
  if (day == 1 || day == dayCount) return 2;
  return 3;
}

List<ScheduleItem> _dailyCoverageStops({
  required int day,
  required int dayCount,
  required String destination,
  required String currency,
  required int count,
  required List<ScheduleItem> existingItems,
}) {
  final usedMinutes = existingItems
      .map((item) => _parseActivityTimeMinutes(item.time))
      .whereType<int>()
      .toSet();
  final candidates =
      _dailyCoverageTemplates(
            day: day,
            dayCount: dayCount,
            destination: destination,
            currency: currency,
          )
          .where((item) {
            final minutes = _parseActivityTimeMinutes(item.time);
            return minutes == null || !usedMinutes.contains(minutes);
          })
          .take(count);
  return candidates.toList(growable: false);
}

List<ScheduleItem> _dailyCoverageTemplates({
  required int day,
  required int dayCount,
  required String destination,
  required String currency,
}) {
  final localMealCost = _localMealCost(currency);
  final activityCost = _localActivityCost(currency);
  if (day == dayCount) {
    return [
      ScheduleItem(
        day,
        '10:00 AM',
        'Slow final morning in $destination with a nearby cafe or market stop',
        Icons.local_cafe_rounded,
        localMealCost,
      ),
      ScheduleItem(
        day,
        '01:30 PM',
        'Last easy neighborhood walk and souvenir window before departure',
        Icons.shopping_bag_rounded,
        activityCost,
      ),
      ScheduleItem(
        day,
        '04:00 PM',
        'Pack up and leave buffer time for the return route',
        Icons.hotel_rounded,
        0,
      ),
    ];
  }
  final theme = day % 3;
  if (theme == 1) {
    return [
      ScheduleItem(
        day,
        '09:30 AM',
        'Known landmark or historic photo route in $destination',
        Icons.place_rounded,
        activityCost,
      ),
      ScheduleItem(
        day,
        '01:00 PM',
        'Local lunch area with a short rest break',
        Icons.restaurant_rounded,
        localMealCost,
      ),
      ScheduleItem(
        day,
        '04:00 PM',
        'Museum, temple, or indoor culture backup',
        Icons.museum_rounded,
        activityCost,
      ),
    ];
  }
  if (theme == 2) {
    return [
      ScheduleItem(
        day,
        '10:00 AM',
        'Transit-friendly district route in $destination',
        Icons.train_rounded,
        _transportCost(currency, local: true),
      ),
      ScheduleItem(
        day,
        '02:00 PM',
        'Scenic walk, riverside, or viewpoint stop',
        Icons.directions_walk_rounded,
        0,
      ),
      ScheduleItem(
        day,
        '06:30 PM',
        'Dinner near the evening area',
        Icons.restaurant_rounded,
        localMealCost,
      ),
    ];
  }
  return [
    ScheduleItem(
      day,
      '09:30 AM',
      'Easy morning cafe and planning buffer',
      Icons.local_cafe_rounded,
      localMealCost,
    ),
    ScheduleItem(
      day,
      '12:30 PM',
      'Food market or local specialty lunch',
      Icons.restaurant_rounded,
      localMealCost,
    ),
    ScheduleItem(
      day,
      '03:30 PM',
      'Shopping street or neighborhood browse',
      Icons.shopping_bag_rounded,
      activityCost,
    ),
  ];
}

int _localMealCost(String currency) {
  return switch (currency) {
    'TWD' => 250,
    'JPY' => 1600,
    'EUR' => 18,
    'IDR' => 90000,
    _ => 20,
  };
}

int _localActivityCost(String currency) {
  return switch (currency) {
    'TWD' => 200,
    'JPY' => 1200,
    'EUR' => 16,
    'IDR' => 80000,
    _ => 18,
  };
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
    profile.activity(_destinationShortLabel(place)),
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
  final finalItems = finalDayItems.toList();
  final originLat = startLocation?.latitude;
  final originLng = startLocation?.longitude;
  if (originLat == null ||
      originLng == null ||
      place.latitude == 0 ||
      place.longitude == 0) {
    return _fallbackReturnTransportItem(
      place: place,
      finalDay: finalDay,
      finalDayItems: finalItems,
      currency: currency,
    );
  }

  final km = _distanceKm(originLat, originLng, place.latitude, place.longitude);
  if (km < 3) {
    return _fallbackReturnTransportItem(
      place: place,
      finalDay: finalDay,
      finalDayItems: finalItems,
      currency: currency,
      local: true,
    );
  }

  final profile = _transportProfileForDistance(km, currency);
  final latestStopMinutes = finalItems
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
    profile.returnActivity(_destinationShortLabel(place)),
    profile.icon,
    profile.cost,
  );
}

ScheduleItem _fallbackReturnTransportItem({
  required PlaceSuggestion place,
  required int finalDay,
  required Iterable<ScheduleItem> finalDayItems,
  required String currency,
  bool local = false,
}) {
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
  final destination = _destinationShortLabel(place);
  return ScheduleItem(
    finalDay,
    _minutesToTimeLabel(startMinutes),
    local
        ? 'Pack up, then return home from ${destination.isEmpty ? place.name : destination} by local transit or taxi'
        : 'Pack up, confirm the route and timing, then return home from ${destination.isEmpty ? place.name : destination}',
    local ? Icons.train_rounded : Icons.flight_takeoff_rounded,
    local
        ? _transportCost(currency, local: true)
        : _transportCost(currency, flight: true),
  );
}

bool _isConnectorItem(ScheduleItem item) {
  final activity = item.activity.toLowerCase();
  return item.type == Icons.train_rounded ||
      item.type == Icons.flight_takeoff_rounded ||
      item.type == Icons.directions_walk_rounded ||
      activity.contains('transfer') ||
      activity.contains('transit') ||
      activity.contains('walk to') ||
      activity.contains('move to') ||
      activity.contains('depart') ||
      activity.contains('arrive') ||
      activity.contains('return home') ||
      activity.contains('go home');
}

bool _hasConnectorBetween(
  List<ScheduleItem> items,
  int startMinutes,
  int endMinutes,
) {
  return items.any((item) {
    if (!_isConnectorItem(item)) return false;
    final minutes = _parseActivityTimeMinutes(item.time);
    return minutes != null && minutes > startMinutes && minutes < endMinutes;
  });
}

String _shortStopLabel(String activity) {
  final firstSentence = activity.split(RegExp(r'[.!?]')).first.trim();
  final words = firstSentence.split(RegExp(r'\s+'));
  if (words.length <= 8) return firstSentence;
  return '${words.take(8).join(' ')}...';
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

String _destinationShortLabel(PlaceSuggestion place) {
  final parts = place.name
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return place.name.trim();
  if (parts.length == 1) return parts.first;
  final country = place.country?.trim().toLowerCase();
  final second = parts[1].toLowerCase();
  if (country != null && country.isNotEmpty && second == country) {
    return parts.first;
  }
  return '${parts[0]}, ${parts[1]}';
}

int _tripDayCount(DateTime startDate, DateTime endDate) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  return math.max(1, end.difference(start).inDays + 1);
}

String _minutesToTimeLabel(int minutes) {
  final hour = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
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
  int transportActual = 0,
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
      actual: math.max(0, transportActual),
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
