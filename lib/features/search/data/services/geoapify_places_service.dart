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
      return _reverseLocationDirectly(latitude: latitude, longitude: longitude);
    }

    final callable = _functions.httpsCallable('reversePlace');
    final response = await callable.call<Map<String, dynamic>>({
      'latitude': latitude,
      'longitude': longitude,
    });
    final result = response.data['result'];
    if (result is! Map) return null;
    return PlaceSuggestion.fromMap(Map<String, dynamic>.from(result));
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
