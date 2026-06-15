bool get supportsBrowserNotifications => false;

Future<bool> requestBrowserNotificationPermission() async => false;

Future<void> scheduleBrowserNotification({
  required int id,
  required DateTime notifyAt,
  required String title,
  required String body,
  String? payload,
}) async {}

Future<void> cancelBrowserNotifications(Iterable<int> ids) async {}
