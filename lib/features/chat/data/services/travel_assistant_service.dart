part of travel_agent_app;

class TravelAssistantService {
  TravelAssistantService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _chatTimeout = Duration(seconds: 20);
  static const _createTripReplyTimeout = Duration(seconds: 18);
  static const _tripPlanTimeout = Duration(seconds: 55);
  static const _scheduleStopTimeout = Duration(seconds: 18);

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
            'model': 'gpt-5.5',
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
    TripStartLocation? startLocation,
    String airline = '',
    String flightConfirmation = '',
  }) async {
    final appContext = await _deviceContext.load(requestLocation: true);
    final tripStartLocation =
        startLocation ?? TripStartLocation.fromContext(appContext);
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
            'flightConfirmation': flightConfirmation,
            'startLocation': tripStartLocation?.toAiMap(),
            'appContext': appContext.toAiMap(),
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
            'model': 'gpt-5.5',
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
              'For trips of 3 or more days, include at least 2 useful schedule items per day and 3 on full sightseeing days.',
              'Day 1 must start with realistic transportation from the trip origin to the destination before destination activities.',
              'The final trip day must include realistic return transportation home after the destination activities.',
              'For a one-day trip, do not add hotel stays or hotel bookings unless the user explicitly asks for lodging.',
              'When moving to a different city or district, or when returning home, include pack-up/preparation wording before the transport.',
              'Choose transport by distance: local transit/taxi for nearby trips, train/bus/high-speed rail for regional trips, and flights only for genuinely long-distance trips.',
              'Never suggest a plane for short regional travel such as Hsinchu to Taipei.',
              'Use web search data for current attraction names, transportation options, ticket prices, and local food costs.',
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
                'confirmation': flightConfirmation,
              },
              'startLocation': tripStartLocation?.toAiMap(),
              'appContext': appContext.toAiMap(),
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
            'tools': [
              {
                'type': 'web_search',
                'search_context_size': 'low',
                'external_web_access': true,
              },
            ],
            'tool_choice': 'required',
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
            'model': 'gpt-5.5',
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
            'model': 'gpt-5.5',
            'instructions': [
              'You are the Create Trip assistant inside a mobile travel app.',
              'Actually interpret the user message and update the trip draft.',
              'Ask for exactly one missing important field at a time.',
              'When useful, create a tappable widget with 2 to 4 options.',
              'Widget option values must be short user messages the app can send back.',
              "When asking for dates, include a 'Pick exact dates' option with value '$_customDateRangeValue'.",
              'Use appContext.localDate, appContext.localTime, and appContext.timeZoneOffset as the source of truth for today, tomorrow, next weekend, and relative dates.',
              'Use appContext.location only when the user says near me, nearby, my location, or asks for location-aware help.',
              'Required final fields: destination, startDate, endDate, budget, groupType.',
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
  );
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
        'maxItems': 24,
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
            'minItems': 2,
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
