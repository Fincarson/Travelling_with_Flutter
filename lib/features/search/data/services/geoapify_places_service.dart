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

  Future<List<PlaceSuggestion>> _searchDestinationsDirectly(
    String query,
  ) async {
    final url = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'type': 'city',
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
}
