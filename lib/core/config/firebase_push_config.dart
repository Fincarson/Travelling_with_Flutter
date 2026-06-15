part of travel_agent_app;

class FirebasePushConfig {
  const FirebasePushConfig._();

  static const webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
}
