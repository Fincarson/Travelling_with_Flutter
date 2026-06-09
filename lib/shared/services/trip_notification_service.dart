part of travel_agent_app;

class TripNotificationService {
  TripNotificationService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _scheduledIdsKey = 'travel_agent.scheduled_activity_ids';
  static const _channelId = 'trip_activity_reminders';
  static const _channelName = 'Trip reminders';
  static const _channelDescription =
      'Trip start reminders and activity reminders.';
  static const _maxScheduledActivities = 48;

  final FlutterLocalNotificationsPlugin _notifications;
  var _initialized = false;
  bool? _permissionsAllowed;

  Future<void> syncTripReminders({
    required Trip? activeTrip,
    required List<Trip> trips,
    required bool enabled,
  }) async {
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
    await _ensureInitialized();
    final ids = await _loadScheduledIds();
    for (final id in ids) {
      await _notifications.cancel(id: id);
    }
    await _saveScheduledIds(const []);
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
    );

    await _notifications.initialize(settings: initializationSettings);
    _initialized = true;
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
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: trip.id,
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
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: trip.id,
    );
  }

  int _notificationId(String tripId, int index) {
    var hash = 17;
    for (final codeUnit in tripId.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + codeUnit);
    }
    return 100000 + ((hash + index) % 900000);
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
