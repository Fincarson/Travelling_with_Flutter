part of travel_agent_app;

const _customDateRangeValue = '__pick_dates__';

class CreateTripDraft {
  const CreateTripDraft({
    this.destination,
    this.startDate,
    this.endDate,
    this.budget,
    this.currency,
    this.groupType,
    this.preferences = const [],
  });

  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? budget;
  final String? currency;
  final String? groupType;
  final List<String> preferences;

  CreateTripDraft copyWith({
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? budget,
    String? currency,
    String? groupType,
    List<String>? preferences,
  }) {
    return CreateTripDraft(
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      groupType: groupType ?? this.groupType,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toAiMap() => {
    'destination': destination,
    'startDate': startDate == null ? null : _dateKey(startDate!),
    'endDate': endDate == null ? null : _dateKey(endDate!),
    'budget': budget,
    'currency': currency,
    'groupType': groupType,
    'preferences': preferences,
  };

  static CreateTripDraft fromAiMap(
    Map<String, dynamic> map, {
    required CreateTripDraft fallback,
  }) {
    return fallback.copyWith(
      destination: _nonEmptyString(map['destination']) ?? fallback.destination,
      startDate: _parseIsoDate(map['startDate']) ?? fallback.startDate,
      endDate: _parseIsoDate(map['endDate']) ?? fallback.endDate,
      budget: _nonEmptyString(map['budget']) ?? fallback.budget,
      currency: _normalCurrencyCode(map['currency']) ?? fallback.currency,
      groupType: _normalGroupType(map['groupType']) ?? fallback.groupType,
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => toAiMap();

  static CreateTripDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CreateTripDraft(
      destination: json['destination'] as String?,
      startDate: _parseIsoDate(json['startDate']),
      endDate: _parseIsoDate(json['endDate']),
      budget: json['budget'] as String?,
      currency: json['currency'] as String?,
      groupType: json['groupType'] as String?,
      preferences: ((json['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class CreateTripChatMessage {
  const CreateTripChatMessage({
    required this.fromUser,
    required this.text,
    this.widget,
  });

  final bool fromUser;
  final String text;
  final CreateTripChoiceWidget? widget;

  Map<String, dynamic> toJson() => {
        'fromUser': fromUser,
        'text': text,
        'widget': widget?.toJson(),
      };

  static CreateTripChatMessage fromJson(Map<String, dynamic> json) {
    return CreateTripChatMessage(
      fromUser: json['fromUser'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      widget: json['widget'] is Map
          ? CreateTripChoiceWidget.fromMap(json['widget'])
          : null,
    );
  }

  static List<CreateTripChatMessage> fromJsonList(List<dynamic> json) {
    return json
        .whereType<Map<String, dynamic>>()
        .map(CreateTripChatMessage.fromJson)
        .toList();
  }

  static List<Map<String, dynamic>> toJsonList(
    List<CreateTripChatMessage> messages,
  ) {
    return messages.map((m) => m.toJson()).toList();
  }
}

class CreateTripAiResponse {
  const CreateTripAiResponse({
    required this.message,
    required this.draft,
    this.widget,
  });

  final String message;
  final CreateTripDraft draft;
  final CreateTripChoiceWidget? widget;

  static CreateTripAiResponse fromMap(
    Map<String, dynamic> map, {
    required CreateTripDraft fallbackDraft,
  }) {
    final draftMap = map['draft'] is Map
        ? Map<String, dynamic>.from(map['draft'] as Map)
        : const <String, dynamic>{};
    return CreateTripAiResponse(
      message: (map['message'] as String?)?.trim().isNotEmpty == true
          ? (map['message'] as String).trim()
          : 'I updated the trip draft.',
      draft: CreateTripDraft.fromAiMap(draftMap, fallback: fallbackDraft),
      widget: CreateTripChoiceWidget.fromMap(map['widget']),
    );
  }
}

class CreateTripChoiceWidget {
  const CreateTripChoiceWidget({required this.title, required this.options});

  final String title;
  final List<CreateTripChoiceOption> options;

  Map<String, dynamic> toJson() => {
        'title': title,
        'options': options.map((o) => o.toJson()).toList(),
      };

  static CreateTripChoiceWidget? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final options = ((map['options'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) => CreateTripChoiceOption.fromMap(item))
        .whereType<CreateTripChoiceOption>()
        .take(4)
        .toList();
    if (options.isEmpty) return null;
    return CreateTripChoiceWidget(
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Choose an option',
      options: options,
    );
  }
}

class CreateTripChoiceOption {
  const CreateTripChoiceOption({
    required this.label,
    required this.value,
    required this.description,
  });

  final String label;
  final String value;
  final String description;

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'description': description,
      };

  static CreateTripChoiceOption? fromMap(Map<dynamic, dynamic> map) {
    final label = _nonEmptyString(map['label']);
    final value = _nonEmptyString(map['value']);
    if (label == null || value == null) return null;
    return CreateTripChoiceOption(
      label: label,
      value: value,
      description: _nonEmptyString(map['description']) ?? '',
    );
  }
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalCurrencyCode(Object? value) {
  final text = _nonEmptyString(value)?.toLowerCase();
  if (text == null) return null;
  if (text == 'idr' || text == 'rp' || text == 'rupiah') return 'IDR';
  if (text == 'twd' || text == 'ntd' || text == r'nt$' || text == 'nt') {
    return 'TWD';
  }
  if (text == 'usd' || text == 'dollar' || text == 'dollars') return 'USD';
  if (text == 'jpy' || text == 'yen') return 'JPY';
  if (text == 'eur' || text == 'euro' || text == 'euros') return 'EUR';
  return null;
}

String _formatAmountText(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return value;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

DateTime? _parseIsoDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

String? _normalGroupType(Object? value) {
  final text = _nonEmptyString(value)?.toLowerCase();
  if (text == null) return null;
  if (text.contains('solo')) return 'Solo';
  if (text.contains('family')) return 'Family';
  if (text.contains('tour')) return 'Tour';
  if (text.contains('friend')) return 'Friends';
  return null;
}
