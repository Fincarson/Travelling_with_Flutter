import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../travel_clone/travel_agent_app.dart';
import '../../data/account_auth_service.dart';

class AccountGate extends StatefulWidget {
  AccountGate({super.key, AccountAuthService? authService})
    : _authService = authService ?? AccountAuthService();

  final AccountAuthService _authService;

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late final Future<AuthenticatedAccount?> _rememberedAccount;

  AccountAuthService get _authService => widget._authService;

  @override
  void initState() {
    super.initState();
    _rememberedAccount = _authService.restoreRememberedAccount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthenticatedAccount?>(
      future: _rememberedAccount,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _AuthFrame(child: _AuthLoading());
        }

        return StreamBuilder<AuthenticatedAccount?>(
          stream: _authService.accountChanges,
          initialData: snapshot.data,
          builder: (context, snapshot) {
            final account = snapshot.data;
            if (account == null) {
              return _AuthFrame(
                child: AccountSignInPage(authService: _authService),
              );
            }

            return TravelAgentApp(key: ValueKey(account.uid), account: account);
          },
        );
      },
    );
  }
}

class AccountSignInPage extends StatefulWidget {
  const AccountSignInPage({required this.authService, super.key});

  final AccountAuthService authService;

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
  var _rememberMe = true;
  String? _message;
  PhoneSignInSession? _phoneSession;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _message = _firebaseMessage(error));
    } on AccountAuthException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not sign in. $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitEmail() async {
    final form = _emailFormKey.currentState;
    if (form == null || !form.validate()) return;

    await _runAuth(() async {
      if (_isCreatingAccount) {
        await widget.authService.createEmailAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }
      await widget.authService.rememberCurrentSession(remember: _rememberMe);
    });
  }

  Future<void> _sendReset() async {
    final email = _email.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _message = 'Enter your email first.');
      return;
    }

    await _runAuth(() async {
      await widget.authService.sendPasswordReset(email);
      if (mounted) {
        setState(() => _message = 'Password reset email sent.');
      }
    });
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() {
        _message = 'Use international phone format, for example +15551234567.';
      });
      return;
    }

    await _runAuth(() async {
      final session = await widget.authService.sendPhoneCode(phone);
      if (!mounted) return;
      if (session.autoVerified) {
        await widget.authService.rememberCurrentSession(remember: _rememberMe);
        return;
      }
      setState(() {
        _phoneSession = session;
        _smsCode.clear();
        _message = 'SMS code sent.';
      });
    });
  }

  Future<void> _confirmPhoneCode() async {
    final form = _phoneFormKey.currentState;
    if (form != null && !form.validate()) return;

    final session = _phoneSession;
    if (session == null) {
      setState(() => _message = 'Send an SMS code first.');
      return;
    }

    await _runAuth(() async {
      await widget.authService.confirmPhoneCode(
        session: session,
        smsCode: _smsCode.text,
      );
      await widget.authService.rememberCurrentSession(remember: _rememberMe);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            const SizedBox(height: 10),
            const Icon(
              Icons.flight_takeoff_rounded,
              color: Color(0xFF355872),
              size: 42,
            ),
            const SizedBox(height: 18),
            Text(
              'Travelling with Flutter',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to keep your trips, AI plans, budgets, and packing lists synced.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7AAACE),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<_AccountMode>(
              segments: const [
                ButtonSegment(
                  value: _AccountMode.email,
                  icon: Icon(Icons.alternate_email_rounded),
                  label: Text('Email'),
                ),
                ButtonSegment(
                  value: _AccountMode.phone,
                  icon: Icon(Icons.phone_iphone_rounded),
                  label: Text('Phone'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _isBusy
                  ? null
                  : (selection) => setState(() {
                      _mode = selection.first;
                      _phoneSession = null;
                      _smsCode.clear();
                      _message = null;
                    }),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _mode == _AccountMode.email
                  ? _buildEmailForm()
                  : _buildPhoneForm(),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _rememberMe,
              onChanged: _isBusy
                  ? null
                  : (value) => setState(() => _rememberMe = value ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Remember me for 30 days',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Useful while debugging. Sign out anytime from Profile.',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
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
              onPressed: _isBusy
                  ? null
                  : () => _runAuth(() async {
                      await widget.authService.signInWithGoogle();
                      await widget.authService.rememberCurrentSession(
                        remember: _rememberMe,
                      );
                    }),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.facebook_rounded),
              label: const Text('Facebook setup needed'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              _StatusMessage(message: _message!),
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
            TextFormField(
              controller: _name,
              enabled: !_isBusy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
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
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              if (!_looksLikeEmail(value ?? '')) return 'Enter a valid email.';
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
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (value) {
              if ((value ?? '').length < 6) {
                return 'Use at least 6 characters.';
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
            label: Text(_isCreatingAccount ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                    _isCreatingAccount = !_isCreatingAccount;
                    _message = null;
                  }),
            child: Text(
              _isCreatingAccount
                  ? 'I already have an account'
                  : 'Create a new account',
            ),
          ),
          if (!_isCreatingAccount)
            TextButton.icon(
              onPressed: _isBusy ? null : _sendReset,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Forgot password?'),
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
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+15551234567',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (value) {
              final phone = (value ?? '').trim();
              if (!phone.startsWith('+') || phone.length < 8) {
                return 'Use international format with + country code.';
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
              decoration: const InputDecoration(
                labelText: 'SMS code',
                prefixIcon: Icon(Icons.sms_outlined),
              ),
              validator: (value) {
                final code = (value ?? '').trim();
                if (code.length < 6) return 'Enter the 6-digit SMS code.';
                return null;
              },
              onFieldSubmitted: (_) => _confirmPhoneCode(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep this window open while the SMS arrives.',
              style: TextStyle(
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
            label: Text(hasSession ? 'Verify code' : 'Send SMS code'),
          ),
          if (hasSession) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isBusy ? null : _sendPhoneCode,
                    child: const Text('Resend code'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _isBusy
                        ? null
                        : () => setState(() {
                            _phoneSession = null;
                            _smsCode.clear();
                            _message = null;
                          }),
                    child: const Text('Change phone'),
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

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRect(child: child),
        ),
      ),
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
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9CD5FF).withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFF3F6)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF355872),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _AccountMode { email, phone }

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
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
    _ => error.message ?? 'Could not sign in. Please try again.',
  };
}
