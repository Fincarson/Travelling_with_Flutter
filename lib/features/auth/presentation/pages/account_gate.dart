import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/travel_agent_app.dart';
import '../../../../core/localization/app_text.dart';
import '../../../../core/performance/app_performance.dart';
import '../../../../shared/widgets/app_error_widgets.dart';
import '../../data/account_auth_service.dart';

class AccountGate extends StatefulWidget {
  const AccountGate({super.key, AccountAuthService? authService})
    : _providedAuthService = authService;

  final AccountAuthService? _providedAuthService;

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  final _deviceContextService = AppDeviceContextService();
  final _locationPromptedAccountIds = <String>{};
  AccountAuthService? _authService;
  Future<AuthenticatedAccount?>? _rememberedAccount;
  var _showStartupOnboarding = true;
  PreAccountOnboardingData? _startupOnboarding;

  void _initializeAuth() {
    final authService = _authService ??=
        widget._providedAuthService ?? AccountAuthService();
    _rememberedAccount ??= authService.restoreRememberedAccount();
  }

  @override
  Widget build(BuildContext context) {
    if (_showStartupOnboarding) {
      return PreAccountOnboardingFlow(
        initialData: _startupOnboarding,
        onBack: () => setState(() => _showStartupOnboarding = false),
        onComplete: (data) {
          setState(() {
            _startupOnboarding = data;
            _showStartupOnboarding = false;
          });
        },
      );
    }

    _initializeAuth();
    final authService = _authService!;
    return FutureBuilder<AuthenticatedAccount?>(
      future: _rememberedAccount!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _AuthFrame(child: _AuthLoading());
        }

        return StreamBuilder<AuthenticatedAccount?>(
          stream: authService.accountChanges,
          initialData: snapshot.data,
          builder: (context, snapshot) {
            final account = snapshot.data;
            if (account == null) {
              return _AuthFrame(
                child: AccountSignInPage(
                  authService: authService,
                  initialOnboarding: _startupOnboarding,
                ),
              );
            }

            unawaited(_requestLocationAfterLogin(account.uid));
            return TravelAgentApp(
              key: ValueKey(account.uid),
              account: account,
              startupOnboarding: _startupOnboarding,
            );
          },
        );
      },
    );
  }

  Future<void> _requestLocationAfterLogin(String accountId) async {
    if (!_locationPromptedAccountIds.add(accountId)) return;
    await _deviceContextService.load(requestLocation: true);
  }
}

class AccountSignInPage extends StatefulWidget {
  const AccountSignInPage({
    required this.authService,
    this.initialOnboarding,
    super.key,
  });

  final AccountAuthService authService;
  final PreAccountOnboardingData? initialOnboarding;

  @override
  State<AccountSignInPage> createState() => _AccountSignInPageState();
}

class _AccountSignInPageState extends State<AccountSignInPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();

  var _mode = _AccountMode.email;
  var _isCreatingAccount = false;
  var _isBusy = false;
  var _emailAuthFailed = false;
  var _phoneAuthFailed = false;
  var _showPasswordReset = false;
  var _showOnboarding = false;
  PreAccountOnboardingData? _pendingOnboarding;
  PhoneSignInSession? _phoneSession;

  @override
  void initState() {
    super.initState();
    _pendingOnboarding = widget.initialOnboarding;
    _name.text = widget.initialOnboarding?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _runAuth(
    Future<void> Function() action, {
    _AuthErrorTarget errorTarget = _AuthErrorTarget.none,
  }) async {
    setState(() {
      _isBusy = true;
      if (errorTarget == _AuthErrorTarget.email) {
        _emailAuthFailed = false;
      }
      if (errorTarget == _AuthErrorTarget.phone) {
        _phoneAuthFailed = false;
      }
    });

    try {
      await action();
    } on FirebaseAuthException catch (error, stackTrace) {
      if (!mounted) return;
      if (_isUnexpectedFirebaseAuthError(error)) {
        await showUnexpectedErrorDialog(context, error, stackTrace, error.code);
        return;
      }
      _showAuthError(_firebaseMessage(error), errorTarget);
    } on AccountAuthException catch (error, stackTrace) {
      if (!mounted) return;
      if (error.isUnexpected) {
        await showUnexpectedErrorDialog(
          context,
          error.details ?? error,
          stackTrace,
          error.code,
        );
        return;
      }
      _showAuthError(error.message, errorTarget);
    } catch (error, stackTrace) {
      if (!mounted) return;
      await showUnexpectedErrorDialog(context, error, stackTrace);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showAuthError(String message, _AuthErrorTarget target) {
    setState(() {
      if (target == _AuthErrorTarget.email) _emailAuthFailed = true;
      if (target == _AuthErrorTarget.phone) _phoneAuthFailed = true;
    });
    _showNotice(message, isError: true);
  }

  void _showNotice(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            appText(context, message),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB3261E)
              : const Color(0xFF355872),
        ),
      );
  }

  void _clearEmailAuthError() {
    if (_emailAuthFailed) setState(() => _emailAuthFailed = false);
  }

  void _clearPhoneAuthError() {
    if (_phoneAuthFailed) setState(() => _phoneAuthFailed = false);
  }

  void _switchMode(_AccountMode mode) {
    if (_isBusy || _mode == mode) return;
    setState(() {
      _mode = mode;
      _isCreatingAccount = false;
      _phoneSession = null;
      _smsCode.clear();
      _emailAuthFailed = false;
      _phoneAuthFailed = false;
    });
  }

  Future<void> _submitEmail() async {
    if (_isCreatingAccount && _pendingOnboarding == null) {
      setState(() => _showOnboarding = true);
      return;
    }
    final form = _emailFormKey.currentState;
    if (form == null || !form.validate()) return;

    await _runAuth(() async {
      if (_isCreatingAccount) {
        final onboarding = _pendingOnboarding!;
        await widget.authService.createEmailAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          interests: onboarding.interests,
          ageRange: onboarding.ageRange,
          travelPace: onboarding.travelPace,
          termsVersion: onboarding.termsVersion,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }
      await widget.authService.rememberCurrentSession(remember: true);
    }, errorTarget: _AuthErrorTarget.email);
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      _showAuthError(
        'Use international phone format, for example +15551234567.',
        _AuthErrorTarget.phone,
      );
      return;
    }

    await _runAuth(() async {
      final session = await widget.authService.sendPhoneCode(phone);
      if (!mounted) return;
      if (session.autoVerified) {
        await widget.authService.rememberCurrentSession(remember: true);
        return;
      }
      setState(() {
        _phoneSession = session;
        _smsCode.clear();
      });
      _showNotice('SMS code sent.');
    }, errorTarget: _AuthErrorTarget.phone);
  }

  Future<void> _confirmPhoneCode() async {
    final form = _phoneFormKey.currentState;
    if (form != null && !form.validate()) return;

    final session = _phoneSession;
    if (session == null) {
      _showAuthError('Send an SMS code first.', _AuthErrorTarget.phone);
      return;
    }

    await _runAuth(() async {
      await widget.authService.confirmPhoneCode(
        session: session,
        smsCode: _smsCode.text,
      );
      await widget.authService.rememberCurrentSession(remember: true);
    }, errorTarget: _AuthErrorTarget.phone);
  }

  Future<void> _signInWithGoogle() async {
    GoogleAccountLinkRequiredException? pendingLink;
    await _runAuth(() async {
      try {
        await widget.authService.signInWithGoogle();
        await widget.authService.rememberCurrentSession(remember: true);
      } on GoogleAccountLinkRequiredException catch (error) {
        pendingLink = error;
      }
    });

    final link = pendingLink;
    if (link == null || !mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _GoogleAccountLinkDialog(email: link.email),
    );
    if (password == null || !mounted) return;

    await _runAuth(() async {
      await widget.authService.completeGoogleAccountLink(
        email: link.email,
        password: password,
        googleCredential: link.googleCredential,
      );
      await widget.authService.rememberCurrentSession(remember: true);
    }, errorTarget: _AuthErrorTarget.email);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return PreAccountOnboardingFlow(
        initialData: _pendingOnboarding,
        onBack: () => setState(() => _showOnboarding = false),
        onComplete: (data) {
          setState(() {
            _pendingOnboarding = data;
            _name.text = data.name;
            _isCreatingAccount = true;
            _showOnboarding = false;
            _emailAuthFailed = false;
          });
        },
      );
    }

    if (_showPasswordReset) {
      return PasswordResetPage(
        authService: widget.authService,
        initialEmail: _email.text.trim(),
        onBack: () => setState(() => _showPasswordReset = false),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: _authPagePadding(context),
          children: [
            const SizedBox(height: 10),
            const Hero(
              tag: 'travel-plane-logo',
              child: Icon(
                Icons.flight_takeoff_rounded,
                color: Color(0xFF355872),
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              appText(context, 'Travel Agent'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appText(
                context,
                'Sign in to keep your trips, AI plans, budgets, and packing lists synced.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7AAACE),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: PerformanceScope.maybeSettingsOf(
                context,
              ).transitionDuration,
              child: _mode == _AccountMode.email
                  ? _buildEmailForm()
                  : _buildPhoneForm(),
            ),
            if (!_isCreatingAccount) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      appText(context, 'or continue with'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF7AAACE),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: Text(appText(context, 'Continue with Google')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _switchMode(
                        _mode == _AccountMode.email
                            ? _AccountMode.phone
                            : _AccountMode.email,
                      ),
                icon: Icon(
                  _mode == _AccountMode.email
                      ? Icons.phone_iphone_rounded
                      : Icons.alternate_email_rounded,
                ),
                label: Text(
                  appText(
                    context,
                    _mode == _AccountMode.email
                        ? 'Continue with phone number'
                        : 'Continue with email',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.facebook_rounded),
                label: Text(appText(context, 'Facebook coming later')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isCreatingAccount) ...[
            _AccountOnboardingSummary(
              data: _pendingOnboarding,
              onEdit: _isBusy
                  ? null
                  : () => setState(() => _showOnboarding = true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              enabled: !_isBusy,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: appText(context, 'Name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _email,
            enabled: !_isBusy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => _clearEmailAuthError(),
            decoration: _authFieldDecoration(
              hasAuthError: _emailAuthFailed,
              labelText: appText(context, 'Email'),
              prefixIcon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              if (!_looksLikeEmail(value ?? '')) {
                return appText(context, 'Enter a valid email.');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            enabled: !_isBusy,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _clearEmailAuthError(),
            decoration: _authFieldDecoration(
              hasAuthError: _emailAuthFailed,
              labelText: appText(context, 'Password'),
              prefixIcon: Icons.lock_outline_rounded,
            ),
            validator: (value) {
              if ((value ?? '').length < 6) {
                return appText(context, 'Use at least 6 characters.');
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitEmail(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBusy ? null : _submitEmail,
            icon: _isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isCreatingAccount
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(
              appText(
                context,
                _isCreatingAccount ? 'Create account' : 'Sign in',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                    if (_isCreatingAccount) {
                      _isCreatingAccount = false;
                    } else if (_pendingOnboarding != null) {
                      _isCreatingAccount = true;
                    } else {
                      _showOnboarding = true;
                    }
                    _emailAuthFailed = false;
                  }),
            child: Text(
              appText(
                context,
                _isCreatingAccount
                    ? 'I already have an account'
                    : 'Create a new account',
              ),
            ),
          ),
          if (!_isCreatingAccount)
            TextButton.icon(
              onPressed: _isBusy
                  ? null
                  : () => setState(() => _showPasswordReset = true),
              icon: const Icon(Icons.help_outline_rounded),
              label: Text(appText(context, 'Forgot password?')),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    final hasSession = _phoneSession != null;
    final supportsPhoneSignIn = widget.authService.supportsPhoneSignIn;

    if (!supportsPhoneSignIn) {
      return const Column(
        key: ValueKey('phone-unavailable'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusMessage(
            message:
                'Phone SMS sign-in works on web, Android, and iOS. Use email on this device.',
          ),
        ],
      );
    }

    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phone,
            enabled: !_isBusy && !hasSession,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _clearPhoneAuthError(),
            decoration: _authFieldDecoration(
              hasAuthError: _phoneAuthFailed,
              labelText: appText(context, 'Phone number'),
              hintText: '+15551234567',
              prefixIcon: Icons.phone_iphone_rounded,
            ),
            validator: (value) {
              final phone = (value ?? '').trim();
              if (!phone.startsWith('+') || phone.length < 8) {
                return appText(
                  context,
                  'Use international format with + country code.',
                );
              }
              return null;
            },
          ),
          if (hasSession) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _smsCode,
              enabled: !_isBusy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _clearPhoneAuthError(),
              decoration: _authFieldDecoration(
                hasAuthError: _phoneAuthFailed,
                labelText: appText(context, 'SMS code'),
                prefixIcon: Icons.sms_outlined,
              ),
              validator: (value) {
                final code = (value ?? '').trim();
                if (code.length < 6) {
                  return appText(context, 'Enter the 6-digit SMS code.');
                }
                return null;
              },
              onFieldSubmitted: (_) => _confirmPhoneCode(),
            ),
            const SizedBox(height: 8),
            Text(
              appText(context, 'Keep this window open while the SMS arrives.'),
              style: const TextStyle(
                color: Color(0xFF7AAACE),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBusy
                ? null
                : hasSession
                ? _confirmPhoneCode
                : _sendPhoneCode,
            icon: _isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasSession
                        ? Icons.verified_rounded
                        : Icons.mark_email_read_rounded,
                  ),
            label: Text(
              appText(context, hasSession ? 'Verify code' : 'Send SMS code'),
            ),
          ),
          if (hasSession) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isBusy ? null : _sendPhoneCode,
                    child: Text(appText(context, 'Resend code')),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _isBusy
                        ? null
                        : () => setState(() {
                            _phoneSession = null;
                            _smsCode.clear();
                            _phoneAuthFailed = false;
                          }),
                    child: Text(appText(context, 'Change phone')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    required this.authService,
    required this.initialEmail,
    required this.onBack,
    super.key,
  });

  final AccountAuthService authService;
  final String initialEmail;
  final VoidCallback onBack;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  var _isSending = false;
  var _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _emailSent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _firebaseMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send the reset email. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: _authPagePadding(context),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: appText(context, 'Back'),
                onPressed: _isSending ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 12),
            const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF355872),
              size: 48,
            ),
            const SizedBox(height: 18),
            Text(
              appText(context, 'Forgot password'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appText(
                context,
                'Enter the email used for your password account. Firebase will send a secure reset link.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7AAACE),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                enabled: !_isSending,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: appText(context, 'Email'),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) => _looksLikeEmail(value ?? '')
                    ? null
                    : appText(context, 'Enter a valid email.'),
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSending ? null : _submit,
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined),
              label: Text(
                appText(
                  context,
                  _emailSent ? 'Resend reset email' : 'Send reset email',
                ),
              ),
            ),
            if (_emailSent) ...[
              const SizedBox(height: 18),
              _ResetEmailHelp(email: _email.text.trim()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              _StatusMessage(message: _error!, isError: true),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSending ? null : widget.onBack,
              child: Text(appText(context, 'Return to sign in')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetEmailHelp extends StatelessWidget {
  const _ResetEmailHelp({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9CD5FF).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF3F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, 'Check your email'),
            style: const TextStyle(
              color: Color(0xFF355872),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appText(
              context,
              'If $email belongs to a password account, the reset link should arrive shortly.',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            appText(
              context,
              'Check Spam, Junk, and Promotions. Also confirm the address is exactly the one used to create the account. Google-only accounts do not have an email password to reset.',
            ),
            style: const TextStyle(
              color: Color(0xFF7AAACE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleAccountLinkDialog extends StatefulWidget {
  const _GoogleAccountLinkDialog({required this.email});

  final String email;

  @override
  State<_GoogleAccountLinkDialog> createState() =>
      _GoogleAccountLinkDialogState();
}

class _GoogleAccountLinkDialogState extends State<_GoogleAccountLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(appText(context, 'Connect Google account')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appText(
                  context,
                  'An account already exists for ${widget.email}. Enter its password once to prove it is yours. Google will then be linked to the same account.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.email,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: appText(context, 'Email'),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                autofocus: true,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: appText(context, 'Existing password'),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? appText(context, 'Enter your existing password.')
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appText(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(appText(context, 'Connect and sign in')),
        ),
      ],
    );
  }
}

class _AccountOnboardingSummary extends StatelessWidget {
  const _AccountOnboardingSummary({required this.data, required this.onEdit});

  final PreAccountOnboardingData? data;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final onboarding = data;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.primary.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Onboarding complete',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onboarding == null
                        ? 'Complete your preferences and draft terms.'
                        : '${onboarding.interests.length} interests • ${onboarding.travelPace} pace • Terms accepted',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
      ),
    );
  }
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE5E7EB),
      child: ClipRect(child: child),
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFB3261E).withValues(alpha: .1)
            : const Color(0xFF9CD5FF).withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0xFFB3261E) : const Color(0xFFEFF3F6),
        ),
      ),
      child: Text(
        appText(context, message),
        style: TextStyle(
          color: isError ? const Color(0xFFB3261E) : const Color(0xFF355872),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _AccountMode { email, phone }

enum _AuthErrorTarget { none, email, phone }

InputDecoration _authFieldDecoration({
  required bool hasAuthError,
  required String labelText,
  required IconData prefixIcon,
  String? hintText,
}) {
  const errorColor = Color(0xFFB3261E);
  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: const BorderSide(color: errorColor, width: 2),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: Icon(prefixIcon, color: hasAuthError ? errorColor : null),
    labelStyle: hasAuthError ? const TextStyle(color: errorColor) : null,
    enabledBorder: hasAuthError ? errorBorder : null,
    focusedBorder: hasAuthError ? errorBorder : null,
  );
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

EdgeInsets _authPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width < 340
      ? 12.0
      : width < 420
      ? 16.0
      : 24.0;
  return EdgeInsets.fromLTRB(horizontal, 28, horizontal, 28);
}

String _firebaseMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'email-already-in-use' => 'That email already has an account.',
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' => 'Email or password is incorrect.',
    'user-not-found' => 'No account was found for that email.',
    'wrong-password' => 'Email or password is incorrect.',
    'weak-password' => 'Use a stronger password.',
    'network-request-failed' => 'Check your connection and try again.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'operation-not-allowed' =>
      'This sign-in provider is not enabled in Firebase.',
    'popup-closed-by-user' => 'The sign-in window was closed.',
    'invalid-verification-code' => 'The SMS code is not correct.',
    'invalid-phone-number' => 'Enter a valid phone number with country code.',
    'credential-already-in-use' =>
      'That sign-in method is already connected to another account.',
    'account-exists-with-different-credential' =>
      'That email already uses another sign-in method.',
    'quota-exceeded' => 'The SMS limit has been reached. Try again later.',
    _ => error.message ?? 'Could not sign in. Please try again.',
  };
}

bool _isUnexpectedFirebaseAuthError(FirebaseAuthException error) {
  return const {
    'app-not-authorized',
    'configuration-not-found',
    'internal-error',
    'missing-client-type',
    'operation-not-allowed',
    'web-context-cancelled',
  }.contains(error.code);
}
