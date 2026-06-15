part of travel_agent_app;

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({
    required this.authService,
    required this.onBack,
    super.key,
  });

  final AccountAuthService authService;
  final VoidCallback onBack;

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  late LinkedAuthProviders _providers = widget.authService.linkedProviders;
  String? _busyProvider;

  void _refreshProviders() {
    if (!mounted) return;
    setState(() => _providers = widget.authService.linkedProviders);
  }

  Future<void> _linkGoogle() async {
    if (_busyProvider != null || _providers.google) return;
    setState(() => _busyProvider = 'google.com');
    try {
      await widget.authService.linkGoogleToCurrentAccount();
      _refreshProviders();
      _showNotice('Google is now linked to this account.');
    } on FirebaseAuthException catch (error) {
      _showNotice(_profileAuthMessage(error), isError: true);
    } on AccountAuthException catch (error) {
      _showNotice(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  Future<void> _linkPhone() async {
    if (_busyProvider != null || _providers.phone) return;
    final linked = await showDialog<bool>(
      context: context,
      builder: (context) => _LinkPhoneDialog(authService: widget.authService),
    );
    if (linked == true) {
      _refreshProviders();
      _showNotice('Phone number linked successfully.');
    }
  }

  Future<void> _confirmUnlink({required String providerId}) async {
    if (_busyProvider != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Unlink sign-in method?')),
        content: Text(
          appText(
            context,
            'You will no longer be able to sign in with this method.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Unlink')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyProvider = providerId);
    try {
      await widget.authService.unlinkProvider(providerId);
      _refreshProviders();
      _showNotice('Sign-in method was unlinked.');
    } on FirebaseAuthException catch (error) {
      _showNotice(_profileAuthMessage(error), isError: true);
    } on AccountAuthException catch (error) {
      _showNotice(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  void _showNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            appText(context, message),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final canUnlink = _providers.count > 1;
    return ScreenScaffold(
      child: SafeArea(
        child: ListView(
          padding: _responsivePagePadding(context, top: 18, bottom: 32),
          children: [
            TopBar(title: 'Linked accounts', onBack: widget.onBack),
            const SizedBox(height: 24),
            Text(
              appText(
                context,
                'Manage the ways you can securely sign in to this account.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _LinkedProviderCard(
              icon: Icons.email_outlined,
              title: 'Email',
              linked: _providers.email,
              detail: _providers.emailAddress,
              busy: _busyProvider == 'password',
              canUnlink: canUnlink,
              onUnlink: () => _confirmUnlink(providerId: 'password'),
            ),
            _LinkedProviderCard(
              icon: Icons.g_mobiledata_rounded,
              title: 'Google',
              linked: _providers.google,
              detail: _providers.googleEmail,
              busy: _busyProvider == 'google.com',
              canUnlink: canUnlink,
              onLink: _linkGoogle,
              onUnlink: () => _confirmUnlink(providerId: 'google.com'),
            ),
            _LinkedProviderCard(
              icon: Icons.phone_iphone_rounded,
              title: 'Phone number',
              linked: _providers.phone,
              detail: _providers.phoneNumber,
              busy: _busyProvider == 'phone',
              canUnlink: canUnlink,
              onLink: widget.authService.supportsPhoneSignIn
                  ? _linkPhone
                  : null,
              onUnlink: () => _confirmUnlink(providerId: 'phone'),
            ),
            if (!canUnlink) ...[
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  'Link another sign-in method before unlinking your current one.',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkedProviderCard extends StatelessWidget {
  const _LinkedProviderCard({
    required this.icon,
    required this.title,
    required this.linked,
    required this.busy,
    required this.canUnlink,
    this.detail,
    this.onLink,
    this.onUnlink,
  });

  final IconData icon;
  final String title;
  final bool linked;
  final bool busy;
  final bool canUnlink;
  final String? detail;
  final VoidCallback? onLink;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cleanDetail = detail?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final information = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        appText(context, title),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: linked
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          appText(context, linked ? 'Linked' : 'Not linked'),
                          style: TextStyle(
                            color: linked
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (linked &&
                    cleanDetail != null &&
                    cleanDetail.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    cleanDetail,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            );
            final action = busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : linked
                ? OutlinedButton(
                    onPressed: canUnlink ? onUnlink : null,
                    child: Text(appText(context, 'Unlink')),
                  )
                : FilledButton.tonal(
                    onPressed: onLink,
                    child: Text(appText(context, 'Link')),
                  );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(icon: icon, size: 44),
                      const SizedBox(width: 12),
                      Expanded(child: information),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                IconBadge(icon: icon, size: 44),
                const SizedBox(width: 12),
                Expanded(child: information),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
