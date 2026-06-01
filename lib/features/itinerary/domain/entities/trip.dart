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
    required this.groupType,
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
    this.title = '',
  });

  final String id;
  final String title;
  final String destination;
  final String startDate;
  final String endDate;
  final int budget;
  final int spent;
  final String groupType;
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

  Trip copyWith({
    TripStatus? status,
    int? spent,
    int? budget,
    String? destination,
    String? startDate,
    String? endDate,
    String? groupType,
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
  }) => Trip(
    id: id,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    budget: budget ?? this.budget,
    spent: spent ?? this.spent,
    groupType: groupType ?? this.groupType,
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
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim().isEmpty ? destination : title,
    'destination': destination,
    'placeId': placeId,
    'formattedAddress': formattedAddress,
    'latitude': latitude,
    'longitude': longitude,
    'startDate': startDate,
    'endDate': endDate,
    'budget': budget,
    'spent': spent,
    'groupType': groupType,
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
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      spent: (map['spent'] as num?)?.toInt() ?? 0,
      groupType: (map['groupType'] as String?) ?? 'Solo',
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
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      spent: (map['spent'] as num?)?.toInt() ?? 0,
      groupType: (map['groupType'] as String?) ?? 'Solo',
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
  });

  final String id;
  final String category;
  final int planned;
  final int actual;

  BudgetCategory copyWith({int? planned, int? actual}) => BudgetCategory(
    id: id,
    category: category,
    planned: planned ?? this.planned,
    actual: actual ?? this.actual,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'planned': planned,
    'actual': actual,
  };

  static BudgetCategory fromMap(Map<String, dynamic> map) => BudgetCategory(
    id: (map['id'] as String?) ?? 'category',
    category: (map['category'] as String?) ?? 'Category',
    planned: (map['planned'] as num?)?.toInt() ?? 0,
    actual: (map['actual'] as num?)?.toInt() ?? 0,
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
    case 'place':
      return Icons.place_rounded;
    default:
      return Icons.place_rounded;
  }
}
