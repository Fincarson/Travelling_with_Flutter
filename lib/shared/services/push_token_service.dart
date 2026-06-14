part of travel_agent_app;

class PushTokenService {
  PushTokenService(this._firestore);

  final FirebaseFirestore _firestore;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _accountId;
  String? _currentTokenId;

  Future<PushTokenSyncResult> sync({
    required String accountId,
    required bool enabled,
  }) async {
    _accountId = accountId;
    if (!enabled) {
      await unregister();
      return const PushTokenSyncResult(
        PushTokenSyncStatus.disabled,
        'Notifications are off.',
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
          'Browser notifications are blocked. Allow notifications in site settings, then press the bell again.',
        );
      }
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.dismissed,
          'Notification permission was not granted. Press the bell again and choose Allow.',
        );
      }

      final vapidKey = await FirebasePushConfig.loadWebVapidKey();
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
        'Notifications are ready on this browser.',
      );
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      if (errorText.contains('unsupported') ||
          errorText.contains('permission-blocked')) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.unsupported,
          'This browser is not accepting web push from the app right now.',
        );
      }
      if (errorText.contains('notallowederror') ||
          errorText.contains('permission denied')) {
        return const PushTokenSyncResult(
          PushTokenSyncStatus.denied,
          'Browser notifications are blocked. Allow notifications in site settings, then press the bell again.',
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
    _tokenRefreshSubscription = null;
    _currentTokenId = null;
    if (accountId == null || tokenId == null) return;
    await _tokenDoc(accountId, tokenId).delete().catchError((_) {});
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
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
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
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
