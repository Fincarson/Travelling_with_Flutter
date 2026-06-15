part of travel_agent_app;

const _customDateRangeValue = '__pick_dates__';

class CreateTripDraft {
  const CreateTripDraft({
    this.destination,
    this.startDate,
    this.endDate,
    this.budget,
    this.currency,
    this.numOfTravelers,
    this.preferences = const [],
  });

  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? budget;
  final String? currency;
  final int? numOfTravelers;
  final List<String> preferences;

  CreateTripDraft copyWith({
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? budget,
    String? currency,
    int? numOfTravelers,
    List<String>? preferences,
  }) {
    return CreateTripDraft(
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      numOfTravelers: numOfTravelers ?? this.numOfTravelers,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toAiMap() => {
    'destination': destination,
    'startDate': startDate == null ? null : _dateKey(startDate!),
    'endDate': endDate == null ? null : _dateKey(endDate!),
    'budget': budget,
    'currency': currency,
    'numOfTravelers': numOfTravelers,
    'preferences': preferences,
  };

  Map<String, dynamic> toMap() => toAiMap();

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
      numOfTravelers:
          _normalTravelerCount(map['numOfTravelers']) ??
          _legacyTravelerCountFromGroupType(map['groupType']) ??
          fallback.numOfTravelers,
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  static CreateTripDraft fromMap(Map<String, dynamic> map) {
    return CreateTripDraft.fromAiMap(map, fallback: const CreateTripDraft());
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

  Map<String, dynamic> toMap() => {
    'fromUser': fromUser,
    'text': text,
    'widget': widget?.toMap(),
  };

  static CreateTripChatMessage fromMap(Map<String, dynamic> map) {
    return CreateTripChatMessage(
      fromUser: map['fromUser'] == true,
      text: (map['text'] as String?) ?? '',
      widget: CreateTripChoiceWidget.fromMap(map['widget']),
    );
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

  Map<String, dynamic> toMap() => {
    'title': title,
    'options': options.map((option) => option.toMap()).toList(),
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

  Map<String, dynamic> toMap() => {
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
  if (RegExp(r'^[a-z]{3}$').hasMatch(text)) return text.toUpperCase();
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

int? _normalTravelerCount(Object? value) {
  if (value is num) return value.toInt().clamp(1, 99).toInt();
  final text = _nonEmptyString(value);
  if (text == null) return null;
  final match = RegExp(r'\d+').firstMatch(text);
  final count = int.tryParse(match?.group(0) ?? '');
  if (count == null) return null;
  return count.clamp(1, 99).toInt();
}

int? _legacyTravelerCountFromGroupType(Object? value) {
  final text = _nonEmptyString(value)?.toLowerCase();
  if (text == null) return null;
  if (text.contains('solo')) return 1;
  if (text.contains('family')) return 4;
  if (text.contains('tour')) return 12;
  if (text.contains('friend')) return 2;
  return null;
}
