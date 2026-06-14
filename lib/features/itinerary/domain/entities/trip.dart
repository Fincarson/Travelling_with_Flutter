part of travel_agent_app;

enum TripStatus { upcoming, ongoing, past }

class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.spent,
    required this.numOfTravelers,
    required this.status,
    required this.images,
    required this.items,
    required this.bookings,
    required this.checklist,
    this.currency = 'USD',
    this.preferences = const [],
    this.budgetCategories = const [],
    this.placeId,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    this.originLabel,
    this.originLatitude,
    this.originLongitude,
    this.title = '',
  });

  final String id;
  final String title;
  final String destination;
  final String startDate;
  final String endDate;
  final int budget;
  final int spent;
  final int numOfTravelers;
  final TripStatus status;
  final List<String> images;
  final List<ScheduleItem> items;
  final List<Booking> bookings;
  final List<ChecklistCategory> checklist;
  final String currency;
  final List<String> preferences;
  final List<BudgetCategory> budgetCategories;
  final String? placeId;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final String? originLabel;
  final double? originLatitude;
  final double? originLongitude;

  Trip copyWith({
    TripStatus? status,
    int? spent,
    int? budget,
    String? destination,
    String? startDate,
    String? endDate,
    int? numOfTravelers,
    String? currency,
    List<String>? images,
    List<ScheduleItem>? items,
    List<Booking>? bookings,
    List<ChecklistCategory>? checklist,
    List<String>? preferences,
    List<BudgetCategory>? budgetCategories,
    String? title,
    String? placeId,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? originLabel,
    double? originLatitude,
    double? originLongitude,
  }) => Trip(
    id: id,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    budget: budget ?? this.budget,
    spent: spent ?? this.spent,
    numOfTravelers: numOfTravelers ?? this.numOfTravelers,
    status: status ?? this.status,
    images: images ?? this.images,
    items: items ?? this.items,
    bookings: bookings ?? this.bookings,
    checklist: checklist ?? this.checklist,
    currency: currency ?? this.currency,
    preferences: preferences ?? this.preferences,
    budgetCategories: budgetCategories ?? this.budgetCategories,
    placeId: placeId ?? this.placeId,
    formattedAddress: formattedAddress ?? this.formattedAddress,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    originLabel: originLabel ?? this.originLabel,
    originLatitude: originLatitude ?? this.originLatitude,
    originLongitude: originLongitude ?? this.originLongitude,
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim().isEmpty ? destination : title,
    'destination': destination,
    'placeId': placeId,
    'formattedAddress': formattedAddress,
    'latitude': latitude,
    'longitude': longitude,
    'originLabel': originLabel,
    'originLatitude': originLatitude,
    'originLongitude': originLongitude,
    'startDate': startDate,
    'endDate': endDate,
    'budget': budget,
    'spent': spent,
    'numOfTravelers': numOfTravelers,
    'currency': currency,
    'status': status.name,
    'images': images,
    'items': items.map((item) => item.toMap()).toList(),
    'bookings': bookings.map((booking) => booking.toMap()).toList(),
    'checklist': checklist.map((category) => category.toMap()).toList(),
    'preferences': preferences,
    'budgetCategories': budgetCategories
        .map((category) => category.toMap())
        .toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Trip fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    final destination = (map['destination'] as String?) ?? 'Untitled trip';
    return Trip(
      id: doc.id,
      title: (map['title'] as String?) ?? destination,
      destination: destination,
      placeId: map['placeId'] as String?,
      formattedAddress: map['formattedAddress'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      originLabel: map['originLabel'] as String?,
      originLatitude: (map['originLatitude'] as num?)?.toDouble(),
      originLongitude: (map['originLongitude'] as num?)?.toDouble(),
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      spent: (map['spent'] as num?)?.toInt() ?? 0,
      numOfTravelers: _numOfTravelersFromMap(map),
      currency: (map['currency'] as String?) ?? 'USD',
      status: TripStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => TripStatus.upcoming,
      ),
      images: ((map['images'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      items: ((map['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => ScheduleItem.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => !_isLegacyManualStarterItem(item))
          .toList(),
      bookings: ((map['bookings'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => Booking.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      checklist: ((map['checklist'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ChecklistCategory.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      budgetCategories:
          ((map['budgetCategories'] as List<dynamic>?) ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    BudgetCategory.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
    );
  }

  static Trip fromSharedDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required List<ScheduleItem> items,
    required List<Booking> bookings,
    required List<BudgetCategory> budgetCategories,
  }) {
    final map = doc.data() ?? const <String, dynamic>{};
    final destination = (map['destination'] as String?) ?? 'Untitled trip';
    return Trip(
      id: doc.id,
      title: (map['title'] as String?) ?? destination,
      destination: destination,
      placeId: map['placeId'] as String?,
      formattedAddress: map['formattedAddress'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      originLabel: map['originLabel'] as String?,
      originLatitude: (map['originLatitude'] as num?)?.toDouble(),
      originLongitude: (map['originLongitude'] as num?)?.toDouble(),
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      spent: (map['spent'] as num?)?.toInt() ?? 0,
      numOfTravelers: _numOfTravelersFromMap(map),
      currency: (map['currency'] as String?) ?? 'USD',
      status: TripStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => TripStatus.upcoming,
      ),
      images: ((map['images'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      items: items,
      bookings: bookings,
      checklist: ((map['checklist'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ChecklistCategory.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      budgetCategories: budgetCategories,
    );
  }
}

int _numOfTravelersFromMap(Map<String, dynamic> map) {
  final value = (map['numOfTravelers'] as num?)?.toInt();
  if (value == null) return 1;
  return value.clamp(1, 99).toInt();
}

String _travelerCountLabel(int count) {
  final safeCount = count.clamp(1, 99).toInt();
  return safeCount == 1 ? '1 traveler' : '$safeCount travelers';
}

class TripMemory {
  const TripMemory({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.plannedBudget,
    required this.actualSpend,
    required this.summary,
    required this.favoritePlaces,
    required this.missedStops,
    required this.imageUrls,
    required this.archivedAtKey,
  });

  final String id;
  final String title;
  final String destination;
  final String startDate;
  final String endDate;
  final String currency;
  final int plannedBudget;
  final int actualSpend;
  final String summary;
  final List<String> favoritePlaces;
  final List<String> missedStops;
  final List<String> imageUrls;
  final String archivedAtKey;

  Map<String, dynamic> toMap() => {
    'title': title,
    'destination': destination,
    'startDate': startDate,
    'endDate': endDate,
    'currency': currency,
    'plannedBudget': plannedBudget,
    'actualSpend': actualSpend,
    'summary': summary,
    'favoritePlaces': favoritePlaces,
    'missedStops': missedStops,
    'imageUrls': imageUrls,
    'archivedAtKey': archivedAtKey,
    'archivedAt': FieldValue.serverTimestamp(),
  };

  static TripMemory fromTrip(Trip trip, {DateTime? now}) {
    final archivedAt = now ?? _travelAgentNow();
    final planned = _tripPlannedBudget(trip);
    final actual = _tripActualSpend(trip);
    final totalDays =
        _tripDateRangeDays(
          _parseTripDate(trip.startDate),
          _parseTripDate(trip.endDate),
        ) ??
        0;
    final stops = _memoryStops(trip);
    final missedStops = _memoryMissedStops(trip);
    final dateSpan = trip.startDate == trip.endDate
        ? trip.startDate
        : '${trip.startDate} to ${trip.endDate}';
    final daysLabel = totalDays <= 0 ? 'Completed trip' : '$totalDays-day trip';
    final spendLabel = planned <= 0
        ? '${trip.currency} $actual logged'
        : '${trip.currency} $actual of ${trip.currency} $planned used';

    return TripMemory(
      id: trip.id,
      title: trip.title.trim().isEmpty ? trip.destination : trip.title,
      destination: trip.destination,
      startDate: trip.startDate,
      endDate: trip.endDate,
      currency: trip.currency,
      plannedBudget: planned,
      actualSpend: actual,
      summary:
          '$daysLabel in ${trip.destination} ($dateSpan). $spendLabel across ${trip.items.length} planned stops.',
      favoritePlaces: stops.take(4).toList(growable: false),
      missedStops: missedStops.take(4).toList(growable: false),
      imageUrls: trip.images.take(3).toList(growable: false),
      archivedAtKey: _dateKey(archivedAt),
    );
  }

  static TripMemory fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return TripMemory(
      id: doc.id,
      title: (map['title'] as String?) ?? 'Trip memory',
      destination: (map['destination'] as String?) ?? 'Unknown destination',
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      currency: (map['currency'] as String?) ?? 'USD',
      plannedBudget: (map['plannedBudget'] as num?)?.toInt() ?? 0,
      actualSpend: (map['actualSpend'] as num?)?.toInt() ?? 0,
      summary: (map['summary'] as String?) ?? '',
      favoritePlaces: ((map['favoritePlaces'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      missedStops: ((map['missedStops'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      imageUrls: ((map['imageUrls'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      archivedAtKey: (map['archivedAtKey'] as String?) ?? '',
    );
  }
}

class ScheduleItem {
  const ScheduleItem(this.day, this.time, this.activity, this.type, this.cost);
  final int day;
  final String time;
  final String activity;
  final IconData type;
  final int cost;

  Map<String, dynamic> toMap() => {
    'day': day,
    'time': time,
    'activity': activity,
    'type': _iconToMap(type),
    'cost': cost,
  };

  static ScheduleItem fromMap(Map<String, dynamic> map) => ScheduleItem(
    (map['day'] as num?)?.toInt() ?? 1,
    (map['time'] as String?) ?? '',
    (map['activity'] as String?) ?? 'Activity',
    _iconFromMap(map['type']),
    (map['cost'] as num?)?.toInt() ?? 0,
  );
}

bool _isLegacyManualStarterItem(ScheduleItem item) {
  final activity = item.activity.trim().toLowerCase();
  return activity.startsWith('add arrival plan for ') ||
      activity == 'add lunch or rest stop' ||
      activity == 'add main day activity' ||
      activity == 'add afternoon activity';
}

enum _TripRuntimePhase { beforeStart, duringTrip, afterTrip, unknown }

class _TripRuntimePlan {
  const _TripRuntimePlan({
    required this.phase,
    required this.currentDay,
    required this.totalDays,
    required this.todaysItems,
    required this.nextItem,
    required this.nextItemStartAt,
  });

  final _TripRuntimePhase phase;
  final int currentDay;
  final int totalDays;
  final List<ScheduleItem> todaysItems;
  final ScheduleItem? nextItem;
  final DateTime? nextItemStartAt;

  bool get isRunningToday => phase == _TripRuntimePhase.duringTrip;
}

_TripRuntimePlan _tripRuntimePlan(Trip trip, {DateTime? now}) {
  final current = now ?? _travelAgentNow();
  final today = _dateOnly(current);
  final start = _parseTripDate(trip.startDate);
  final end = _parseTripDate(trip.endDate);
  final maxScheduleDay = trip.items.fold<int>(
    1,
    (maxDay, item) => math.max(maxDay, item.day),
  );
  final dateRangeDays = start == null || end == null || end.isBefore(start)
      ? 1
      : end.difference(start).inDays + 1;
  final totalDays = math.max(maxScheduleDay, dateRangeDays);

  final rawDay = start == null ? 1 : today.difference(start).inDays + 1;
  final currentDay = rawDay.clamp(1, totalDays);
  final phase = start == null
      ? _TripRuntimePhase.unknown
      : rawDay < 1
      ? _TripRuntimePhase.beforeStart
      : end != null && today.isAfter(end)
      ? _TripRuntimePhase.afterTrip
      : rawDay > totalDays
      ? _TripRuntimePhase.afterTrip
      : _TripRuntimePhase.duringTrip;

  final todaysItems =
      trip.items.where((item) => item.day == currentDay).toList()
        ..sort(_compareRuntimeScheduleItems);

  return _TripRuntimePlan(
    phase: phase,
    currentDay: currentDay,
    totalDays: totalDays,
    todaysItems: todaysItems,
    nextItem: _nextScheduleItem(trip, current, phase: phase),
    nextItemStartAt: _nextScheduleItemStartAt(trip, current, phase: phase),
  );
}

ScheduleItem? _nextScheduleItem(
  Trip trip,
  DateTime now, {
  required _TripRuntimePhase phase,
}) => _nextTimedScheduleItem(trip, now, phase: phase)?.item;

DateTime? _nextScheduleItemStartAt(
  Trip trip,
  DateTime now, {
  required _TripRuntimePhase phase,
}) => _nextTimedScheduleItem(trip, now, phase: phase)?.startsAt;

_TimedScheduleItem? _nextTimedScheduleItem(
  Trip trip,
  DateTime now, {
  required _TripRuntimePhase phase,
}) {
  final timedItems =
      trip.items
          .map(
            (item) =>
                _TimedScheduleItem(item, _scheduleItemStartAt(trip, item)),
          )
          .toList()
        ..sort((a, b) {
          final aStart = a.startsAt;
          final bStart = b.startsAt;
          if (aStart != null && bStart != null) return aStart.compareTo(bStart);
          if (aStart != null) return -1;
          if (bStart != null) return 1;
          return _compareRuntimeScheduleItems(a.item, b.item);
        });

  if (phase == _TripRuntimePhase.beforeStart ||
      phase == _TripRuntimePhase.unknown) {
    return timedItems.isEmpty ? null : timedItems.first;
  }
  if (phase == _TripRuntimePhase.afterTrip) return null;

  for (final item in timedItems) {
    final startsAt = item.startsAt;
    if (startsAt != null && startsAt.isAfter(now)) return item;
  }
  return null;
}

DateTime? _scheduleItemStartAt(Trip trip, ScheduleItem item) {
  final startDate = _parseTripDate(trip.startDate);
  final minutes = _parseActivityTimeMinutes(item.time);
  if (startDate == null || minutes == null) return null;
  return startDate
      .add(Duration(days: math.max(0, item.day - 1)))
      .add(Duration(minutes: minutes));
}

DateTime? _parseTripDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _compareRuntimeScheduleItems(ScheduleItem a, ScheduleItem b) {
  final dayCompare = a.day.compareTo(b.day);
  if (dayCompare != 0) return dayCompare;
  return (_parseActivityTimeMinutes(a.time) ?? 0).compareTo(
    _parseActivityTimeMinutes(b.time) ?? 0,
  );
}

int? _parseActivityTimeMinutes(String value) {
  final text = value.trim();
  final match = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0');
  if (hour == null || minute == null || minute > 59) return null;

  final meridiem = match.group(3)?.toUpperCase();
  if (meridiem == 'AM') {
    if (hour == 12) hour = 0;
  } else if (meridiem == 'PM') {
    if (hour < 12) hour += 12;
  }

  if (hour < 0 || hour > 23) return null;
  return hour * 60 + minute;
}

String _clockLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _TimedScheduleItem {
  const _TimedScheduleItem(this.item, this.startsAt);

  final ScheduleItem item;
  final DateTime? startsAt;
}

enum _ItineraryRepairKind {
  syncOngoingDates,
  fixInvalidDateRange,
  extendDateRange,
  fillEmptyDay,
  reviewDuplicateTimes,
  reviewUntimedStops,
  reviewBudget,
}

class _ItineraryRepairSuggestion {
  const _ItineraryRepairSuggestion({
    required this.kind,
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
  });

  final _ItineraryRepairKind kind;
  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;

  bool get canApply => actionLabel != null;
}

List<_ItineraryRepairSuggestion> _itineraryRepairSuggestions(
  Trip trip, {
  DateTime? now,
}) {
  final current = _dateOnly(now ?? _travelAgentNow());
  final start = _parseTripDate(trip.startDate);
  final end = _parseTripDate(trip.endDate);
  final maxScheduleDay = _maxScheduleDay(trip);
  final suggestions = <_ItineraryRepairSuggestion>[];

  if (start != null && end != null && end.isBefore(start)) {
    suggestions.add(
      const _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.fixInvalidDateRange,
        icon: Icons.event_busy_rounded,
        title: 'Date range needs repair',
        detail: 'The end date is before the start date.',
        actionLabel: 'Fix dates',
      ),
    );
  } else if (trip.status == TripStatus.ongoing &&
      start != null &&
      end != null &&
      (current.isBefore(start) || current.isAfter(end))) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.syncOngoingDates,
        icon: Icons.today_rounded,
        title: 'Active trip is not on today',
        detail: current.isBefore(start)
            ? 'This trip is marked active, but it starts on ${trip.startDate}.'
            : 'This trip is marked active, but it ended on ${trip.endDate}.',
        actionLabel: 'Sync dates',
      ),
    );
  }

  final dateRangeDays = _tripDateRangeDays(start, end);
  if (start != null &&
      dateRangeDays != null &&
      maxScheduleDay > dateRangeDays &&
      !suggestions.any(
        (item) => item.kind == _ItineraryRepairKind.fixInvalidDateRange,
      )) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.extendDateRange,
        icon: Icons.event_repeat_rounded,
        title: 'Schedule runs past dates',
        detail:
            'The schedule reaches day $maxScheduleDay, but the dates only cover $dateRangeDays day${dateRangeDays == 1 ? '' : 's'}.',
        actionLabel: 'Extend dates',
      ),
    );
  }

  final emptyDay = _firstEmptyScheduleDay(trip, dateRangeDays);
  if (emptyDay != null) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.fillEmptyDay,
        icon: Icons.add_location_alt_rounded,
        title: 'Day $emptyDay has no stops',
        detail:
            'Add at least one activity so the daily plan does not go blank.',
      ),
    );
  }

  final duplicate = _firstDuplicateScheduleTime(trip);
  if (duplicate != null) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.reviewDuplicateTimes,
        icon: Icons.schedule_rounded,
        title: 'Overlapping schedule time',
        detail:
            'Day ${duplicate.day} has more than one stop at ${duplicate.time}.',
      ),
    );
  }

  final untimedCount = trip.items
      .where(
        (item) =>
            item.time.trim().isNotEmpty &&
            _parseActivityTimeMinutes(item.time) == null,
      )
      .length;
  if (untimedCount > 0) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.reviewUntimedStops,
        icon: Icons.edit_calendar_rounded,
        title: 'Some times need cleanup',
        detail:
            '$untimedCount stop${untimedCount == 1 ? '' : 's'} use a time format the app cannot sort reliably.',
      ),
    );
  }

  final actual = _tripActualSpend(trip);
  if (trip.budget > 0 && actual > trip.budget) {
    suggestions.add(
      _ItineraryRepairSuggestion(
        kind: _ItineraryRepairKind.reviewBudget,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Budget is over plan',
        detail:
            'Spent ${trip.currency} $actual of ${trip.currency} ${trip.budget}.',
      ),
    );
  }

  return suggestions.take(4).toList(growable: false);
}

Trip _applyItineraryRepair(
  Trip trip,
  _ItineraryRepairKind kind, {
  DateTime? now,
}) {
  return switch (kind) {
    _ItineraryRepairKind.syncOngoingDates => _syncOngoingTripDatesToToday(
      trip,
      now: now,
    ),
    _ItineraryRepairKind.fixInvalidDateRange ||
    _ItineraryRepairKind.extendDateRange => _extendTripDatesToSchedule(trip),
    _ => trip,
  };
}

Trip _syncOngoingTripDatesToToday(Trip trip, {DateTime? now}) {
  final oldStart = _parseTripDate(trip.startDate);
  if (oldStart == null) return trip;

  final today = _dateOnly(now ?? _travelAgentNow());
  final runtime = _tripRuntimePlan(trip, now: today);
  final currentDay = runtime.phase == _TripRuntimePhase.afterTrip
      ? runtime.totalDays
      : runtime.currentDay;
  final newStart = today.subtract(Duration(days: math.max(0, currentDay - 1)));
  final newEnd = newStart.add(
    Duration(days: math.max(1, runtime.totalDays) - 1),
  );
  final dayOffset = newStart.difference(oldStart).inDays;

  return trip.copyWith(
    startDate: _dateKey(newStart),
    endDate: _dateKey(newEnd),
    bookings: _shiftBookingDates(trip.bookings, dayOffset),
  );
}

Trip _extendTripDatesToSchedule(Trip trip) {
  final start = _parseTripDate(trip.startDate);
  if (start == null) return trip;
  final totalDays = math.max(1, _maxScheduleDay(trip));
  final end = start.add(Duration(days: totalDays - 1));
  return trip.copyWith(endDate: _dateKey(end));
}

List<Booking> _shiftBookingDates(List<Booking> bookings, int dayOffset) {
  if (dayOffset == 0) return bookings;
  return bookings
      .map((booking) {
        final date = _parseTripDate(booking.date);
        if (date == null) return booking;
        return Booking(
          booking.title,
          _dateKey(date.add(Duration(days: dayOffset))),
          booking.time,
          booking.reference,
          booking.cost,
          booking.icon,
        );
      })
      .toList(growable: false);
}

int _maxScheduleDay(Trip trip) {
  return trip.items.fold<int>(1, (maxDay, item) => math.max(maxDay, item.day));
}

int? _tripDateRangeDays(DateTime? start, DateTime? end) {
  if (start == null || end == null || end.isBefore(start)) return null;
  return end.difference(start).inDays + 1;
}

int? _firstEmptyScheduleDay(Trip trip, int? dateRangeDays) {
  final totalDays = math.min(
    math.max(dateRangeDays ?? _maxScheduleDay(trip), 1),
    14,
  );
  if (totalDays <= 1) return null;
  final daysWithStops = trip.items.map((item) => item.day).toSet();
  for (var day = 1; day <= totalDays; day++) {
    if (!daysWithStops.contains(day)) return day;
  }
  return null;
}

({int day, String time})? _firstDuplicateScheduleTime(Trip trip) {
  final seen = <String>{};
  final items = [...trip.items]..sort(_compareRuntimeScheduleItems);
  for (final item in items) {
    final minutes = _parseActivityTimeMinutes(item.time);
    if (minutes == null) continue;
    final key = '${item.day}-$minutes';
    if (!seen.add(key)) return (day: item.day, time: item.time);
  }
  return null;
}

int _tripActualSpend(Trip trip) {
  if (trip.budgetCategories.isNotEmpty) {
    return trip.budgetCategories.fold<int>(
      0,
      (total, category) => total + category.effectiveActual,
    );
  }
  return trip.spent;
}

int _tripPlannedBudget(Trip trip) {
  if (trip.budgetCategories.isNotEmpty) {
    final categoryTotal = trip.budgetCategories.fold<int>(
      0,
      (total, category) => total + category.planned,
    );
    if (categoryTotal > 0) return categoryTotal;
  }
  return trip.budget;
}

enum _BudgetGuardianSeverity { calm, watch, warning }

class _BudgetGuardianInsight {
  const _BudgetGuardianInsight({
    required this.severity,
    required this.icon,
    required this.title,
    required this.detail,
    required this.tripProgressPercent,
    required this.spendPercent,
    required this.plannedTotal,
    required this.actualTotal,
    required this.categories,
  });

  final _BudgetGuardianSeverity severity;
  final IconData icon;
  final String title;
  final String detail;
  final int tripProgressPercent;
  final int spendPercent;
  final int plannedTotal;
  final int actualTotal;
  final List<BudgetCategory> categories;
}

_BudgetGuardianInsight _budgetGuardianInsight(
  Trip trip, {
  required List<BudgetCategory> categories,
  DateTime? now,
}) {
  final runtime = _tripRuntimePlan(trip, now: now);
  final planned = trip.budget > 0
      ? trip.budget
      : categories.fold<int>(0, (total, item) => total + item.planned);
  final actual = categories.fold<int>(
    0,
    (total, item) => total + item.effectiveActual,
  );
  final progress = switch (runtime.phase) {
    _TripRuntimePhase.beforeStart || _TripRuntimePhase.unknown => 0.0,
    _TripRuntimePhase.afterTrip => 1.0,
    _TripRuntimePhase.duringTrip =>
      runtime.totalDays <= 0 ? 0.0 : runtime.currentDay / runtime.totalDays,
  };
  final spendRatio = planned <= 0 ? 0.0 : actual / planned;
  final worstCategory = _highestBudgetRiskCategory(categories);
  final progressPercent = (progress * 100).round().clamp(0, 100);
  final spendPercent = (spendRatio * 100).round();

  if (planned > 0 && actual > planned) {
    return _BudgetGuardianInsight(
      severity: _BudgetGuardianSeverity.warning,
      icon: Icons.warning_amber_rounded,
      title: 'Budget limit crossed',
      detail:
          'You are at $spendPercent% of budget. Tighten the next paid stops or rebalance categories.',
      tripProgressPercent: progressPercent,
      spendPercent: spendPercent,
      plannedTotal: planned,
      actualTotal: actual,
      categories: categories,
    );
  }

  if (planned > 0 && spendRatio > progress + .15) {
    final categoryText = worstCategory == null
        ? 'overall budget'
        : '${worstCategory.category.toLowerCase()} budget';
    return _BudgetGuardianInsight(
      severity: _BudgetGuardianSeverity.warning,
      icon: Icons.account_balance_wallet_rounded,
      title: 'Spending is ahead of pace',
      detail:
          'You are $progressPercent% through the trip but used $spendPercent% of $categoryText.',
      tripProgressPercent: progressPercent,
      spendPercent: spendPercent,
      plannedTotal: planned,
      actualTotal: actual,
      categories: categories,
    );
  }

  if (worstCategory != null &&
      worstCategory.planned > 0 &&
      worstCategory.effectiveActual / worstCategory.planned > .85) {
    final categoryPercent =
        (worstCategory.effectiveActual / worstCategory.planned * 100).round();
    return _BudgetGuardianInsight(
      severity: _BudgetGuardianSeverity.watch,
      icon: Icons.savings_rounded,
      title: '${worstCategory.category} is getting tight',
      detail:
          '$categoryPercent% of this category is already used. Keep the next few choices lighter.',
      tripProgressPercent: progressPercent,
      spendPercent: spendPercent,
      plannedTotal: planned,
      actualTotal: actual,
      categories: categories,
    );
  }

  final remaining = math.max(0, planned - actual);
  return _BudgetGuardianInsight(
    severity: _BudgetGuardianSeverity.calm,
    icon: Icons.verified_rounded,
    title: 'Budget pace looks okay',
    detail:
        'You have ${trip.currency} $remaining left against the current plan.',
    tripProgressPercent: progressPercent,
    spendPercent: spendPercent,
    plannedTotal: planned,
    actualTotal: actual,
    categories: categories,
  );
}

BudgetCategory? _highestBudgetRiskCategory(List<BudgetCategory> categories) {
  final usable = categories.where((item) => item.planned > 0).toList();
  if (usable.isEmpty) return null;
  usable.sort(
    (a, b) => (b.effectiveActual / b.planned).compareTo(
      a.effectiveActual / a.planned,
    ),
  );
  return usable.first;
}

List<String> _memoryStops(Trip trip) {
  final seen = <String>{};
  final stops = <String>[];
  final prioritized = [
    ...trip.items.where(
      (item) =>
          item.type == Icons.place_rounded ||
          item.type == Icons.restaurant_rounded ||
          item.type == Icons.museum_rounded ||
          item.type == Icons.park_rounded ||
          item.type == Icons.shopping_bag_rounded,
    ),
    ...trip.items,
  ];

  for (final item in prioritized) {
    final label = item.activity.trim();
    if (label.isEmpty || !seen.add(label.toLowerCase())) continue;
    stops.add(label);
  }
  return stops;
}

List<String> _memoryMissedStops(Trip trip) {
  final lastDay =
      _tripDateRangeDays(
        _parseTripDate(trip.startDate),
        _parseTripDate(trip.endDate),
      ) ??
      0;
  if (lastDay <= 0) return const [];
  return trip.items
      .where((item) => item.day > lastDay)
      .map((item) => item.activity.trim())
      .where((activity) => activity.isNotEmpty)
      .toList(growable: false);
}

class Booking {
  const Booking(
    this.title,
    this.date,
    this.time,
    this.reference,
    this.cost,
    this.icon,
  );
  final String title;
  final String date;
  final String time;
  final String reference;
  final int cost;
  final IconData icon;

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': date,
    'time': time,
    'reference': reference,
    'cost': cost,
    'icon': _iconToMap(icon),
  };

  static Booking fromMap(Map<String, dynamic> map) => Booking(
    (map['title'] as String?) ?? 'Booking',
    (map['date'] as String?) ?? '',
    (map['time'] as String?) ?? '',
    (map['reference'] as String?) ?? '',
    (map['cost'] as num?)?.toInt() ?? 0,
    _iconFromMap(map['icon'] ?? map['type']),
  );
}

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.category,
    required this.planned,
    required this.actual,
    this.spendings = const [],
  });

  final String id;
  final String category;
  final int planned;
  final int actual;
  final List<BudgetSpending> spendings;

  int get effectiveActual => spendings.isEmpty
      ? actual
      : spendings.fold<int>(0, (total, spending) => total + spending.amount);

  BudgetCategory copyWith({
    int? planned,
    int? actual,
    List<BudgetSpending>? spendings,
  }) => BudgetCategory(
    id: id,
    category: category,
    planned: planned ?? this.planned,
    actual: actual ?? this.actual,
    spendings: spendings ?? this.spendings,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'planned': planned,
    'actual': effectiveActual,
    'spendings': spendings.map((spending) => spending.toMap()).toList(),
  };

  static BudgetCategory fromMap(Map<String, dynamic> map) {
    final spendings = ((map['spendings'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) => BudgetSpending.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final actual = (map['actual'] as num?)?.toInt() ?? 0;
    return BudgetCategory(
      id: (map['id'] as String?) ?? 'category',
      category: (map['category'] as String?) ?? 'Category',
      planned: (map['planned'] as num?)?.toInt() ?? 0,
      actual: spendings.isEmpty
          ? actual
          : spendings.fold<int>(
              0,
              (total, spending) => total + spending.amount,
            ),
      spendings: spendings,
    );
  }
}

class BudgetSpending {
  const BudgetSpending({
    required this.id,
    required this.title,
    required this.amount,
    this.date = '',
    this.note = '',
  });

  final String id;
  final String title;
  final int amount;
  final String date;
  final String note;

  BudgetSpending copyWith({
    String? title,
    int? amount,
    String? date,
    String? note,
  }) => BudgetSpending(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    note: note ?? this.note,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date,
    'note': note,
  };

  static BudgetSpending fromMap(Map<String, dynamic> map) => BudgetSpending(
    id: (map['id'] as String?) ?? 'spending',
    title: (map['title'] as String?) ?? 'Spending',
    amount: (map['amount'] as num?)?.toInt() ?? 0,
    date: (map['date'] as String?) ?? '',
    note: (map['note'] as String?) ?? '',
  );
}

class ChecklistCategory {
  const ChecklistCategory(this.category, this.items);
  final String category;
  final List<String> items;

  Map<String, dynamic> toMap() => {'category': category, 'items': items};

  static ChecklistCategory fromMap(Map<String, dynamic> map) =>
      ChecklistCategory(
        (map['category'] as String?) ?? 'Checklist',
        ((map['items'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}

const _aiChecklistMarker = '[AI] ';

bool _isAiChecklistItem(String item) =>
    item.trimLeft().startsWith(_aiChecklistMarker);

String _checklistDisplayText(String item) {
  final trimmed = item.trimLeft();
  if (!trimmed.startsWith(_aiChecklistMarker)) return item;
  return trimmed.substring(_aiChecklistMarker.length).trimLeft();
}

String _aiChecklistItem(String item) {
  final display = _checklistDisplayText(item).trim();
  if (display.isEmpty) return _aiChecklistMarker.trimRight();
  return '$_aiChecklistMarker$display';
}

String _checklistCompareText(String item) => _checklistDisplayText(
  item,
).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

Map<String, dynamic> _iconToMap(IconData icon) => {'name': _iconName(icon)};

IconData _iconFromMap(Object? value) {
  if (value is String) return _iconByName(value);
  if (value is! Map) return Icons.place_rounded;
  final map = Map<String, dynamic>.from(value);
  return _iconByName(map['name'] as String?);
}

String _iconName(IconData icon) {
  if (icon == Icons.train_rounded) return 'train';
  if (icon == Icons.restaurant_rounded) return 'restaurant';
  if (icon == Icons.hiking_rounded) return 'hiking';
  if (icon == Icons.temple_buddhist_rounded) return 'temple';
  if (icon == Icons.directions_walk_rounded) return 'walk';
  if (icon == Icons.flight_takeoff_rounded) return 'flight';
  if (icon == Icons.hotel_rounded) return 'hotel';
  if (icon == Icons.museum_rounded) return 'museum';
  if (icon == Icons.beach_access_rounded) return 'beach';
  if (icon == Icons.local_cafe_rounded) return 'cafe';
  if (icon == Icons.shopping_bag_rounded) return 'shopping';
  if (icon == Icons.cloud_rounded) return 'cloud';
  return 'place';
}

IconData _iconByName(String? name) {
  switch (name) {
    case 'train':
      return Icons.train_rounded;
    case 'food':
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'hiking':
    case 'nature':
      return Icons.hiking_rounded;
    case 'temple':
      return Icons.temple_buddhist_rounded;
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    case 'museum':
      return Icons.museum_rounded;
    case 'beach':
      return Icons.beach_access_rounded;
    case 'cafe':
      return Icons.local_cafe_rounded;
    case 'shopping':
      return Icons.shopping_bag_rounded;
    case 'cloud':
      return Icons.cloud_rounded;
    case 'place':
      return Icons.place_rounded;
    default:
      return Icons.place_rounded;
  }
}
