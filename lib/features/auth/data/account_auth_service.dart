import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticatedAccount {
  const AuthenticatedAccount({
    required this.uid,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;

  String get name {
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;

    final emailName = email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) return emailName;

    final phone = phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;

    return 'Explorer';
  }

  String get contactLabel {
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) return trimmedEmail;

    final phone = phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;

    return 'Signed in';
  }

  factory AuthenticatedAccount.fromFirebaseUser(User user) {
    return AuthenticatedAccount(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }
}

class PhoneSignInSession {
  const PhoneSignInSession._({
    this.confirmationResult,
    this.verificationId,
    this.autoVerified = false,
  });

  final ConfirmationResult? confirmationResult;
  final String? verificationId;
  final bool autoVerified;

  factory PhoneSignInSession.web(ConfirmationResult result) =>
      PhoneSignInSession._(confirmationResult: result);

  factory PhoneSignInSession.mobile(String verificationId) =>
      PhoneSignInSession._(verificationId: verificationId);

  factory PhoneSignInSession.autoVerified() =>
      const PhoneSignInSession._(autoVerified: true);
}

class AccountAuthException implements Exception {
  const AccountAuthException(
    this.message, {
    this.code,
    this.details,
    this.isUnexpected = false,
  });

  final String message;
  final String? code;
  final String? details;
  final bool isUnexpected;

  @override
  String toString() => message;
}

class GoogleAccountLinkRequiredException implements Exception {
  const GoogleAccountLinkRequiredException({
    required this.email,
    required this.googleCredential,
  });

  final String email;
  final AuthCredential googleCredential;
}

class LinkedAuthProviders {
  const LinkedAuthProviders({
    required this.email,
    required this.google,
    required this.phone,
    this.emailAddress,
    this.googleEmail,
    this.phoneNumber,
  });

  final bool email;
  final bool google;
  final bool phone;
  final String? emailAddress;
  final String? googleEmail;
  final String? phoneNumber;

  int get count => [email, google, phone].where((linked) => linked).length;
}

class AccountAuthService {
  AccountAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static Future<void>? _googleInit;
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const rememberDuration = Duration(days: 30);
  static const _rememberedUidKey = 'account_auth.remembered_uid';
  static const _rememberUntilKey = 'account_auth.remember_until';

  Stream<AuthenticatedAccount?> get accountChanges {
    return _auth.userChanges().map((user) {
      if (user == null) return null;
      return AuthenticatedAccount.fromFirebaseUser(user);
    });
  }

  AuthenticatedAccount? get currentAccount {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthenticatedAccount.fromFirebaseUser(user);
  }

  LinkedAuthProviders get linkedProviders {
    final user = _auth.currentUser;
    UserInfo? provider(String providerId) {
      for (final info in user?.providerData ?? const <UserInfo>[]) {
        if (info.providerId == providerId) return info;
      }
      return null;
    }

    final passwordProvider = provider('password');
    final googleProvider = provider('google.com');
    final phoneProvider = provider('phone');
    return LinkedAuthProviders(
      email: passwordProvider != null,
      google: googleProvider != null,
      phone: phoneProvider != null,
      emailAddress: passwordProvider?.email ?? user?.email,
      googleEmail: googleProvider?.email,
      phoneNumber: phoneProvider?.phoneNumber ?? user?.phoneNumber,
    );
  }

  Future<AuthenticatedAccount?> restoreRememberedAccount() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final rememberedUid = prefs.getString(_rememberedUidKey);
    final rememberUntilText = prefs.getString(_rememberUntilKey);
    final rememberUntil = rememberUntilText == null
        ? null
        : DateTime.tryParse(rememberUntilText)?.toUtc();
    final isRemembered =
        rememberedUid == user.uid &&
        rememberUntil != null &&
        DateTime.now().toUtc().isBefore(rememberUntil);

    if (!isRemembered) {
      await signOut();
      return null;
    }

    return AuthenticatedAccount.fromFirebaseUser(user);
  }

  Future<void> rememberCurrentSession({required bool remember}) async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    if (!remember || user == null) {
      await prefs.remove(_rememberedUidKey);
      await prefs.remove(_rememberUntilKey);
      return;
    }

    final rememberUntil = DateTime.now().toUtc().add(rememberDuration);
    await prefs.setString(_rememberedUidKey, user.uid);
    await prefs.setString(_rememberUntilKey, rememberUntil.toIso8601String());
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createEmailAccount({
    required String name,
    required String email,
    required String password,
    List<String> interests = const [],
    String? ageRange,
    String travelPace = 'Balanced',
    String? termsVersion,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmedName);
      await credential.user?.reload();
    }
    await _saveNewAccountProfile(
      credential,
      displayName: trimmedName,
      interests: interests,
      ageRange: ageRange,
      travelPace: travelPace,
      termsVersion: termsVersion,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  bool get supportsPhoneSignIn {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<PhoneSignInSession> sendPhoneCode(String phoneNumber) async {
    if (!supportsPhoneSignIn) {
      throw const AccountAuthException(
        'Phone SMS sign-in works on web, Android, and iOS. Use email on this device.',
      );
    }

    final trimmedPhone = phoneNumber.trim();
    if (!trimmedPhone.startsWith('+')) {
      throw const AccountAuthException(
        'Use international phone format, for example +15551234567.',
      );
    }

    if (kIsWeb) {
      final confirmationResult = await _auth.signInWithPhoneNumber(
        trimmedPhone,
      );
      return PhoneSignInSession.web(confirmationResult);
    }

    final completer = Completer<PhoneSignInSession>();

    await _auth.verifyPhoneNumber(
      phoneNumber: trimmedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        if (!completer.isCompleted) {
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            await _rejectNewProviderAccount(
              userCredential,
              'No account is linked to that phone number. Sign in with email, then link the phone number in Profile.',
            );
            completer.complete(PhoneSignInSession.autoVerified());
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        }
      },
      verificationFailed: (exception) {
        if (!completer.isCompleted) completer.completeError(exception);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(PhoneSignInSession.mobile(verificationId));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<void> confirmPhoneCode({
    required PhoneSignInSession session,
    required String smsCode,
  }) async {
    final code = smsCode.trim();
    if (code.isEmpty) {
      throw const AccountAuthException('Enter the SMS verification code.');
    }

    final confirmationResult = session.confirmationResult;
    if (confirmationResult != null) {
      final credential = await confirmationResult.confirm(code);
      await _rejectNewProviderAccount(
        credential,
        'No account is linked to that phone number. Sign in with email, then link the phone number in Profile.',
      );
      return;
    }

    final verificationId = session.verificationId;
    if (verificationId == null) {
      if (session.autoVerified) return;
      throw const AccountAuthException('Ask for a new SMS code and try again.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _rejectNewProviderAccount(
      userCredential,
      'No account is linked to that phone number. Sign in with email, then link the phone number in Profile.',
    );
  }

  Future<void> signInWithGoogle() async {
    AuthCredential? requestedCredential;
    try {
      final userCredential = kIsWeb
          ? await _auth.signInWithPopup(GoogleAuthProvider())
          : await _signInWithNativeGoogle(
              onCredential: (credential) => requestedCredential = credential,
            );
      await _rejectNewProviderAccount(
        userCredential,
        'No account exists for that Google email. Create an account with email first, then link Google in Profile.',
      );
    } on FirebaseAuthException catch (error) {
      if (_requiresExistingAccountLink(error)) {
        final email = error.email?.trim();
        final credential = error.credential ?? requestedCredential;
        if (email != null && email.isNotEmpty && credential != null) {
          throw GoogleAccountLinkRequiredException(
            email: email,
            googleCredential: credential,
          );
        }
      }
      rethrow;
    } on GoogleSignInException catch (error) {
      throw _googleAccountAuthException(error);
    }
  }

  Future<void> completeGoogleAccountLink({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    final emailCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = emailCredential.user;
    if (user == null) {
      throw const AccountAuthException(
        'Could not open the existing email account.',
      );
    }
    await user.linkWithCredential(googleCredential);
    await user.reload();
  }

  Future<void> linkGoogleToCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException('Sign in before linking Google.');
    }
    if (linkedProviders.google) {
      throw const AccountAuthException('Google is already linked.');
    }

    try {
      if (kIsWeb) {
        await user.linkWithPopup(GoogleAuthProvider());
      } else {
        final credential = await _nativeGoogleCredential();
        await user.linkWithCredential(credential);
      }
      await user.reload();
    } on GoogleSignInException catch (error) {
      throw _googleAccountAuthException(error);
    }
  }

  Future<void> unlinkProvider(String providerId) async {
    const supportedProviders = {'password', 'google.com', 'phone'};
    if (!supportedProviders.contains(providerId)) {
      throw const AccountAuthException(
        'That sign-in method cannot be unlinked here.',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException(
        'Sign in before changing linked accounts.',
      );
    }
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (!providerIds.contains(providerId)) {
      throw const AccountAuthException('That sign-in method is not linked.');
    }
    if (providerIds.length <= 1) {
      throw const AccountAuthException(
        'Link another sign-in method before unlinking this one.',
      );
    }

    await user.unlink(providerId);
    await user.reload();
    if (providerId == 'google.com' && !kIsWeb) {
      unawaited(_signOutFromGoogle());
    }
  }

  Future<PhoneSignInSession> sendPhoneLinkCode(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException('Sign in before linking a phone.');
    }
    if (linkedProviders.phone) {
      throw const AccountAuthException('A phone number is already linked.');
    }
    if (!supportsPhoneSignIn) {
      throw const AccountAuthException(
        'Phone linking works on web, Android, and iOS.',
      );
    }

    final trimmedPhone = phoneNumber.trim();
    if (!trimmedPhone.startsWith('+')) {
      throw const AccountAuthException(
        'Use international phone format, for example +15551234567.',
      );
    }

    if (kIsWeb) {
      final confirmationResult = await user.linkWithPhoneNumber(trimmedPhone);
      return PhoneSignInSession.web(confirmationResult);
    }

    final completer = Completer<PhoneSignInSession>();
    await _auth.verifyPhoneNumber(
      phoneNumber: trimmedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        if (completer.isCompleted) return;
        try {
          await user.linkWithCredential(credential);
          await user.reload();
          completer.complete(PhoneSignInSession.autoVerified());
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
      verificationFailed: (exception) {
        if (!completer.isCompleted) completer.completeError(exception);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(PhoneSignInSession.mobile(verificationId));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<void> confirmPhoneLinkCode({
    required PhoneSignInSession session,
    required String smsCode,
  }) async {
    final code = smsCode.trim();
    if (code.isEmpty) {
      throw const AccountAuthException('Enter the SMS verification code.');
    }

    final confirmationResult = session.confirmationResult;
    if (confirmationResult != null) {
      await confirmationResult.confirm(code);
      await _auth.currentUser?.reload();
      return;
    }

    final verificationId = session.verificationId;
    if (verificationId == null) {
      if (session.autoVerified) return;
      throw const AccountAuthException('Ask for a new SMS code and try again.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException('Sign in before linking a phone.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await user.linkWithCredential(credential);
    await user.reload();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    unawaited(_clearRememberedSession());
    if (!kIsWeb) unawaited(_signOutFromGoogle());
  }

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException('No signed-in account to delete.');
    }
    _ensureRecentSignIn(user);
    await user.delete();
  }

  void ensureCanDeleteCurrentAccount() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthException('No signed-in account to delete.');
    }
    _ensureRecentSignIn(user);
  }

  void _ensureRecentSignIn(User user) {
    final lastSignInTime = user.metadata.lastSignInTime;
    if (lastSignInTime == null ||
        DateTime.now().toUtc().difference(lastSignInTime.toUtc()) >
            const Duration(minutes: 5)) {
      throw const AccountAuthException(
        'Please sign out, sign in again, then delete the account.',
      );
    }
  }

  static Future<void> _initializeGoogleSignIn() {
    return _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
  }

  Future<UserCredential> _signInWithNativeGoogle({
    required ValueChanged<AuthCredential> onCredential,
  }) async {
    final credential = await _nativeGoogleCredential();
    onCredential(credential);
    return _auth.signInWithCredential(credential);
  }

  static Future<AuthCredential> _nativeGoogleCredential() async {
    await _initializeGoogleSignIn();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AccountAuthException(
        'Google Sign-In is not available on this platform yet.',
      );
    }

    final googleAccount = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleAccount.authentication;
    return GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  }

  static Future<void> _signOutFromGoogle() async {
    try {
      await _initializeGoogleSignIn();
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Firebase Auth is authoritative; provider cleanup must not block logout.
    }
  }

  static Future<void> _clearRememberedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rememberedUidKey);
      await prefs.remove(_rememberUntilKey);
    } catch (_) {
      // A local preference failure must not restore a signed-out Firebase user.
    }
  }

  Future<void> _rejectNewProviderAccount(
    UserCredential credential,
    String message,
  ) async {
    if (credential.additionalUserInfo?.isNewUser != true) return;

    final newUser = credential.user;
    try {
      await newUser?.delete();
    } finally {
      if (_auth.currentUser?.uid == newUser?.uid) {
        await _auth.signOut();
      }
    }
    throw AccountAuthException(message);
  }

  static Future<void> _saveNewAccountProfile(
    UserCredential credential, {
    String? displayName,
    List<String> interests = const [],
    String? ageRange,
    String travelPace = 'Balanced',
    String? termsVersion,
  }) async {
    if (credential.additionalUserInfo?.isNewUser != true) return;
    final user = credential.user ?? FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    final trimmedName = (displayName ?? user?.displayName ?? '').trim();
    final trimmedEmail = (user?.email ?? '').trim();
    final photoUrl = user?.photoURL;
    final completedOnboarding =
        termsVersion != null && termsVersion.trim().isNotEmpty;
    final profileData = <String, dynamic>{
      'interests': interests,
      'onboarding': {'ageRange': ageRange, 'travelPace': travelPace},
      'settings': {
        'onboardingRequired': !completedOnboarding,
        'onboardingCompleted': completedOnboarding,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (completedOnboarding) {
      profileData['legalConsent'] = {
        'termsVersion': termsVersion.trim(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'draftTerms': true,
      };
    }
    if (trimmedName.isNotEmpty) profileData['name'] = trimmedName;
    if (trimmedEmail.isNotEmpty) profileData['email'] = trimmedEmail;
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      profileData['photoUrl'] = photoUrl.trim();
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(
      firestore.collection('travel_users').doc(uid),
      profileData,
      SetOptions(merge: true),
    );
    batch.set(firestore.collection('public_users').doc(uid), {
      'displayName': trimmedName.isEmpty ? 'Explorer' : trimmedName,
      'emailLower': trimmedEmail.toLowerCase(),
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}

bool _requiresExistingAccountLink(FirebaseAuthException error) {
  return error.code == 'account-exists-with-different-credential' ||
      error.code == 'email-already-in-use';
}

String _googleSignInMessage(GoogleSignInException error) {
  return switch (error.code) {
    GoogleSignInExceptionCode.canceled => 'Google Sign-In was canceled.',
    GoogleSignInExceptionCode.interrupted =>
      'Google Sign-In was interrupted. Please try again.',
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Google Sign-In is not configured for this app build. Refresh google-services.json after registering the app SHA fingerprints.',
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google Sign-In is unavailable on this device.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google Sign-In could not open its account picker.',
    _ => error.description ?? 'Google Sign-In failed. Please try again.',
  };
}

AccountAuthException _googleAccountAuthException(GoogleSignInException error) {
  final isExpected =
      error.code == GoogleSignInExceptionCode.canceled ||
      error.code == GoogleSignInExceptionCode.interrupted;
  return AccountAuthException(
    _googleSignInMessage(error),
    code: 'google-sign-in-${error.code.name}',
    details: error.toString(),
    isUnexpected: !isExpected,
  );
}
