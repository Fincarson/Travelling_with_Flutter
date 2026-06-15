part of travel_agent_app;

class GeoapifyPlacesService {
  GeoapifyPlacesService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<PlaceSuggestion>> searchDestinations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    if (LocalApiKeys.hasGeoapifyApiKey) {
      return _searchDestinationsDirectly(trimmed);
    }

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
    if (LocalApiKeys.hasGeoapifyApiKey) {
      try {
        final place = await _reverseLocationDirectly(
          latitude: latitude,
          longitude: longitude,
        );
        if (place != null) return place;
      } catch (_) {}
      return _reverseLocationWithNominatim(
        latitude: latitude,
        longitude: longitude,
      );
    }

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

    if (LocalApiKeys.hasGeoapifyApiKey) {
      return _searchNearbyPlacesDirectly(
        latitude: latitude,
        longitude: longitude,
        categories: categories,
        radiusMeters: radiusMeters,
        limit: limit,
      );
    }

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

  Future<PlaceSuggestion?> searchItineraryStop({
    required String query,
    required String destination,
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return null;

    try {
      final places = LocalApiKeys.hasGeoapifyApiKey
          ? await _searchItineraryStopDirectly(
              query: trimmed,
              destination: destination,
              latitude: latitude,
              longitude: longitude,
            )
          : await _searchItineraryStopWithFunction(
              query: trimmed,
              destination: destination,
              latitude: latitude,
              longitude: longitude,
            );
      if (places.isNotEmpty) return places.first;
    } catch (_) {}

    return _searchItineraryStopWithNominatim(
      query: trimmed,
      destination: destination,
    );
  }

  Future<List<PlaceSuggestion>> _searchDestinationsDirectly(
    String query,
  ) async {
    final results = await Future.wait([
      _fetchDestinationsByType(query, 'country'),
      _fetchDestinationsByType(query, 'city'),
    ]);

    return _rankPlaceSuggestions([
      ...results[0],
      ...results[1],
    ], query).take(6).toList();
  }

  Future<PlaceSuggestion?> _reverseLocationDirectly({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'apiKey': LocalApiKeys.geoapifyApiKey,
    });

    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Current location lookup is unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>?) ?? const [];
    final places = _placeSuggestionsFromResults(results);
    return places.isEmpty ? null : places.first;
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

  Future<List<PlaceSuggestion>> _fetchDestinationsByType(
    String query,
    String type,
  ) async {
    final url = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'type': type,
      'limit': '6',
      'apiKey': LocalApiKeys.geoapifyApiKey,
    });

    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Place search is unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<List<PlaceSuggestion>> _searchNearbyPlacesDirectly({
    required double latitude,
    required double longitude,
    required List<String> categories,
    required int radiusMeters,
    required int limit,
  }) async {
    final lon = longitude.toString();
    final lat = latitude.toString();
    final url = Uri.https('api.geoapify.com', '/v2/places', {
      'categories': categories.join(','),
      'filter': 'circle:$lon,$lat,$radiusMeters',
      'bias': 'proximity:$lon,$lat',
      'limit': limit.clamp(1, 20).toString(),
      'apiKey': LocalApiKeys.geoapifyApiKey,
    });

    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Nearby places are unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(features);
  }

  Future<List<PlaceSuggestion>> _searchItineraryStopWithFunction({
    required String query,
    required String destination,
    double? latitude,
    double? longitude,
  }) async {
    final callable = _functions.httpsCallable('searchItineraryStop');
    final response = await callable.call<Map<String, dynamic>>({
      'query': query,
      'destination': destination,
      'latitude': latitude,
      'longitude': longitude,
    });
    final results = (response.data['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<List<PlaceSuggestion>> _searchItineraryStopDirectly({
    required String query,
    required String destination,
    double? latitude,
    double? longitude,
  }) async {
    final params = {
      'text': destination.trim().isEmpty ? query : '$query, $destination',
      'format': 'json',
      'limit': '4',
      'apiKey': LocalApiKeys.geoapifyApiKey,
      if (latitude != null && longitude != null)
        'bias': 'proximity:$longitude,$latitude',
    };
    final url = Uri.https('api.geoapify.com', '/v1/geocode/search', params);
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Stop lookup is unavailable.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<PlaceSuggestion?> _searchItineraryStopWithNominatim({
    required String query,
    required String destination,
  }) async {
    final text = destination.trim().isEmpty ? query : '$query, $destination';
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': text,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '1',
    });
    final response = await http.get(
      url,
      headers: const {
        'User-Agent': 'TravellingWithFlutter/1.0 itinerary-map',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final results = jsonDecode(response.body);
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    final item = Map<String, dynamic>.from(results.first as Map);
    final displayName = (item['display_name'] as String?)?.trim();
    if (displayName == null || displayName.isEmpty) return null;
    return PlaceSuggestion(
      name: displayName.split(',').first.trim(),
      formatted: displayName,
      latitude: double.tryParse((item['lat'] as String?) ?? '') ?? 0,
      longitude: double.tryParse((item['lon'] as String?) ?? '') ?? 0,
      placeId: 'osm-${item['osm_type'] ?? 'place'}-${item['osm_id'] ?? text}',
      resultType: item['type'] as String?,
    );
  }

  List<PlaceSuggestion> _placeSuggestionsFromResults(List<dynamic> results) {
    return results
        .whereType<Map>()
        .map((item) => PlaceSuggestion.fromMap(Map<String, dynamic>.from(item)))
        .where((place) => place.latitude != 0 && place.longitude != 0)
        .toList();
  }

  List<PlaceSuggestion> _rankPlaceSuggestions(
    List<PlaceSuggestion> suggestions,
    String query,
  ) {
    final seen = <String>{};
    final unique = suggestions.where((place) {
      final key = place.placeId.trim().isEmpty
          ? place.formatted
          : place.placeId;
      return seen.add(key);
    }).toList();
    final normalizedQuery = _normalizedPlaceName(query);

    unique.sort((a, b) {
      final scoreA = _placeRankScore(a, normalizedQuery);
      final scoreB = _placeRankScore(b, normalizedQuery);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      return a.name.length.compareTo(b.name.length);
    });

    return unique;
  }

  int _placeRankScore(PlaceSuggestion place, String normalizedQuery) {
    final name = _normalizedPlaceName(place.name);
    final country = _normalizedPlaceName(place.country ?? '');
    final formatted = _normalizedPlaceName(place.formatted);
    final isCountry =
        place.resultType == 'country' ||
        (country.isNotEmpty && name == country);

    if (isCountry && (name == normalizedQuery || country == normalizedQuery)) {
      return 0;
    }
    if (name == normalizedQuery) return 1;
    if (formatted == normalizedQuery) return 2;
    if (isCountry) return 3;
    return 4;
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
