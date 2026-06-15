part of travel_agent_app;

class TravelAssistantService {
  TravelAssistantService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _chatTimeout = Duration(seconds: 20);
  static const _createTripReplyTimeout = Duration(seconds: 35);
  static const _tripPlanTimeout = Duration(seconds: 35);
  static const _scheduleStopTimeout = Duration(seconds: 18);
  static const _dayPlanEditTimeout = Duration(seconds: 28);

  final FirebaseFunctions _functions;
  final _deviceContext = AppDeviceContextService();

  Future<List<String>> recommendDestinationNames({
    required UserProfile user,
    required List<TripMemory> memories,
    required List<Destination> candidates,
  }) async {
    final candidateNames = candidates
        .map((destination) => destination.name)
        .toList(growable: false);
    if (candidateNames.isEmpty) return const [];
    final ratings = memories
        .where((memory) => memory.rating != null)
        .map(
          (memory) => {
            'destination': memory.destination,
            'rating': memory.rating,
            'feedback': memory.feedback,
          },
        )
        .toList(growable: false);
    final input = {
      'interests': user.interests,
      'travelPace': user.travelPace,
      'favoritePlaces': user.favoritePlaces
          .map((place) => place.name)
          .toList(growable: false),
      'tripRatings': ratings,
      'candidates': candidateNames,
    };

    final callable = _functions.httpsCallable('recommendDestinations');
    final response = await callable
        .call<Map<String, dynamic>>(input)
        .timeout(_chatTimeout);
    final data = response.data;

    final allowed = candidateNames.toSet();
    return ((data['destinations'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .where(allowed.contains)
        .toSet()
        .take(5)
        .toList(growable: false);
  }

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';
    final appContext = await _deviceContext.load(
      requestLocation: _messageNeedsLocation(trimmed),
    );

    final callable = _functions.httpsCallable('chatWithAssistant');
    final response = await callable
        .call<Map<String, dynamic>>({
          'message': trimmed,
          'appContext': appContext.toAiMap(),
        })
        .timeout(_chatTimeout);
    return (response.data['reply'] as String?)?.trim() ?? '';
  }

  Future<GeneratedTripPlan> generateTripPlan({
    required PlaceSuggestion place,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required int numOfTravelers,
    required List<String> preferences,
    required String currency,
    required String profileLanguage,
    AppDeviceContext? appContext,
    TripStartLocation? startLocation,
    String airline = '',
    String flightConfirmation = '',
  }) async {
    final resolvedAppContext =
        appContext ?? await _deviceContext.load(requestLocation: true);
    final tripStartLocation =
        startLocation ?? TripStartLocation.fromContext(resolvedAppContext);
    final outputLanguage = _aiLanguageName(profileLanguage);
    final callable = _functions.httpsCallable('generateTripPlan');
    final response = await callable
        .call<Map<String, dynamic>>({
          'place': {
            'name': place.name,
            'formatted': place.formatted,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'placeId': place.placeId,
            'country': place.country,
          },
          'startDate': _dateKey(startDate),
          'endDate': _dateKey(endDate),
          'budget': budget,
          'numOfTravelers': numOfTravelers,
          'preferences': preferences,
          'currency': currency,
          'profileLanguage': profileLanguage,
          'outputLanguage': outputLanguage,
          'airline': airline,
          'flightConfirmation': flightConfirmation,
          'startLocation': tripStartLocation?.toAiMap(),
          'appContext': resolvedAppContext.toAiMap(),
        })
        .timeout(_tripPlanTimeout);
    final data = response.data['plan'] is Map
        ? Map<String, dynamic>.from(response.data['plan'] as Map)
        : response.data;
    return _planWithTripTransport(
      GeneratedTripPlan.fromMap(data),
      place: place,
      startDate: startDate,
      endDate: endDate,
      startLocation: tripStartLocation,
      currency: currency,
      preferences: preferences,
    );
  }

  Future<ScheduleItem> generateScheduleStop({
    required Trip trip,
    required int day,
    required String description,
  }) async {
    final trimmed = description.trim();
    final appContext = await _deviceContext.load(
      requestLocation: _messageNeedsLocation(trimmed),
    );
    final input = {
      'destination': trip.destination,
      'startDate': trip.startDate,
      'endDate': trip.endDate,
      'currency': trip.currency,
      'budget': trip.budget,
      'numOfTravelers': trip.numOfTravelers,
      'preferences': trip.preferences,
      'targetDay': day,
      'request': trimmed.isEmpty ? 'Suggest a useful trip stop.' : trimmed,
      'existingSchedule': trip.items
          .map(
            (item) => {
              'day': item.day,
              'time': item.time,
              'activity': item.activity,
              'type': _iconName(item.type),
              'cost': item.cost,
            },
          )
          .toList(),
      'appContext': appContext.toAiMap(),
    };

    final callable = _functions.httpsCallable('generateScheduleStop');
    final response = await callable
        .call<Map<String, dynamic>>({'tripId': trip.id, ...input})
        .timeout(_scheduleStopTimeout);
    final data = response.data['item'] is Map
        ? Map<String, dynamic>.from(response.data['item'] as Map)
        : response.data;
    return _scheduleItemFromAiMap(data, fallbackDay: day);
  }

  Future<DayPlanEditResult> generateDayPlanEdit({
    required Trip trip,
    required int day,
    required String placeRequest,
  }) async {
    final trimmed = placeRequest.trim();
    if (trimmed.isEmpty) {
      throw Exception('Place is required.');
    }
    final appContext = await _deviceContext.load(requestLocation: false);
    final input = {
      'destination': trip.destination,
      'startDate': trip.startDate,
      'endDate': trip.endDate,
      'currency': trip.currency,
      'budget': trip.budget,
      'numOfTravelers': trip.numOfTravelers,
      'preferences': trip.preferences,
      'targetDay': day,
      'placeRequest': trimmed,
      'targetDaySchedule': trip.items
          .where((item) => item.day == day)
          .map(_scheduleItemToAiMap)
          .toList(),
      'fullSchedule': trip.items.map(_scheduleItemToAiMap).toList(),
      'appContext': appContext.toAiMap(),
    };

    final callable = _functions.httpsCallable('generateDayPlanEdit');
    final response = await callable
        .call<Map<String, dynamic>>({'tripId': trip.id, ...input})
        .timeout(_dayPlanEditTimeout);
    final data = response.data['result'] is Map
        ? Map<String, dynamic>.from(response.data['result'] as Map)
        : response.data;
    return DayPlanEditResult.fromMap(data, fallbackDay: day);
  }

  Future<CreateTripAiResponse> createTripReply({
    required String message,
    required CreateTripDraft currentDraft,
    required List<CreateTripChatMessage> history,
    required String profileLanguage,
  }) async {
    final appContext = await _deviceContext.load(
      requestLocation: _messageNeedsLocation(message),
    );
    final outputLanguage = _aiLanguageName(profileLanguage);
    final callable = _functions.httpsCallable('createTripReply');
    final response = await callable
        .call<Map<String, dynamic>>({
          'message': message,
          'currentDraft': currentDraft.toAiMap(),
          'history': history.reversed
              .take(8)
              .toList()
              .reversed
              .map(
                (item) => {
                  'role': item.fromUser ? 'user' : 'assistant',
                  'text': item.text,
                },
              )
              .toList(),
          'today': _dateKey(appContext.today),
          'profileLanguage': profileLanguage,
          'outputLanguage': outputLanguage,
          'appContext': appContext.toAiMap(),
        })
        .timeout(_createTripReplyTimeout);
    final data = response.data['reply'] is Map
        ? Map<String, dynamic>.from(response.data['reply'] as Map)
        : response.data;
    return CreateTripAiResponse.fromMap(data, fallbackDraft: currentDraft);
  }
}

ScheduleItem _scheduleItemFromAiMap(
  Map<String, dynamic> data, {
  required int fallbackDay,
}) {
  final item = ScheduleItem.fromMap(data);
  return ScheduleItem(
    item.day <= 0 ? fallbackDay : item.day,
    item.time.trim().isEmpty ? '10:00 AM' : item.time,
    item.activity.trim().isEmpty ? 'Suggested stop' : item.activity,
    item.type,
    item.cost < 0 ? 0 : item.cost,
  );
}

Map<String, dynamic> _scheduleItemToAiMap(ScheduleItem item) => {
  'day': item.day,
  'time': item.time,
  'activity': item.activity,
  'type': _iconName(item.type),
  'cost': item.cost,
};

class DayPlanEditResult {
  const DayPlanEditResult({
    required this.feasible,
    required this.warning,
    required this.items,
  });

  final bool feasible;
  final String warning;
  final List<ScheduleItem> items;

  static DayPlanEditResult fromMap(
    Map<String, dynamic> map, {
    required int fallbackDay,
  }) {
    final items = ((map['items'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final parsed = _scheduleItemFromAiMap(
            Map<String, dynamic>.from(item),
            fallbackDay: fallbackDay,
          );
          return ScheduleItem(
            fallbackDay,
            parsed.time,
            parsed.activity,
            parsed.type,
            parsed.cost,
          );
        })
        .take(8)
        .toList();
    return DayPlanEditResult(
      feasible: map['feasible'] == true,
      warning: (map['warning'] as String?)?.trim() ?? '',
      items: items,
    );
  }
}

String _aiLanguageName(String profileLanguage) {
  return switch (profileLanguage) {
    'id' => 'Indonesian',
    'zh' || 'zh_Hant_TW' || 'zh-TW' => 'Traditional Chinese',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'es' => 'Spanish',
    'fr' => 'French',
    'de' => 'German',
    'it' => 'Italian',
    'pt' => 'Portuguese',
    'th' => 'Thai',
    'vi' => 'Vietnamese',
    'ar' => 'Arabic',
    _ => 'English',
  };
}

bool _messageNeedsLocation(String message) {
  final text = message.toLowerCase();
  return text.contains('near me') ||
      text.contains('nearby') ||
      text.contains('around me') ||
      text.contains('my location') ||
      text.contains('where i am') ||
      text.contains('current location');
}

class GeneratedTripPlan {
  const GeneratedTripPlan({
    required this.items,
    required this.bookings,
    required this.checklist,
  });

  final List<ScheduleItem> items;
  final List<Booking> bookings;
  final List<ChecklistCategory> checklist;

  static GeneratedTripPlan fromMap(Map<String, dynamic> map) {
    final items = ((map['items'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return ScheduleItem(
            (data['day'] as num?)?.toInt() ?? 1,
            (data['time'] as String?) ?? '09:00 AM',
            (data['activity'] as String?) ?? 'Explore local highlights',
            _iconByName(data['type'] as String?),
            (data['cost'] as num?)?.toInt() ?? 0,
          );
        })
        .take(24)
        .toList();

    final bookings = ((map['bookings'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((booking) {
          final data = Map<String, dynamic>.from(booking);
          return Booking(
            (data['title'] as String?) ?? 'Trip booking',
            (data['date'] as String?) ?? '',
            (data['time'] as String?) ?? '',
            (data['reference'] as String?) ?? 'TBD',
            (data['cost'] as num?)?.toInt() ?? 0,
            _iconByName(data['type'] as String?),
          );
        })
        .take(4)
        .toList();

    final checklist = ((map['checklist'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((category) {
          final data = Map<String, dynamic>.from(category);
          return ChecklistCategory(
            (data['category'] as String?) ?? 'Essentials',
            ((data['items'] as List<dynamic>?) ?? const [])
                .whereType<String>()
                .take(8)
                .toList(),
          );
        })
        .where((category) => category.items.isNotEmpty)
        .take(5)
        .toList();

    return GeneratedTripPlan(
      items: items,
      bookings: bookings,
      checklist: checklist,
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
