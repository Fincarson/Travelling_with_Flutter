part of travel_agent_app;

enum MapTravelMode { driving, walking, bicycling, transit }

extension MapTravelModeUi on MapTravelMode {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    MapTravelMode.driving => 'Drive',
    MapTravelMode.walking => 'Walk',
    MapTravelMode.bicycling => 'Bike',
    MapTravelMode.transit => 'Transit',
  };

  IconData get icon => switch (this) {
    MapTravelMode.driving => Icons.directions_car_filled_rounded,
    MapTravelMode.walking => Icons.directions_walk_rounded,
    MapTravelMode.bicycling => Icons.directions_bike_rounded,
    MapTravelMode.transit => Icons.directions_transit_filled_rounded,
  };
}

class _TripMapService {
  _TripMapService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<_ResolvedSchedulePlace>> resolvePlaces({
    required Trip trip,
    required int day,
  }) async {
    final callable = _functions.httpsCallable('resolveItineraryMapStops');
    final indexedItems = trip.items.indexed
        .where((entry) => entry.$2.day == day)
        .map(
          (entry) => {
            'index': entry.$1,
            'activity': entry.$2.activity,
            'time': entry.$2.time,
            'placeId': entry.$2.placeId,
            'formattedAddress': entry.$2.formattedAddress,
            'latitude': entry.$2.latitude,
            'longitude': entry.$2.longitude,
          },
        )
        .toList(growable: false);
    if (indexedItems.isEmpty) return const [];

    final result = await callable.call<Map<String, dynamic>>({
      'tripId': trip.id,
      'destination': trip.destination,
      'items': indexedItems,
    });
    final data = Map<String, dynamic>.from(result.data);
    return ((data['stops'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map(
          (stop) =>
              _ResolvedSchedulePlace.fromMap(Map<String, dynamic>.from(stop)),
        )
        .toList(growable: false);
  }

  Future<_TripMapRoute?> computeRoute({
    required String tripId,
    required List<_TripMapStop> stops,
    required MapTravelMode mode,
  }) async {
    if (stops.length < 2) return null;
    final callable = _functions.httpsCallable('computeItineraryRoute');
    final result = await callable.call<Map<String, dynamic>>({
      'tripId': tripId,
      'mode': mode.apiValue,
      'stops': stops
          .map(
            (stop) => {
              'latitude': stop.item.latitude,
              'longitude': stop.item.longitude,
            },
          )
          .toList(growable: false),
    });
    final data = Map<String, dynamic>.from(result.data);
    final encodedPolylines =
        ((data['encodedPolylines'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
    if (encodedPolylines.isEmpty) return null;
    return _TripMapRoute(
      points: [
        for (final encodedPolyline in encodedPolylines)
          ..._decodeGooglePolyline(encodedPolyline),
      ],
      distanceMeters: (data['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class _ResolvedSchedulePlace {
  const _ResolvedSchedulePlace({
    required this.index,
    required this.placeId,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final int index;
  final String placeId;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  static _ResolvedSchedulePlace fromMap(Map<String, dynamic> map) =>
      _ResolvedSchedulePlace(
        index: (map['index'] as num?)?.toInt() ?? -1,
        placeId: (map['placeId'] as String?) ?? '',
        formattedAddress: (map['formattedAddress'] as String?) ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      );
}

class _TripMapStop {
  const _TripMapStop({required this.index, required this.item});

  final int index;
  final ScheduleItem item;

  bool get hasMapLocation => item.hasMapLocation;
  LatLng get point => LatLng(item.latitude!, item.longitude!);
  google_maps.LatLng get googlePoint =>
      google_maps.LatLng(item.latitude!, item.longitude!);
}

class _TripMapRoute {
  const _TripMapRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  String get distanceLabel {
    if (distanceMeters < 1000) return '$distanceMeters m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
  }
}

List<LatLng> _decodeGooglePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    latitude += (result & 1) == 1 ? ~(result >> 1) : result >> 1;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    longitude += (result & 1) == 1 ? ~(result >> 1) : result >> 1;
    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }

  return points;
}
