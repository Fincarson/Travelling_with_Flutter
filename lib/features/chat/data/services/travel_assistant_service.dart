part of travel_agent_app;

class TravelAssistantService {
  TravelAssistantService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';

    if (LocalApiKeys.hasOpenAiApiKey) {
      return _sendMessageDirectly(trimmed);
    }

    final callable = _functions.httpsCallable('chatWithAssistant');
    final response = await callable.call<Map<String, dynamic>>({
      'message': trimmed,
    });
    return (response.data['reply'] as String?)?.trim() ?? '';
  }

  Future<String> _sendMessageDirectly(String message) async {
    final response = await http.post(
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
            'and short.',
        'input': message,
        'store': false,
        'reasoning': {'effort': 'low'},
        'text': {'verbosity': 'low'},
      }),
    );

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
    String airline = '',
    String flightConfirmation = '',
  }) async {
    if (!LocalApiKeys.hasOpenAiApiKey) {
      final callable = _functions.httpsCallable('generateTripPlan');
      final response = await callable.call<Map<String, dynamic>>({
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
        'airline': airline,
        'flightConfirmation': flightConfirmation,
      });
      final data = response.data['plan'] is Map
          ? Map<String, dynamic>.from(response.data['plan'] as Map)
          : response.data;
      return GeneratedTripPlan.fromMap(data);
    }

    final response = await http.post(
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
          'Return no markdown and no explanation.',
        ].join(' '),
        'input': jsonEncode({
          'destination': place.name,
          'formattedAddress': place.formatted,
          'startDate': _dateKey(startDate),
          'endDate': _dateKey(endDate),
          'budgetUsd': budget,
          'currency': currency,
          'groupType': groupType,
          'preferences': preferences,
          'flight': {'airline': airline, 'confirmation': flightConfirmation},
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
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI schedule generation failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _responseOutputText(body);
    final data = _decodeJsonObject(text);
    return GeneratedTripPlan.fromMap(data);
  }

  Future<CreateTripAiResponse> createTripReply({
    required String message,
    required CreateTripDraft currentDraft,
    required List<CreateTripChatMessage> history,
  }) async {
    if (!LocalApiKeys.hasOpenAiApiKey) {
      final callable = _functions.httpsCallable('createTripReply');
      final response = await callable.call<Map<String, dynamic>>({
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
        'today': _dateKey(DateTime.now()),
      });
      final data = response.data['reply'] is Map
          ? Map<String, dynamic>.from(response.data['reply'] as Map)
          : response.data;
      return CreateTripAiResponse.fromMap(data, fallbackDraft: currentDraft);
    }

    final response = await http.post(
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
          'Required final fields: destination, startDate, endDate, budget, groupType.',
          'Dates must be ISO yyyy-MM-dd. groupType must be Solo, Friends, Family, or Tour.',
          'If the user names a currency, set currency to USD, TWD, IDR, JPY, or EUR.',
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
          'today': _dateKey(DateTime.now()),
        }),
        'store': false,
        'reasoning': {'effort': 'low'},
        'text': {
          'verbosity': 'low',
          'format': {..._createTripReplyTextFormat()},
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI create trip chat failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = _decodeJsonObject(_responseOutputText(body));
    return CreateTripAiResponse.fromMap(data, fallbackDraft: currentDraft);
  }
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
        'maxItems': 12,
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
        .take(12)
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
