part of travel_agent_app;

class GeoapifyPlacesService {
  GeoapifyPlacesService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<PlaceSuggestion>> searchDestinations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final callable = _functions.httpsCallable('searchPlaces');
    final response = await callable.call<Map<String, dynamic>>({
      'query': trimmed,
    });
    final results = (response.data['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<PlaceSuggestion?> reverseLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final callable = _functions.httpsCallable('reversePlace');
      final response = await callable.call<Map<String, dynamic>>({
        'latitude': latitude,
        'longitude': longitude,
      });
      final result = response.data['result'];
      if (result is Map) {
        return PlaceSuggestion.fromMap(Map<String, dynamic>.from(result));
      }
    } catch (_) {}

    return _reverseLocationWithNominatim(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<PlaceSuggestion>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required List<String> categories,
    int radiusMeters = 1200,
    int limit = 8,
  }) async {
    if (categories.isEmpty) return const [];

    final callable = _functions.httpsCallable('searchNearbyPlaces');
    final response = await callable.call<Map<String, dynamic>>({
      'latitude': latitude,
      'longitude': longitude,
      'categories': categories,
      'radiusMeters': radiusMeters,
      'limit': limit,
    });
    final results = (response.data['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<PlaceSuggestion?> _reverseLocationWithNominatim({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
    });

    final response = await http.get(
      url,
      headers: const {
        'User-Agent': 'TravellingWithFlutter/1.0 reverse-geocoding',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final displayName = (body['display_name'] as String?)?.trim();
    if (displayName == null || displayName.isEmpty) return null;

    final address = body['address'] is Map
        ? Map<String, dynamic>.from(body['address'] as Map)
        : const <String, dynamic>{};
    final name = _nominatimAddressName(address, displayName);

    return PlaceSuggestion(
      name: name,
      formatted: displayName,
      latitude: double.tryParse((body['lat'] as String?) ?? '') ?? latitude,
      longitude: double.tryParse((body['lon'] as String?) ?? '') ?? longitude,
      placeId:
          'osm-${body['osm_type'] ?? 'place'}-${body['osm_id'] ?? displayName}',
      country: address['country'] as String?,
      countryCode: (address['country_code'] as String?)?.toUpperCase(),
      resultType: body['type'] as String?,
    );
  }

  List<PlaceSuggestion> _placeSuggestionsFromResults(List<dynamic> results) {
    return results
        .whereType<Map>()
        .map((item) => PlaceSuggestion.fromMap(Map<String, dynamic>.from(item)))
        .where((place) => place.latitude != 0 && place.longitude != 0)
        .toList();
  }
}

String _nominatimAddressName(Map<String, dynamic> address, String displayName) {
  for (final key in const [
    'amenity',
    'building',
    'house_number',
    'road',
    'neighbourhood',
    'suburb',
    'city',
    'town',
    'village',
  ]) {
    final value = (address[key] as String?)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return displayName.split(',').first.trim();
}
