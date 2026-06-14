part of travel_agent_app;

class FirebasePushConfig {
  const FirebasePushConfig._();

  static const _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue:
        'BEy_M5Q8dCBD6QJFT3h-aIOr_2xYfUkAiS7AAiZRk8ytYunRvWCGVVac9ViXy0T12GVY0gpsQdrtnoeekcbpcy8',
  );

  static String? _cachedWebVapidKey;

  static Future<String> loadWebVapidKey() async {
    if (!kIsWeb) return '';
    final definedKey = _webVapidKey.trim();
    if (definedKey.isNotEmpty) return definedKey;
    final cachedKey = _cachedWebVapidKey;
    if (cachedKey != null) return cachedKey;

    try {
      final uri = Uri.base.resolve(
        'firebase-push-config.json?v=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _cachedWebVapidKey = '';
        return '';
      }
      final decoded = jsonDecode(response.body);
      final key = decoded is Map
          ? decoded['webVapidKey']?.toString().trim() ?? ''
          : '';
      _cachedWebVapidKey = key;
      return key;
    } catch (_) {
      _cachedWebVapidKey = '';
      return '';
    }
  }
}
