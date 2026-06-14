part of travel_agent_app;

enum TripPreviewJobStatus { queued, running, ready, failed, unknown }

class TripPreviewJob {
  const TripPreviewJob({
    required this.id,
    required this.status,
    required this.place,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.currency,
    required this.groupType,
    required this.preferences,
    required this.startLocation,
    required this.images,
    this.plan,
    this.errorMessage,
    this.createdAt,
  });

  final String id;
  final TripPreviewJobStatus status;
  final PlaceSuggestion? place;
  final DateTime? startDate;
  final DateTime? endDate;
  final int budget;
  final String currency;
  final String groupType;
  final List<String> preferences;
  final TripStartLocation? startLocation;
  final List<String> images;
  final GeneratedTripPlan? plan;
  final String? errorMessage;
  final DateTime? createdAt;

  bool get isActive =>
      status == TripPreviewJobStatus.queued ||
      status == TripPreviewJobStatus.running;

  bool get isReady => status == TripPreviewJobStatus.ready && plan != null;

  static TripPreviewJob fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final request = data['request'] is Map
        ? Map<String, dynamic>.from(data['request'] as Map)
        : const <String, dynamic>{};
    final result = data['result'] is Map
        ? Map<String, dynamic>.from(data['result'] as Map)
        : const <String, dynamic>{};
    final planMap = result['plan'] is Map
        ? Map<String, dynamic>.from(result['plan'] as Map)
        : null;

    return TripPreviewJob(
      id: snapshot.id,
      status: _tripPreviewJobStatus(data['status']),
      place: _previewPlaceFromMap(request['place']),
      startDate: _parseTripDate(request['startDate'] as String? ?? ''),
      endDate: _parseTripDate(request['endDate'] as String? ?? ''),
      budget: (request['budget'] as num?)?.toInt() ?? 0,
      currency: (request['currency'] as String?) ?? 'USD',
      groupType: (request['groupType'] as String?) ?? 'Solo',
      preferences: _previewStringList(request['preferences']),
      startLocation: _previewStartLocationFromMap(request['startLocation']),
      images: _previewStringList(result['images']).isNotEmpty
          ? _previewStringList(result['images'])
          : _previewStringList(request['fallbackImages']),
      plan: planMap == null ? null : GeneratedTripPlan.fromMap(planMap),
      errorMessage: data['errorMessage'] as String?,
      createdAt: _previewTimestampDate(data['createdAt']),
    );
  }
}

class TripPreviewJobService {
  TripPreviewJobService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _jobsRef(String accountId) =>
      _firestore
          .collection('travel_users')
          .doc(accountId)
          .collection('tripPreviewJobs');

  Future<String> createJob({
    required String accountId,
    required PlaceSuggestion place,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required String groupType,
    required List<String> preferences,
    required String currency,
    required String profileLanguage,
    required AppDeviceContext appContext,
    required TripStartLocation? startLocation,
    required List<String> fallbackImages,
    String airline = '',
    String flightCode = '',
    String flightDepartureTime = '',
    String flightDeparturePlace = '',
    String flightLandingTime = '',
    String flightLandingPlace = '',
  }) async {
    final callable = _functions.httpsCallable('createTripPreviewJob');
    final response = await callable.call<Map<String, dynamic>>({
      'accountId': accountId,
      'place': _placeToPreviewMap(place),
      'startDate': _dateKey(startDate),
      'endDate': _dateKey(endDate),
      'budget': budget,
      'groupType': groupType,
      'preferences': preferences,
      'currency': currency,
      'profileLanguage': profileLanguage,
      'outputLanguage': _aiLanguageName(profileLanguage),
      'airline': airline,
      'flightCode': flightCode,
      'flightDepartureTime': flightDepartureTime,
      'flightDeparturePlace': flightDeparturePlace,
      'flightLandingTime': flightLandingTime,
      'flightLandingPlace': flightLandingPlace,
      'startLocation': startLocation?.toAiMap(),
      'appContext': appContext.toAiMap(),
      'fallbackImages': fallbackImages,
    });
    return (response.data['jobId'] as String?) ?? '';
  }

  Stream<TripPreviewJob?> watchLatestJob(String accountId) {
    return watchRecentJobs(accountId).map((jobs) {
      if (jobs.isEmpty) return null;
      final ready = jobs.where((job) => job.isReady).toList();
      if (ready.isNotEmpty) return ready.first;
      final active = jobs.where((job) => job.isActive).toList();
      if (active.isNotEmpty) return active.first;
      return jobs.first;
    });
  }

  Stream<List<TripPreviewJob>> watchRecentJobs(String accountId) {
    return _jobsRef(accountId)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(TripPreviewJob.fromDoc).toList();
        });
  }

  Future<void> deleteJob(String accountId, String jobId) {
    if (jobId.trim().isEmpty) return Future<void>.value();
    return _jobsRef(accountId).doc(jobId).delete();
  }
}

TripPreviewJobStatus _tripPreviewJobStatus(Object? value) {
  return TripPreviewJobStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => TripPreviewJobStatus.unknown,
  );
}

Map<String, dynamic> _placeToPreviewMap(PlaceSuggestion place) => {
  'name': place.name,
  'formatted': place.formatted,
  'latitude': place.latitude,
  'longitude': place.longitude,
  'placeId': place.placeId,
  'country': place.country,
};

PlaceSuggestion? _previewPlaceFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);
  final name = (map['name'] as String?)?.trim() ?? '';
  if (name.isEmpty) return null;
  return PlaceSuggestion(
    name: name,
    formatted: (map['formatted'] as String?) ?? name,
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    placeId: (map['placeId'] as String?) ?? name,
    country: map['country'] as String?,
  );
}

TripStartLocation? _previewStartLocationFromMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);
  final label = (map['label'] as String?)?.trim() ?? '';
  final address = (map['address'] as String?)?.trim();
  if (label.isEmpty && (address == null || address.isEmpty)) return null;
  return TripStartLocation(
    label: label.isEmpty ? address! : label,
    address: address == null || address.isEmpty ? null : address,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    isCurrentLocation: map['isCurrentLocation'] == true,
  );
}

List<String> _previewStringList(Object? value) =>
    ((value as List<dynamic>?) ?? const [])
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();

DateTime? _previewTimestampDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}
