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
  });

  final String name;
  final String formatted;
  final double latitude;
  final double longitude;
  final String placeId;
  final String? country;
  final String? resultType;

  static PlaceSuggestion fromMap(Map<String, dynamic> map) {
    final resultType =
        map['resultType'] as String? ??
        map['result_type'] as String? ??
        map['type'] as String?;
    final country = map['country'] as String?;
    final locality =
        map['name'] as String? ??
        map['city'] as String? ??
        map['county'] as String? ??
        map['state'] as String? ??
        (resultType == 'country' ? country : null);
    final formatted =
        (map['formatted'] as String?) ?? locality ?? 'Unknown place';
    final name = _placeNameWithCountry(locality ?? formatted, country);
    return PlaceSuggestion(
      name: name,
      formatted: formatted,
      latitude:
          (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble() ??
          0,
      longitude:
          (map['longitude'] as num?)?.toDouble() ??
          (map['lon'] as num?)?.toDouble() ??
          0,
      placeId:
          (map['placeId'] as String?) ??
          (map['place_id'] as String?) ??
          formatted,
      country: country,
      resultType: resultType,
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
