part of travel_agent_app;

class TravelAssistantService {
  TravelAssistantService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _chatTimeout = Duration(seconds: 20);
  static const _createTripReplyTimeout = Duration(seconds: 30);
  static const _tripPlanTimeout = Duration(seconds: 30);
  static const _scheduleStopTimeout = Duration(seconds: 18);
  static const _dayPlanEditTimeout = Duration(seconds: 28);
  static const _transportRecommendationsTimeout = Duration(seconds: 35);
  static const _fastChatModel = 'gpt-5.4-mini';
  static const _smartItineraryModel = _fastChatModel;

  final FirebaseFunctions _functions;
  final _deviceContext = AppDeviceContextService();

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';
    final appContext = await _deviceContext.load(
      requestLocation: _messageNeedsLocation(trimmed),
    );

    if (LocalApiKeys.hasOpenAiApiKey) {
      return _sendMessageDirectly(trimmed, appContext);
    }

    final callable = _functions.httpsCallable('chatWithAssistant');
    final response = await callable
        .call<Map<String, dynamic>>({
          'message': trimmed,
          'appContext': appContext.toAiMap(),
        })
        .timeout(_chatTimeout);
    return (response.data['reply'] as String?)?.trim() ?? '';
  }

  Future<String> _sendMessageDirectly(
    String message,
    AppDeviceContext appContext,
  ) async {
    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _fastChatModel,
            'instructions':
                'You are a concise travel planning assistant inside a mobile app. '
                'Help with schedule order, budget tradeoffs, packing, food, '
                'transit, and practical destination advice. Keep replies friendly '
                'and short. Use appContext.localDate, appContext.localTime, and '
                'appContext.timeZoneOffset as the source of truth for today and '
                'relative dates. Use appContext.location only for near-me or '
                'location-aware requests.',
            'input': jsonEncode({
              'message': message,
              'appContext': appContext.toAiMap(),
            }),
            'store': false,
            'reasoning': {'effort': 'low'},
            'text': {'verbosity': 'low'},
          }),
        )
        .timeout(_chatTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI chat is unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final outputText = body['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final output = (body['output'] as List<dynamic>?) ?? const [];
    return output
        .whereType<Map>()
        .expand((item) => (item['content'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((content) => content['text'])
        .whereType<String>()
        .join('\n')
        .trim();
  }

  Future<GeneratedTripPlan> generateTripPlan({
    required PlaceSuggestion place,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required String groupType,
    required List<String> preferences,
    required String currency,
    required String profileLanguage,
    AppDeviceContext? appContext,
    TripStartLocation? startLocation,
    String airline = '',
    String flightCode = '',
    String flightDepartureTime = '',
    String flightDeparturePlace = '',
    String flightLandingTime = '',
    String flightLandingPlace = '',
  }) async {
    final resolvedAppContext =
        appContext ?? await _deviceContext.load(requestLocation: true);
    final tripStartLocation =
        startLocation ?? TripStartLocation.fromContext(resolvedAppContext);
    final outputLanguage = _aiLanguageName(profileLanguage);
    if (!LocalApiKeys.hasOpenAiApiKey) {
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
            'groupType': groupType,
            'preferences': preferences,
            'currency': currency,
            'profileLanguage': profileLanguage,
            'outputLanguage': outputLanguage,
            'airline': airline,
            'flightCode': flightCode,
            'flightDepartureTime': flightDepartureTime,
            'flightDeparturePlace': flightDeparturePlace,
            'flightLandingTime': flightLandingTime,
            'flightLandingPlace': flightLandingPlace,
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

    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _smartItineraryModel,
            'instructions': [
              'Generate a practical travel schedule as strict JSON only.',
              'Use current attraction names for the destination.',
              'Keep costs realistic but approximate.',
              'Treat selected tags and custom preference tags as concrete itinerary requirements, not decorative labels.',
              'For each distinctive tag, include at least one matching schedule item, venue area, event search, food stop, accessibility choice, or practical constraint.',
              'For example, anime should trigger anime convention/event-calendar research when dates match, or anime districts, stores, themed cafes, arcades, museums, or pop-culture stops when no convention is current.',
              'Halal food should trigger halal restaurants or Muslim-friendly food areas. Wheelchair access should trigger accessible transit and step-free venues.',
              'Use appContext.localDate and appContext.timeZoneOffset as today context.',
              'Use startLocation as the trip origin when provided. If startLocation is missing, use appContext.location when available.',
              'If startLocation has an address, use that address as the origin reference; do not show raw coordinates in user-facing itinerary text.',
              'Use web search to identify the nearest practical station, bus stop, airport, ferry terminal, HSR/rail station, or transit hub from the origin address before recommending transport to the destination.',
              'Distribute activities across every date in the trip. Do not leave middle or later days empty.',
              'For trips of 3 or more days, include at least 4 useful schedule items on every full sightseeing day; do not make later days thinner or more generic than earlier days.',
              'Day 1 must start with realistic transportation from the trip origin to the destination before destination activities.',
              'The final trip day must include realistic return transportation home after the destination activities.',
              'Every day must include realistic place-to-place movement between separated stops, such as walk, metro, taxi, train, airport transfer, or buffer time before the next venue.',
              'Do not list attractions back-to-back as if travel time is zero. Leave realistic gaps for transit, walking, queues, family pacing, meals, check-in, check-out, airport security, and baggage.',
              'If exact public transport schedules or flight times are uncertain, say to confirm the exact operator/time instead of presenting the time as guaranteed.',
              'If flight details include departure or landing time/place, treat those as fixed user-provided constraints and build airport transfers and sightseeing around them.',
              'For international trips, do not end the itinerary at sightseeing. Add pack-up, airport or station transfer, departure, arrival, and return-home steps when the trip ends.',
              'For a one-day trip, do not add hotel stays or hotel bookings unless the user explicitly asks for lodging.',
              'When moving to a different city or district, or when returning home, include pack-up/preparation wording before the transport.',
              'Choose transport by distance: local transit/taxi for nearby trips, train/bus/high-speed rail for regional trips, and flights only for genuinely long-distance trips.',
              'Never suggest a plane for short regional travel such as Hsinchu to Taipei.',
              'Use current-known attraction names, transportation options, ticket prices, and local food costs.',
              'Use specific real place names or clearly named local areas. Do not use generic stop titles like "signature landmark visit", "historic district walk", "scenic viewpoint stop", or "local scene stop" unless the title also includes the actual venue or district name.',
              'When the destination name has multiple comma-separated parts, keep enough administrative context to avoid choosing a different city with the same name.',
              'Do not spend time finding coordinates, addresses, or images. The app maps stops later in the background.',
              'When live data may vary, mark times, prices, and operator details as approximate and tell the user to confirm before departure.',
              'Use ordinary local price ranges for meals. Do not price a normal Taipei local lunch at TWD 700 unless it is fine dining, a multi-person/shared meal, or explicitly expensive.',
              'Write all user-facing itinerary text in $outputLanguage.',
              'Do not infer language from currency; currency only controls money.',
              'Return no markdown and no explanation.',
            ].join(' '),
            'input': jsonEncode({
              'destination': place.name,
              'formattedAddress': place.formatted,
              'destinationLocation': {
                'latitude': place.latitude,
                'longitude': place.longitude,
              },
              'startDate': _dateKey(startDate),
              'endDate': _dateKey(endDate),
              'budgetUsd': budget,
              'currency': currency,
              'profileLanguage': profileLanguage,
              'outputLanguage': outputLanguage,
              'groupType': groupType,
              'preferences': preferences,
              'flight': {
                'airline': airline,
                'flightNumber': flightCode,
                'departureTime': flightDepartureTime,
                'departurePlace': flightDeparturePlace,
                'landingTime': flightLandingTime,
                'landingPlace': flightLandingPlace,
              },
              'startLocation': tripStartLocation?.toAiMap(),
              'appContext': resolvedAppContext.toAiMap(),
              'schema': {
                'items': [
                  {
                    'day': 1,
                    'time': '09:00 AM',
                    'activity': 'Activity name',
                    'type': 'place|food|walk|museum|beach|shopping|train',
                    'cost': 25,
                  },
                ],
                'bookings': [
                  {
                    'title': 'Hotel or transport booking',
                    'date': 'YYYY-MM-DD',
                    'time': '15:00',
                    'reference': 'short reference',
                    'cost': 300,
                    'type': 'hotel|flight|train|place',
                  },
                ],
                'checklist': [
                  {
                    'category': 'Essentials',
                    'items': ['Passport'],
                  },
                ],
              },
            }),
            'store': false,
            'reasoning': {'effort': 'low'},
            'text': {'verbosity': 'low', 'format': _tripPlanTextFormat()},
          }),
        )
        .timeout(_tripPlanTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI schedule generation failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _responseOutputText(body);
    final data = _decodeJsonObject(text);
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
      'groupType': trip.groupType,
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

    if (!LocalApiKeys.hasOpenAiApiKey) {
      final callable = _functions.httpsCallable('generateScheduleStop');
      final response = await callable
          .call<Map<String, dynamic>>(input)
          .timeout(_scheduleStopTimeout);
      final data = response.data['item'] is Map
          ? Map<String, dynamic>.from(response.data['item'] as Map)
          : response.data;
      return _scheduleItemFromAiMap(data, fallbackDay: day);
    }

    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _smartItineraryModel,
            'instructions': [
              'Generate exactly one practical schedule stop as strict JSON only.',
              'Fit it into the requested trip day without duplicating existing stops.',
              'Use current local time and location only if the user asks for nearby or location-aware help.',
              'Keep the activity title concise and specific.',
              'Return no markdown and no explanation.',
            ].join(' '),
            'input': jsonEncode(input),
            'store': false,
            'reasoning': {'effort': 'low'},
            'text': {'verbosity': 'low', 'format': _scheduleStopTextFormat()},
          }),
        )
        .timeout(_scheduleStopTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI stop generation failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _scheduleItemFromAiMap(
      _decodeJsonObject(_responseOutputText(body)),
      fallbackDay: day,
    );
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
    final targetDaySchedule = trip.items
        .where((item) => item.day == day)
        .map(_scheduleItemToAiMap)
        .toList();
    final input = {
      'destination': trip.destination,
      'startDate': trip.startDate,
      'endDate': trip.endDate,
      'currency': trip.currency,
      'budget': trip.budget,
      'groupType': trip.groupType,
      'preferences': trip.preferences,
      'targetDay': day,
      'placeRequest': trimmed,
      'targetDaySchedule': targetDaySchedule,
      'fullSchedule': trip.items.map(_scheduleItemToAiMap).toList(),
      'appContext': appContext.toAiMap(),
    };

    if (!LocalApiKeys.hasOpenAiApiKey) {
      final callable = _functions.httpsCallable('generateDayPlanEdit');
      final response = await callable
          .call<Map<String, dynamic>>(input)
          .timeout(_dayPlanEditTimeout);
      final data = response.data['result'] is Map
          ? Map<String, dynamic>.from(response.data['result'] as Map)
          : response.data;
      return DayPlanEditResult.fromMap(data, fallbackDay: day);
    }

    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _smartItineraryModel,
            'instructions': [
              'You are editing one day of a travel itinerary inside a mobile app.',
              'First judge whether the requested place can realistically fit into the target day.',
              'Consider existing stop density, time gaps, route geography, city/region distance, opening hours when searchable, and whether adding the place would make the day rushed or impossible.',
              'Treat broad but valid requests such as "anime convention", "food market", "PC store", or "festival" as category searches in or near the destination and target date; do not reject them just because they are not exact venue names.',
              'For event requests, search event calendars where possible. If no exact event is confirmed for the target date, add a practical event-calendar check or relevant district/venue alternative and include a warning to verify dates/tickets.',
              'If the request is too far, impossible, or the day is already too packed, set feasible=false, keep items as the existing target day schedule, and write a concise warning explaining why.',
              'If feasible=true, return the complete revised target-day schedule with realistic times, preserving useful existing stops and adding the requested place in an efficient route order.',
              'Do not move the requested place to another day unless warning says it should be planned on a different day.',
              'Return no markdown and no explanation.',
            ].join(' '),
            'input': jsonEncode(input),
            'store': false,
            'tools': [
              {
                'type': 'web_search',
                'search_context_size': 'low',
                'external_web_access': true,
              },
            ],
            'tool_choice': 'required',
            'reasoning': {'effort': 'low'},
            'text': {'verbosity': 'low', 'format': _dayPlanEditTextFormat()},
          }),
        )
        .timeout(_dayPlanEditTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI day edit failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DayPlanEditResult.fromMap(
      _decodeJsonObject(_responseOutputText(body)),
      fallbackDay: day,
    );
  }

  Future<TransportRecommendationResult> generateTransportRecommendations({
    required String origin,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String currency,
    required String groupType,
  }) async {
    final appContext = await _deviceContext.load(requestLocation: false);
    final input = {
      'origin': origin,
      'destination': destination,
      'startDate': _dateKey(startDate),
      'endDate': _dateKey(endDate),
      'currency': currency,
      'groupType': groupType,
      'appContext': appContext.toAiMap(),
    };

    if (!LocalApiKeys.hasOpenAiApiKey) {
      final callable = _functions.httpsCallable(
        'generateTransportRecommendations',
      );
      final response = await callable
          .call<Map<String, dynamic>>(input)
          .timeout(_transportRecommendationsTimeout);
      final data = response.data['result'] is Map
          ? Map<String, dynamic>.from(response.data['result'] as Map)
          : response.data;
      return TransportRecommendationResult.fromMap(data);
    }

    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _smartItineraryModel,
            'instructions': [
              'Find practical transportation options for a travel app booking workspace.',
              'Use web search data from multiple booking or travel information sources when available, such as airline sites, rail operators, bus operators, Traveloka, Klook, Skyscanner, Google Flights snippets, Rome2Rio-style route data, or local transit providers.',
              'Return options sorted from cheapest to most expensive.',
              'Use the requested currency when prices can be estimated; if a source gives another currency, convert approximately.',
              'If exact live booking prices are unavailable, use realistic current public fare ranges and clearly say approximate in bookingHint.',
              'Include only useful bookable route options for the origin and destination.',
              'Return no markdown and no explanation.',
            ].join(' '),
            'input': jsonEncode(input),
            'store': false,
            'tools': [
              {
                'type': 'web_search',
                'search_context_size': 'medium',
                'external_web_access': true,
              },
            ],
            'tool_choice': 'required',
            'reasoning': {'effort': 'low'},
            'text': {
              'verbosity': 'low',
              'format': _transportRecommendationsTextFormat(),
            },
          }),
        )
        .timeout(_transportRecommendationsTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI transport recommendations failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TransportRecommendationResult.fromMap(
      _decodeJsonObject(_responseOutputText(body)),
    );
  }

  Future<CreateTripAiResponse> createTripReply({
    required String message,
    required CreateTripDraft currentDraft,
    required List<CreateTripChatMessage> history,
    required String profileLanguage,
  }) async {
    final appContext = await _deviceContext.load(requestLocation: true);
    final outputLanguage = _aiLanguageName(profileLanguage);
    if (!LocalApiKeys.hasOpenAiApiKey) {
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

    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _fastChatModel,
            'instructions': [
              'You are the Create Trip assistant inside a mobile travel app.',
              'Actually interpret the user message and update the trip draft.',
              'Ask for exactly one missing important field at a time.',
              'When useful, create a tappable widget with 2 to 4 options.',
              'Widget option values must be short user messages the app can send back.',
              'When dates are missing and the user has given a destination or trip length, choose smart date range options instead of fixed offsets.',
              'For smart date range options, consider appContext location/timezone, likely origin country public holidays or long weekends, destination seasonality, distance/travel friction, weekends, and how soon booking is practical.',
              'Use web search when needed to check current public holidays, school breaks, destination events, weather seasons, or closures.',
              "When asking for dates, include 2 or 3 smart date range options with values as exact ISO ranges like '2026-07-02 to 2026-07-06', plus a 'Pick exact dates' option with value '$_customDateRangeValue'.",
              'Use appContext.localDate, appContext.localTime, and appContext.timeZoneOffset as the source of truth for today, tomorrow, next weekend, and relative dates.',
              'Use appContext.location as current-origin context for timing suggestions when available, especially for holidays in the user location country.',
              'Required final fields: destination, startDate, endDate, budget, groupType.',
              'Budget must be a plain number string in the selected currency, not a tier label such as mid-range or luxury.',
              'Preserve currentDraft.currency unless the latest user message explicitly names another currency.',
              "If the user gives an amount without a currency, interpret it in currentDraft.currency. Treat shorthand like '50K' as 50000.",
              'Dates must be ISO yyyy-MM-dd. groupType must be Solo, Friends, Family, or Tour.',
              'If the user names a currency, set currency to USD, TWD, IDR, JPY, or EUR.',
              'Write message, widget title, widget labels, widget descriptions, and preferences in $outputLanguage.',
              'Do not infer language from currency; currency only controls money.',
              'Return only JSON matching the schema.',
            ].join(' '),
            'input': jsonEncode({
              'latestMessage': message,
              'currentDraft': currentDraft.toAiMap(),
              'recentHistory': history.reversed
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
            }),
            'store': false,
            'reasoning': {'effort': 'low'},
            'text': {
              'verbosity': 'low',
              'format': {..._createTripReplyTextFormat()},
            },
          }),
        )
        .timeout(_createTripReplyTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI create trip chat failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = _decodeJsonObject(_responseOutputText(body));
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
    address: item.address,
    latitude: item.latitude,
    longitude: item.longitude,
    imageUrl: item.imageUrl,
  );
}

Map<String, dynamic> _scheduleItemToAiMap(ScheduleItem item) => {
  'day': item.day,
  'time': item.time,
  'activity': item.activity,
  'type': _iconName(item.type),
  'cost': item.cost,
  'address': item.address,
  'latitude': item.latitude,
  'longitude': item.longitude,
  'imageUrl': item.imageUrl,
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

class TransportRecommendationResult {
  const TransportRecommendationResult({
    required this.summary,
    required this.options,
  });

  final String summary;
  final List<TransportRecommendation> options;

  static TransportRecommendationResult fromMap(Map<String, dynamic> map) {
    final options =
        ((map['options'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => TransportRecommendation.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
          ..sort((a, b) => a.price.compareTo(b.price));
    return TransportRecommendationResult(
      summary: (map['summary'] as String?)?.trim() ?? '',
      options: options,
    );
  }
}

class TransportRecommendation {
  const TransportRecommendation({
    required this.mode,
    required this.provider,
    required this.route,
    required this.duration,
    required this.price,
    required this.currency,
    required this.bookingHint,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String mode;
  final String provider;
  final String route;
  final String duration;
  final int price;
  final String currency;
  final String bookingHint;
  final String sourceName;
  final String sourceUrl;

  static TransportRecommendation fromMap(Map<String, dynamic> map) {
    return TransportRecommendation(
      mode: (map['mode'] as String?)?.trim() ?? 'Transport',
      provider: (map['provider'] as String?)?.trim() ?? 'Provider varies',
      route: (map['route'] as String?)?.trim() ?? '',
      duration: (map['duration'] as String?)?.trim() ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?)?.trim() ?? 'USD',
      bookingHint: (map['bookingHint'] as String?)?.trim() ?? '',
      sourceName: (map['sourceName'] as String?)?.trim() ?? '',
      sourceUrl: (map['sourceUrl'] as String?)?.trim() ?? '',
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

Map<String, dynamic> _tripPlanTextFormat() => {
  'type': 'json_schema',
  'name': 'generated_trip_plan',
  'strict': true,
  'schema': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'items': {
        'type': 'array',
        'minItems': 3,
        'maxItems': 60,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'day': {'type': 'integer'},
            'time': {'type': 'string'},
            'activity': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': [
                'place',
                'food',
                'restaurant',
                'walk',
                'museum',
                'beach',
                'shopping',
                'train',
                'flight',
                'hotel',
                'cafe',
                'hiking',
                'temple',
              ],
            },
            'cost': {'type': 'integer'},
          },
          'required': ['day', 'time', 'activity', 'type', 'cost'],
        },
      },
      'bookings': {
        'type': 'array',
        'maxItems': 4,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'title': {'type': 'string'},
            'date': {'type': 'string'},
            'time': {'type': 'string'},
            'reference': {'type': 'string'},
            'cost': {'type': 'integer'},
            'type': {
              'type': 'string',
              'enum': ['hotel', 'flight', 'train', 'place'],
            },
          },
          'required': ['title', 'date', 'time', 'reference', 'cost', 'type'],
        },
      },
      'checklist': {
        'type': 'array',
        'maxItems': 5,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'category': {'type': 'string'},
            'items': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 8,
              'items': {'type': 'string'},
            },
          },
          'required': ['category', 'items'],
        },
      },
    },
    'required': ['items', 'bookings', 'checklist'],
  },
};

Map<String, dynamic> _scheduleStopTextFormat() => {
  'type': 'json_schema',
  'name': 'generated_schedule_stop',
  'strict': true,
  'schema': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'day': {'type': 'integer'},
      'time': {'type': 'string'},
      'activity': {'type': 'string'},
      'type': {
        'type': 'string',
        'enum': [
          'place',
          'food',
          'restaurant',
          'walk',
          'museum',
          'beach',
          'shopping',
          'train',
          'flight',
          'hotel',
          'cafe',
          'hiking',
          'temple',
        ],
      },
      'cost': {'type': 'integer'},
    },
    'required': ['day', 'time', 'activity', 'type', 'cost'],
  },
};

Map<String, dynamic> _dayPlanEditTextFormat() => {
  'type': 'json_schema',
  'name': 'day_plan_edit',
  'strict': true,
  'schema': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'feasible': {'type': 'boolean'},
      'warning': {'type': 'string'},
      'items': {
        'type': 'array',
        'maxItems': 8,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'day': {'type': 'integer'},
            'time': {'type': 'string'},
            'activity': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': [
                'place',
                'food',
                'restaurant',
                'walk',
                'museum',
                'beach',
                'shopping',
                'train',
                'flight',
                'hotel',
                'cafe',
                'hiking',
                'temple',
              ],
            },
            'cost': {'type': 'integer'},
          },
          'required': ['day', 'time', 'activity', 'type', 'cost'],
        },
      },
    },
    'required': ['feasible', 'warning', 'items'],
  },
};

Map<String, dynamic> _transportRecommendationsTextFormat() => {
  'type': 'json_schema',
  'name': 'transport_recommendations',
  'strict': true,
  'schema': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'summary': {'type': 'string'},
      'options': {
        'type': 'array',
        'minItems': 1,
        'maxItems': 8,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'mode': {'type': 'string'},
            'provider': {'type': 'string'},
            'route': {'type': 'string'},
            'duration': {'type': 'string'},
            'price': {'type': 'integer'},
            'currency': {'type': 'string'},
            'bookingHint': {'type': 'string'},
            'sourceName': {'type': 'string'},
            'sourceUrl': {'type': 'string'},
          },
          'required': [
            'mode',
            'provider',
            'route',
            'duration',
            'price',
            'currency',
            'bookingHint',
            'sourceName',
            'sourceUrl',
          ],
        },
      },
    },
    'required': ['summary', 'options'],
  },
};

Map<String, dynamic> _createTripReplyTextFormat() => {
  'type': 'json_schema',
  'name': 'create_trip_reply',
  'strict': true,
  'schema': {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'message': {'type': 'string'},
      'draft': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'destination': {
            'type': ['string', 'null'],
          },
          'startDate': {
            'type': ['string', 'null'],
          },
          'endDate': {
            'type': ['string', 'null'],
          },
          'budget': {
            'type': ['string', 'null'],
          },
          'currency': {
            'type': ['string', 'null'],
          },
          'groupType': {
            'type': ['string', 'null'],
          },
          'preferences': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': [
          'destination',
          'startDate',
          'endDate',
          'budget',
          'currency',
          'groupType',
          'preferences',
        ],
      },
      'widget': {
        'type': ['object', 'null'],
        'additionalProperties': false,
        'properties': {
          'title': {'type': 'string'},
          'options': {
            'type': 'array',
            'minItems': 1,
            'maxItems': 4,
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'label': {'type': 'string'},
                'value': {'type': 'string'},
                'description': {'type': 'string'},
              },
              'required': ['label', 'value', 'description'],
            },
          },
        },
        'required': ['title', 'options'],
      },
    },
    'required': ['message', 'draft', 'widget'],
  },
};

class GeneratedTripPlan {
  const GeneratedTripPlan({
    required this.items,
    required this.bookings,
    required this.checklist,
  });

  final List<ScheduleItem> items;
  final List<Booking> bookings;
  final List<ChecklistCategory> checklist;

  Map<String, dynamic> toMap() => {
    'items': items.map((item) => item.toMap()).toList(),
    'bookings': bookings.map((booking) => booking.toMap()).toList(),
    'checklist': checklist.map((category) => category.toMap()).toList(),
  };

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
            address: data['address'] as String?,
            latitude: (data['latitude'] as num?)?.toDouble(),
            longitude: (data['longitude'] as num?)?.toDouble(),
            imageUrl: data['imageUrl'] as String?,
          );
        })
        .take(60)
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

String _responseOutputText(Map<String, dynamic> body) {
  final outputText = body['output_text'];
  if (outputText is String) return outputText;

  final output = (body['output'] as List<dynamic>?) ?? const [];
  return output
      .whereType<Map>()
      .expand((item) => (item['content'] as List<dynamic>?) ?? const [])
      .whereType<Map>()
      .map((content) => content['text'])
      .whereType<String>()
      .join('\n')
      .trim();
}

Map<String, dynamic> _decodeJsonObject(String text) {
  final trimmed = text.trim();
  final cleaned = trimmed
      .replaceFirst(RegExp(r'^```(?:json)?', multiLine: true), '')
      .replaceFirst(RegExp(r'```$', multiLine: true), '')
      .trim();
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('AI response did not contain JSON.');
  }
  final decoded =
      jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
  return decoded;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
