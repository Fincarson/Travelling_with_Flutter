part of travel_agent_app;

class PushTokenService {
  PushTokenService(this._firestore);

  final FirebaseFirestore _firestore;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Timer? _presenceHeartbeat;
  String? _accountId;
  String? _currentTokenId;
  String? _activeChatId;
  var _isForeground = true;

  Future<PushTokenSyncResult> sync({
    required String accountId,
    required bool enabled,
  }) async {
    _accountId = accountId;
    if (!enabled) {
      await _disableAllTokens(accountId);
      await unregister();
      return const PushTokenSyncResult(
        PushTokenSyncStatus.disabled,
        'Notifications are off.',
      );
    }
    if (!_supportsFirebaseMessaging) {
      return const PushTokenSyncResult(
        PushTokenSyncStatus.unsupported,
        'Remote push notifications are not supported on this platform.',
      );
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.denied,
          kIsWeb
              ? 'Browser notifications are blocked. Allow notifications in site settings, then try again.'
              : 'Notifications are blocked in device settings.',
        );
      }
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.dismissed,
          'Notification permission was not granted. Press the bell again and choose Allow.',
        );
      }

      final vapidKey = FirebasePushConfig.webVapidKey.trim();
      if (kIsWeb && vapidKey.isEmpty) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.missingVapidKey,
          'Web push is missing its VAPID key in this build.',
        );
      }

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? vapidKey : null,
      );
      if (token == null || token.trim().isEmpty) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.noToken,
          'Firebase did not return a push token. Refresh and try again.',
        );
      }

      await _saveToken(accountId: accountId, token: token);
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        final activeAccountId = _accountId;
        if (activeAccountId == null || newToken.trim().isEmpty) return;
        unawaited(_saveToken(accountId: activeAccountId, token: newToken));
      });

      return const PushTokenSyncResult(
        PushTokenSyncStatus.registered,
        kIsWeb
            ? 'Notifications are ready in this browser.'
            : 'Notifications are ready on this device.',
      );
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      if (errorText.contains('unsupported') ||
          errorText.contains('permission-blocked')) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.unsupported,
          kIsWeb
              ? 'This browser is not accepting web push from the app right now.'
              : 'Push notifications are not supported on this device.',
        );
      }
      return PushTokenSyncResult(
        PushTokenSyncStatus.failed,
        'Could not enable notifications: $error',
      );
    }
  }

  Future<void> unregister() async {
    final accountId = _accountId;
    final tokenId = _currentTokenId;
    await _tokenRefreshSubscription?.cancel();
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    _tokenRefreshSubscription = null;
    _currentTokenId = null;
    if (accountId == null || tokenId == null) return;
    await _tokenDoc(accountId, tokenId).delete().catchError((_) {});
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    _tokenRefreshSubscription = null;
  }

  Future<void> updatePresence({
    required bool isForeground,
    String? activeChatId,
  }) async {
    _isForeground = isForeground;
    _activeChatId = isForeground ? activeChatId : null;
    if (isForeground) {
      _startPresenceHeartbeat();
    } else {
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = null;
    }
    await _writePresence();
  }

  Future<void> _saveToken({
    required String accountId,
    required String token,
  }) async {
    final tokenId = _tokenDocumentId(token);
    _currentTokenId = tokenId;
    await _tokenDoc(accountId, tokenId).set({
      'token': token,
      'platform': _pushPlatformName(),
      'enabled': true,
      'appState': _isForeground ? 'foreground' : 'background',
      'activeChatId': _isForeground ? _activeChatId : null,
      'presenceUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (_isForeground) _startPresenceHeartbeat();
  }

  Future<void> _disableAllTokens(String accountId) async {
    final snapshot = await _userTokensRef(accountId).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final document in snapshot.docs) {
      batch.set(document.reference, {
        'enabled': false,
        'appState': 'background',
        'activeChatId': null,
        'presenceUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_writePresence());
    });
  }

  Future<void> _writePresence() async {
    final accountId = _accountId;
    final tokenId = _currentTokenId;
    if (accountId == null || tokenId == null) return;
    await _tokenDoc(accountId, tokenId).set({
      'appState': _isForeground ? 'foreground' : 'background',
      'activeChatId': _isForeground ? _activeChatId : null,
      'presenceUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _tokenDoc(
    String accountId,
    String tokenId,
  ) {
    return _firestore
        .collection('travel_users')
        .doc(accountId)
        .collection('notificationTokens')
        .doc(tokenId);
  }

  CollectionReference<Map<String, dynamic>> _userTokensRef(String accountId) {
    return _firestore
        .collection('travel_users')
        .doc(accountId)
        .collection('notificationTokens');
  }

  String _tokenDocumentId(String token) =>
      base64Url.encode(utf8.encode(token)).replaceAll('=', '');

  String _pushPlatformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  bool get _supportsFirebaseMessaging {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
}

enum PushTokenSyncStatus {
  disabled,
  registered,
  denied,
  dismissed,
  missingVapidKey,
  noToken,
  unsupported,
  failed,
}

class PushTokenSyncResult {
  const PushTokenSyncResult(this.status, this.message);

  final PushTokenSyncStatus status;
  final String message;

  bool get registered => status == PushTokenSyncStatus.registered;
}
