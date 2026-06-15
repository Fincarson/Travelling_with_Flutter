part of travel_agent_app;

class TripNotificationService {
  TripNotificationService({
    FlutterLocalNotificationsPlugin? notifications,
    Future<void> Function()? initializeNotifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _initializeNotifications = initializeNotifications;

  static const _scheduledIdsKey = 'travel_agent.scheduled_activity_ids';
  static const _channelId = 'trip_activity_reminders';
  static const _channelName = 'Trip reminders';
  static const _channelDescription =
      'Trip start reminders and activity reminders.';
  static const _maxScheduledActivities = 48;

  final FlutterLocalNotificationsPlugin _notifications;
  final Future<void> Function()? _initializeNotifications;
  var _initialized = false;
  bool? _permissionsAllowed;

  Future<void> syncTripReminders({
    required Trip? activeTrip,
    required List<Trip> trips,
    required bool enabled,
  }) async {
    if (kIsWeb) {
      await _syncBrowserTripReminders(
        activeTrip: activeTrip,
        trips: trips,
        enabled: enabled,
      );
      return;
    }
    if (!_supportsNativeNotifications) return;

    await _ensureInitialized();

    if (!enabled) {
      await cancelTripReminders();
      return;
    }

    final allowed = await _ensurePermissions();
    if (!allowed) {
      await cancelTripReminders();
      return;
    }

    await cancelTripReminders();

    final scheduledIds = <int>[];
    final now = _travelAgentNow();

    for (final trip in trips) {
      if (trip.status != TripStatus.upcoming) continue;
      final startDate = _parseTripDate(trip.startDate);
      if (startDate == null) continue;

      final dayBefore = startDate
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 9));
      if (dayBefore.isAfter(now)) {
        final id = _notificationId(trip.id, 9001);
        await _scheduleTripStartReminder(
          id: id,
          trip: trip,
          notifyAt: dayBefore,
          title: '${trip.destination} starts tomorrow',
          body: 'Open your itinerary and start the trip when you are ready.',
        );
        scheduledIds.add(id);
      }

      final departureDay = startDate.add(const Duration(hours: 8));
      if (departureDay.isAfter(now)) {
        final id = _notificationId(trip.id, 9002);
        await _scheduleTripStartReminder(
          id: id,
          trip: trip,
          notifyAt: departureDay,
          title: '${trip.destination} starts today',
          body: 'Your trip is waiting. Tap Start trip to activate the agent.',
        );
        scheduledIds.add(id);
      }
    }

    if (activeTrip != null && activeTrip.status == TripStatus.ongoing) {
      for (var index = 0; index < activeTrip.items.length; index++) {
        if (scheduledIds.length >= _maxScheduledActivities) break;

        final item = activeTrip.items[index];
        final startAt = _scheduleItemStartAt(activeTrip, item);
        if (startAt == null) continue;

        final notifyAt = startAt.subtract(const Duration(hours: 1));
        if (!notifyAt.isAfter(now)) continue;

        final id = _notificationId(activeTrip.id, index);
        await _scheduleActivityReminder(
          id: id,
          trip: activeTrip,
          item: item,
          notifyAt: notifyAt,
        );
        scheduledIds.add(id);
      }
    }

    await _saveScheduledIds(scheduledIds);
  }

  Future<void> cancelTripReminders() async {
    if (kIsWeb) {
      final ids = await _loadScheduledIds();
      await browser_notifications.cancelBrowserNotifications(ids);
      await _saveScheduledIds(const []);
      return;
    }
    if (!_supportsNativeNotifications) {
      await _saveScheduledIds(const []);
      return;
    }

    await _ensureInitialized();
    final ids = await _loadScheduledIds();
    for (final id in ids) {
      await _notifications.cancel(id: id);
    }
    await _saveScheduledIds(const []);
  }

  Future<void> _syncBrowserTripReminders({
    required Trip? activeTrip,
    required List<Trip> trips,
    required bool enabled,
  }) async {
    if (!enabled) {
      await cancelTripReminders();
      return;
    }

    final allowed = await browser_notifications
        .requestBrowserNotificationPermission();
    if (!allowed) {
      await cancelTripReminders();
      return;
    }

    await cancelTripReminders();

    final scheduledIds = <int>[];
    final now = _travelAgentNow();

    for (final trip in trips) {
      if (trip.status != TripStatus.upcoming) continue;
      final startDate = _parseTripDate(trip.startDate);
      if (startDate == null) continue;

      final dayBefore = startDate
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 9));
      if (dayBefore.isAfter(now)) {
        final id = _notificationId(trip.id, 9001);
        await _scheduleBrowserReminder(
          id: id,
          notifyAt: dayBefore,
          title: '${trip.destination} starts tomorrow',
          body: 'Open your itinerary and start the trip when you are ready.',
          payload: _tripNotificationPayload(
            type: 'trip_start',
            tripId: trip.id,
          ),
        );
        scheduledIds.add(id);
      }

      final departureDay = startDate.add(const Duration(hours: 8));
      if (departureDay.isAfter(now)) {
        final id = _notificationId(trip.id, 9002);
        await _scheduleBrowserReminder(
          id: id,
          notifyAt: departureDay,
          title: '${trip.destination} starts today',
          body: 'Your trip is waiting. Tap Start trip to activate the agent.',
          payload: _tripNotificationPayload(
            type: 'trip_start',
            tripId: trip.id,
          ),
        );
        scheduledIds.add(id);
      }
    }

    if (activeTrip != null && activeTrip.status == TripStatus.ongoing) {
      for (var index = 0; index < activeTrip.items.length; index++) {
        if (scheduledIds.length >= _maxScheduledActivities) break;

        final item = activeTrip.items[index];
        final startAt = _scheduleItemStartAt(activeTrip, item);
        if (startAt == null) continue;

        final notifyAt = startAt.subtract(const Duration(hours: 1));
        if (!notifyAt.isAfter(now)) continue;

        final id = _notificationId(activeTrip.id, index);
        await _scheduleBrowserReminder(
          id: id,
          notifyAt: notifyAt,
          title: '${activeTrip.destination} in 1 hour',
          body: '${item.time} - ${item.activity}',
          payload: _tripNotificationPayload(
            type: 'trip_activity',
            tripId: activeTrip.id,
          ),
        );
        scheduledIds.add(id);
      }
    }

    await _saveScheduledIds(scheduledIds);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    final initializeNotifications = _initializeNotifications;
    if (initializeNotifications != null) {
      await initializeNotifications();
    } else {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Travel Agent',
          appUserModelId: 'IndieeGo.TravelAgent',
          guid: '8e3b65d5-8b6d-4da2-8c6f-68a5e4e8d4c2',
        ),
      );
      await _notifications.initialize(settings: initializationSettings);
    }
    _initialized = true;
  }

  bool get _supportsNativeNotifications {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<bool> _ensurePermissions() async {
    final previousDecision = _permissionsAllowed;
    if (previousDecision != null) return previousDecision;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidAllowed =
        await android?.requestNotificationsPermission() ?? true;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosAllowed =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosAllowed =
        await macos?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    _permissionsAllowed = androidAllowed && iosAllowed && macosAllowed;
    return _permissionsAllowed!;
  }

  Future<void> _scheduleActivityReminder({
    required int id,
    required Trip trip,
    required ScheduleItem item,
    required DateTime notifyAt,
  }) async {
    final scheduledAt = tz.TZDateTime.from(notifyAt, tz.local);
    final title = '${trip.destination} in 1 hour';
    final body = '${item.time} - ${item.activity}';

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _tripNotificationPayload(type: 'trip_activity', tripId: trip.id),
    );
  }

  Future<void> _scheduleTripStartReminder({
    required int id,
    required Trip trip,
    required DateTime notifyAt,
    required String title,
    required String body,
  }) async {
    final scheduledAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _tripNotificationPayload(type: 'trip_start', tripId: trip.id),
    );
  }

  Future<void> _scheduleBrowserReminder({
    required int id,
    required DateTime notifyAt,
    required String title,
    required String body,
    required String payload,
  }) {
    return browser_notifications.scheduleBrowserNotification(
      id: id,
      notifyAt: notifyAt,
      title: title,
      body: body,
      payload: payload,
    );
  }

  int _notificationId(String tripId, int index) {
    var hash = 17;
    for (final codeUnit in tripId.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + codeUnit);
    }
    return 100000 + ((hash + index) % 900000);
  }

  String _tripNotificationPayload({
    required String type,
    required String tripId,
  }) {
    return jsonEncode({
      'type': type,
      'tripId': tripId,
      'targetPath': '/trips/${Uri.encodeComponent(tripId)}',
    });
  }

  Future<List<int>> _loadScheduledIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(_scheduledIdsKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .toList() ??
        const [];
  }

  Future<void> _saveScheduledIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledIdsKey,
      ids.map((id) => id.toString()).toList(),
    );
  }
}
