part of travel_agent_app;

class AppDeviceContext {
  const AppDeviceContext({
    required this.now,
    required this.timeZoneName,
    required this.timeZoneOffset,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
  });

  final DateTime now;
  final String timeZoneName;
  final Duration timeZoneOffset;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;

  DateTime get today => DateTime(now.year, now.month, now.day);
  bool get hasLocation => latitude != null && longitude != null;

  String get timeZoneOffsetLabel {
    final minutes = timeZoneOffset.inMinutes;
    final sign = minutes >= 0 ? '+' : '-';
    final absolute = minutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final mins = (absolute % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$mins';
  }

  Map<String, dynamic> toAiMap() => {
    'localDate': _dateKey(today),
    'localTime': _timeKey(now),
    'timeZoneName': timeZoneName,
    'timeZoneOffset': timeZoneOffsetLabel,
    'location': latitude == null || longitude == null
        ? null
        : {
            'latitude': latitude,
            'longitude': longitude,
            'accuracyMeters': locationAccuracyMeters,
          },
  };
}

class TripStartLocation {
  const TripStartLocation({
    required this.label,
    this.latitude,
    this.longitude,
    this.isCurrentLocation = false,
  });

  final String label;
  final double? latitude;
  final double? longitude;
  final bool isCurrentLocation;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toAiMap() => {
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
    'isCurrentLocation': isCurrentLocation,
  };

  static TripStartLocation? fromContext(AppDeviceContext? context) {
    if (context == null || !context.hasLocation) return null;
    return TripStartLocation(
      label: 'Current location',
      latitude: context.latitude,
      longitude: context.longitude,
      isCurrentLocation: true,
    );
  }

  static TripStartLocation fromPlace(PlaceSuggestion place) =>
      TripStartLocation(
        label: place.name,
        latitude: place.latitude == 0 ? null : place.latitude,
        longitude: place.longitude == 0 ? null : place.longitude,
      );
}

enum AppLocationAccessStatus { granted, denied, deniedForever, serviceDisabled }

class AppDeviceContextService {
  static const _locationTimeout = Duration(seconds: 4);
  static const _explicitLocationTimeout = Duration(seconds: 12);
  static const _locationAccessKey = 'app.location.access.enabled.v1';

  Future<bool> isLocationAccessEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationAccessKey) ?? true;
  }

  Future<void> setLocationAccessEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationAccessKey, enabled);
  }

  Future<AppLocationAccessStatus> enableLocationAccess() async {
    await setLocationAccessEnabled(true);
    final status = await requestLocationPermission();
    if (status == AppLocationAccessStatus.granted) return status;
    await setLocationAccessEnabled(false);
    return status;
  }

  Future<AppLocationAccessStatus> requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return AppLocationAccessStatus.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return AppLocationAccessStatus.deniedForever;
      }
      if (permission == LocationPermission.denied) {
        return AppLocationAccessStatus.denied;
      }

      return AppLocationAccessStatus.granted;
    } catch (_) {
      return AppLocationAccessStatus.denied;
    }
  }

  Future<AppDeviceContext> load({bool requestLocation = false}) async {
    return _load(
      requestLocation: requestLocation,
      timeout: _locationTimeout,
      useLastKnownFallback: false,
    );
  }

  Future<AppDeviceContext> loadCurrentLocation() async {
    return _load(
      requestLocation: true,
      timeout: _explicitLocationTimeout,
      useLastKnownFallback: true,
    );
  }

  Future<AppDeviceContext> _load({
    required bool requestLocation,
    required Duration timeout,
    required bool useLastKnownFallback,
  }) async {
    final now = _travelAgentNow();
    final locationAccessEnabled = await isLocationAccessEnabled();
    final position = locationAccessEnabled
        ? await _tryCurrentPosition(
            requestPermission: requestLocation,
            timeout: timeout,
            useLastKnownFallback: useLastKnownFallback,
          )
        : null;

    return AppDeviceContext(
      now: now,
      timeZoneName: now.timeZoneName,
      timeZoneOffset: now.timeZoneOffset,
      latitude: position?.latitude,
      longitude: position?.longitude,
      locationAccuracyMeters: position?.accuracy,
    );
  }

  Future<Position?> _tryCurrentPosition({
    required bool requestPermission,
    required Duration timeout,
    required bool useLastKnownFallback,
  }) async {
    try {
      if (requestPermission) {
        final status = await requestLocationPermission();
        if (status != AppLocationAccessStatus.granted) return null;
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: timeout,
          ),
        );
      } catch (_) {
        if (!useLastKnownFallback) return null;
        return Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      if (!useLastKnownFallback) return null;
      try {
        return Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}

DateTime _travelAgentNow() {
  const override = String.fromEnvironment('TRAVEL_AGENT_NOW');
  if (override.isEmpty) return DateTime.now();
  return DateTime.tryParse(override)?.toLocal() ?? DateTime.now();
}

String _timeKey(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
