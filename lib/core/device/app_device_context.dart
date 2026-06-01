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

class AppDeviceContextService {
  Future<AppDeviceContext> load({bool requestLocation = false}) async {
    final now = DateTime.now();
    Position? position;

    if (requestLocation) {
      position = await _tryCurrentPosition();
    }

    return AppDeviceContext(
      now: now,
      timeZoneName: now.timeZoneName,
      timeZoneOffset: now.timeZoneOffset,
      latitude: position?.latitude,
      longitude: position?.longitude,
      locationAccuracyMeters: position?.accuracy,
    );
  }

  Future<Position?> _tryCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (_) {
      return null;
    }
  }
}

String _timeKey(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
