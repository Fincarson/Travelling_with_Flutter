import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  const AccountAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountAuthService {
  AccountAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static Future<void>? _googleInit;

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
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmedName);
    }
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
          await _auth.signInWithCredential(credential);
          completer.complete(PhoneSignInSession.autoVerified());
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
      await confirmationResult.confirm(code);
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
    await _auth.signInWithCredential(credential);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }

    _googleInit ??= GoogleSignIn.instance.initialize();
    await _googleInit;

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AccountAuthException(
        'Google Sign-In is not available on this platform yet.',
      );
    }

    final googleAccount = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleAccount.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        _googleInit ??= GoogleSignIn.instance.initialize();
        await _googleInit;
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out is the source of truth for this app.
      }
    }
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
}
