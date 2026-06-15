part of travel_agent_app;

class AppNotificationService {
  static const _channelId = 'travel_agent_updates';
  static const _channelName = 'Travel Agent updates';
  static const _channelDescription =
      'Chat messages, group activity, trip reminders, and AI travel updates.';

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _browserClickSubscription;
  bool Function()? _notificationsEnabled;
  String? Function()? _activeChatId;
  Future<void> Function(String targetPath)? _onOpen;
  var _localInitialized = false;
  var _listenersInitialized = false;

  Future<void> initialize({
    required bool Function() notificationsEnabled,
    required String? Function() activeChatId,
    required Future<void> Function(String targetPath) onOpen,
  }) async {
    _notificationsEnabled = notificationsEnabled;
    _activeChatId = activeChatId;
    _onOpen = onOpen;
    await ensureLocalInitialized();
    if (_listenersInitialized) return;
    _listenersInitialized = true;

    _browserClickSubscription = browser_notifications.browserNotificationClicks
        .listen((payload) => unawaited(_openPayload(payload)));

    if (!_supportsFirebaseMessaging) return;
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_handleForegroundMessage(message)),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openRemoteMessage(message)),
    );
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _openRemoteMessage(initialMessage);
    }
  }

  Future<void> ensureLocalInitialized() async {
    if (_localInitialized || kIsWeb) {
      _localInitialized = true;
      return;
    }
    const settings = InitializationSettings(
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
    await notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_openPayload(response.payload));
      },
    );
    _localInitialized = true;

    final launchDetails = await notifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      await _openPayload(response.payload);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (_notificationsEnabled?.call() != true) return;
    final data = message.data;
    if (_isCurrentChatNotification(data)) return;

    final title =
        message.notification?.title ?? data['title'] ?? 'Travel Agent';
    final body =
        message.notification?.body ?? data['body'] ?? 'You have an update.';
    final payload = jsonEncode(data);
    if (kIsWeb) {
      await browser_notifications.showBrowserNotification(
        id: _notificationId(message.messageId ?? payload),
        title: title,
        body: body,
        payload: payload,
        tag: data['tag'],
      );
      return;
    }

    await ensureLocalInitialized();
    await notifications.show(
      id: _notificationId(message.messageId ?? payload),
      title: title,
      body: body,
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
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      payload: payload,
    );
  }

  bool _isCurrentChatNotification(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type != 'group_chat' &&
        type != 'group_member_joined' &&
        type != 'group_member_left' &&
        type != 'group_member_removed') {
      return false;
    }
    final chatId = data['chatId']?.toString();
    return chatId != null &&
        chatId.isNotEmpty &&
        chatId == _activeChatId?.call();

  }

  Future<void> _openRemoteMessage(RemoteMessage message) {
    return _openData(message.data);
  }

  Future<void> _openPayload(String? payload) async {
    final text = payload?.trim() ?? '';
    if (text.isEmpty) return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        await _openData(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {}

    if (text.startsWith('/')) {
      await _onOpen?.call(text);
      return;
    }
    await _onOpen?.call('/trips/${Uri.encodeComponent(text)}');
  }

  Future<void> _openData(Map<String, dynamic> data) async {
    final targetPath = data['targetPath']?.toString().trim();
    if (targetPath != null && targetPath.startsWith('/')) {
      await _onOpen?.call(targetPath);
      return;
    }
    final chatId = data['chatId']?.toString().trim();
    if (chatId != null && chatId.isNotEmpty) {
      await _onOpen?.call('/chat/${Uri.encodeComponent(chatId)}');
      return;
    }
    final tripId = data['tripId']?.toString().trim();
    if (tripId != null && tripId.isNotEmpty) {
      await _onOpen?.call('/trips/${Uri.encodeComponent(tripId)}');
      return;
    }
    await _onOpen?.call('/notifications');
  }

  int _notificationId(String seed) {
    var hash = 17;
    for (final codeUnit in seed.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + codeUnit);
    }
    return 100000 + (hash % 900000);
  }

  bool get _supportsFirebaseMessaging {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _browserClickSubscription?.cancel();
  }
}
