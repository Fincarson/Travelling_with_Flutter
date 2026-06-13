// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

final _timers = <int, Timer>{};
final _visibleNotifications = <int, html.Notification>{};

bool get supportsBrowserNotifications => html.Notification.supported;

Future<bool> requestBrowserNotificationPermission() async {
  if (!supportsBrowserNotifications) return false;
  final current = html.Notification.permission;
  if (current == 'granted') return true;
  if (current == 'denied') return false;

  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

Future<void> scheduleBrowserNotification({
  required int id,
  required DateTime notifyAt,
  required String title,
  required String body,
  String? payload,
}) async {
  if (!supportsBrowserNotifications ||
      html.Notification.permission != 'granted') {
    return;
  }

  await cancelBrowserNotifications([id]);

  final delay = notifyAt.difference(DateTime.now());
  if (delay.isNegative || delay == Duration.zero) {
    _showBrowserNotification(id: id, title: title, body: body);
    return;
  }

  _timers[id] = Timer(delay, () {
    _timers.remove(id);
    _showBrowserNotification(id: id, title: title, body: body);
  });
}

Future<void> cancelBrowserNotifications(Iterable<int> ids) async {
  for (final id in ids) {
    _timers.remove(id)?.cancel();
    _visibleNotifications.remove(id)?.close();
  }
}

void _showBrowserNotification({
  required int id,
  required String title,
  required String body,
}) {
  final notification = html.Notification(
    title,
    body: body,
    icon: 'icons/Icon-192.png',
    tag: 'trip-reminder-$id',
  );
  _visibleNotifications[id] = notification;
  notification.onClose.first.then((_) => _visibleNotifications.remove(id));
}
