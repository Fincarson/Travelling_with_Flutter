part of travel_agent_app;

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.formatted,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    this.country,
    this.resultType,
    this.distanceMeters,
    this.categories = const [],
  });

  final String name;
  final String formatted;
  final double latitude;
  final double longitude;
  final String placeId;
  final String? country;
  final String? resultType;
  final int? distanceMeters;
  final List<String> categories;

  Map<String, dynamic> toMap() => {
    'name': name,
    'formatted': formatted,
    'latitude': latitude,
    'longitude': longitude,
    'placeId': placeId,
    'country': country,
    'resultType': resultType,
    'distance': distanceMeters,
    'categories': categories,
  };

  static PlaceSuggestion fromMap(Map<String, dynamic> map) {
    final properties = map['properties'] is Map
        ? Map<String, dynamic>.from(map['properties'] as Map)
        : map;
    final geometry = map['geometry'] is Map
        ? Map<String, dynamic>.from(map['geometry'] as Map)
        : const <String, dynamic>{};
    final coordinates = (geometry['coordinates'] as List<dynamic>?) ?? const [];
    final resultType =
        properties['resultType'] as String? ??
        properties['result_type'] as String? ??
        properties['type'] as String?;
    final country = properties['country'] as String?;
    final locality =
        properties['name'] as String? ??
        properties['city'] as String? ??
        properties['county'] as String? ??
        properties['state'] as String? ??
        (resultType == 'country' ? country : null);
    final formatted =
        (properties['formatted'] as String?) ?? locality ?? 'Unknown place';
    final name = _placeNameWithCountry(locality ?? formatted, country);
    return PlaceSuggestion(
      name: name,
      formatted: formatted,
      latitude:
          (properties['latitude'] as num?)?.toDouble() ??
          (properties['lat'] as num?)?.toDouble() ??
          (coordinates.length > 1
              ? (coordinates[1] as num?)?.toDouble()
              : null) ??
          0,
      longitude:
          (properties['longitude'] as num?)?.toDouble() ??
          (properties['lon'] as num?)?.toDouble() ??
          (coordinates.isNotEmpty
              ? (coordinates[0] as num?)?.toDouble()
              : null) ??
          0,
      placeId:
          (properties['placeId'] as String?) ??
          (properties['place_id'] as String?) ??
          formatted,
      country: country,
      resultType: resultType,
      distanceMeters: (properties['distance'] as num?)?.round(),
      categories: ((properties['categories'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

String _placeNameWithCountry(String value, String? country) {
  final name = value.trim();
  final countryName = country?.trim();
  if (countryName == null || countryName.isEmpty) return name;

  final parts = name
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  final lastPart = parts.isEmpty ? name : parts.last;
  if (_normalizedPlaceName(name) == _normalizedPlaceName(countryName) ||
      _normalizedPlaceName(lastPart) == _normalizedPlaceName(countryName)) {
    return name;
  }
  return '$name, $countryName';
}

String _normalizedPlaceName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
