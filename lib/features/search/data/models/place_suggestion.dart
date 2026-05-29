part of travel_agent_app;

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.formatted,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    this.country,
  });

  final String name;
  final String formatted;
  final double latitude;
  final double longitude;
  final String placeId;
  final String? country;

  static PlaceSuggestion fromMap(Map<String, dynamic> map) {
    final city =
        map['name'] as String? ??
        map['city'] as String? ??
        map['county'] as String? ??
        map['state'] as String? ??
        map['name'] as String?;
    final country = map['country'] as String?;
    final formatted = (map['formatted'] as String?) ?? city ?? 'Unknown place';
    final name = city == null
        ? formatted
        : country == null
        ? city
        : '$city, $country';
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
    );
  }
}
