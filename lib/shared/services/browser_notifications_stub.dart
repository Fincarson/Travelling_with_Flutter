bool get supportsBrowserNotifications => false;
Stream<String> get browserNotificationClicks => const Stream.empty();

Future<bool> requestBrowserNotificationPermission() async => false;

Future<void> scheduleBrowserNotification({
  required int id,
  required DateTime notifyAt,
  required String title,
  required String body,
  String? payload,
}) async {}

Future<void> cancelBrowserNotifications(Iterable<int> ids) async {}

Future<void> showBrowserNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
  String? tag,
}) async {}
