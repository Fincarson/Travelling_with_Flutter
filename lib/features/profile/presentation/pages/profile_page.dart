part of travel_agent_app;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.account,
    required this.user,
    required this.onSave,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onOpenPerformance,
    required this.onOpenArchived,
    required this.archivedItemCount,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final Future<void> Function(UserProfile profile) onSave;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenArchived;
  final int archivedItemCount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.user.name,
  );

  var _isSigningOut = false;
  var _isDeleting = false;
  var _isSaving = false;
  late final Set<String> _interests = {...widget.user.interests};
  late var _language = widget.user.language;
  late var _notificationsEnabled = widget.user.notificationsEnabled;
  late var _themeMode = widget.user.themeMode;
  final _customInterest = TextEditingController();
  final _deviceContextService = AppDeviceContextService();
  var _locationAccessEnabled = true;
  var _isUpdatingLocationAccess = false;

  @override
  void dispose() {
    _name.dispose();
    _customInterest.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user == widget.user || _isSaving) return;
    _name.text = widget.user.name;
    _interests
      ..clear()
      ..addAll(widget.user.interests);
    _language = widget.user.language;
    _notificationsEnabled = widget.user.notificationsEnabled;
    _themeMode = widget.user.themeMode;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocationAccess());
  }

  Future<void> _loadLocationAccess() async {
    final enabled = await _deviceContextService.isLocationAccessEnabled();
    if (!mounted) return;
    setState(() => _locationAccessEnabled = enabled);
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await widget.onSignOut();
  }

  UserProfile _draftProfile() => UserProfile(
    name: _name.text,
    email: widget.account.email ?? widget.user.email,
    bio: widget.user.bio,
    photoUrl: widget.user.photoUrl,
    interests: _interests.toList(),
    language: _language,
    notificationsEnabled: _notificationsEnabled,
    themeMode: _themeMode,
    performanceSettings: widget.user.performanceSettings,
  );

  Future<void> _saveDraft({bool showFeedback = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_draftProfile());
      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context, 'Profile saved.'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save profile: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editInterests() async {
    final draft = {..._interests};
    String? interestError;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _responsiveHorizontalPadding(context),
                  0,
                  _responsiveHorizontalPadding(context),
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appText(context, 'Travel interests'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: appText(context, 'Cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in const [
                            'Culture',
                            'Food',
                            'Nature',
                            'Shopping',
                            'Museums',
                            'Hidden Gems',
                          ])
                            ChoiceChip(
                              label: Text(appText(context, tag)),
                              selected: draft.contains(tag),
                              selectedColor: _accent,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _primary,
                              ),
                              onSelected: (_) => setSheetState(
                                () => draft.contains(tag)
                                    ? draft.remove(tag)
                                    : draft.add(tag),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customInterest,
                              decoration: InputDecoration(
                                labelText: _profileText(
                                  _language,
                                  'customInterest',
                                ),
                                errorText: interestError,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addCustomInterest(
                                draft,
                                setSheetState,
                                (message) => interestError = message,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: _profileText(_language, 'customInterest'),
                            onPressed: () => _addCustomInterest(
                              draft,
                              setSheetState,
                              (message) => interestError = message,
                            ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: _profileText(_language, 'saveInterests'),
                        icon: Icons.check_rounded,
                        onPressed: () => Navigator.of(context).pop(draft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _interests
          ..clear()
          ..addAll(selected);
      });
      unawaited(_saveDraft());
    }
  }

  void _addCustomInterest(
    Set<String> draft,
    void Function(void Function()) setSheetState,
    ValueChanged<String?> setError,
  ) {
    final interest = _cleanInterest(_customInterest.text);
    setSheetState(() {
      if (interest == null || _isBlockedInterest(interest)) {
        setError(_profileText(_language, 'interestBlocked'));
        return;
      }
      setError(null);
      draft.add(interest);
      _customInterest.clear();
    });
  }

  void _pickLanguage() {
    _showSettingPicker<String>(
      title: _profileText(_language, 'language'),
      value: _language,
      options: const [
        'en',
        'id',
        'zh',
        'ja',
        'ko',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'th',
        'vi',
        'ar',
      ],
      labelFor: _languageLabel,
      onSelected: (value) {
        setState(() => _language = value);
        AppLocaleController.setProfileLanguage(value);
        unawaited(_saveDraft());
      },
    );
  }

  void _pickTheme() {
    _showSettingPicker<String>(
      title: _profileText(_language, 'theme'),
      value: _themeMode,
      options: const ['Light', 'Dark'],
      labelFor: (value) => appText(context, value),
      onSelected: (value) {
        setState(() => _themeMode = value);
        unawaited(_saveDraft());
      },
    );
  }

  Future<void> _showSettingPicker<T>({
    required String title,
    required T value,
    required List<T> options,
    required String Function(T value) labelFor,
    required ValueChanged<T> onSelected,
  }) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                onTap: () => Navigator.of(context).pop(option),
                title: Text(appText(context, labelFor(option))),
                trailing: option == value
                    ? const Icon(Icons.check_rounded, color: _primary)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_profileText(_language, 'deleteQuestion')),
        content: Text(_profileText(_language, 'deleteMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_profileText(_language, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_profileText(_language, 'delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onDeleteAccount();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('requires-recent-login')
          ? 'Please sign out, sign in again, then delete the account.'
          : 'Could not delete account. $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _setLocationAccess(bool enabled) async {
    if (_isUpdatingLocationAccess) return;
    setState(() => _isUpdatingLocationAccess = true);
    var nextValue = enabled;
    var message = enabled
        ? 'Location access enabled.'
        : 'Location access disabled for this app.';
    try {
      if (enabled) {
        final status = await _deviceContextService.enableLocationAccess();
        nextValue = status == AppLocationAccessStatus.granted;
        switch (status) {
          case AppLocationAccessStatus.granted:
            message = 'Location access enabled.';
          case AppLocationAccessStatus.denied:
            message = 'Location permission was denied.';
          case AppLocationAccessStatus.deniedForever:
            message =
                'Android will not show the popup again. App settings opened.';
          case AppLocationAccessStatus.serviceDisabled:
            message = 'Turn on device location services, then try again.';
        }
      } else {
        await _deviceContextService.setLocationAccessEnabled(false);
      }
      if (!mounted) return;
      setState(() => _locationAccessEnabled = nextValue);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appText(context, message))));
    } finally {
      if (mounted) setState(() => _isUpdatingLocationAccess = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 28, bottom: 112),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: _accent.withValues(alpha: .35),
              child: const Icon(
                Icons.person_rounded,
                size: 48,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              widget.account.contactLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: appText(context, 'Name')),
          ),
          const SizedBox(height: 18),
          SettingsTile(
            icon: Icons.language_rounded,
            title: _profileText(_language, 'language'),
            value: _languageLabel(_language),
            onTap: _pickLanguage,
          ),
          SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: _profileText(_language, 'notifications'),
            value: _notificationsEnabled
                ? _localizedSettingValue(_language, 'on')
                : _localizedSettingValue(_language, 'off'),
            onTap: () {
              setState(() => _notificationsEnabled = !_notificationsEnabled);
              unawaited(_saveDraft());
            },
          ),
          LocationAccessTile(
            enabled: _locationAccessEnabled,
            busy: _isUpdatingLocationAccess,
            onChanged: _setLocationAccess,
          ),
          SettingsTile(
            icon: Icons.palette_outlined,
            title: _profileText(_language, 'theme'),
            value: _themeMode,
            onTap: _pickTheme,
          ),
          SettingsTile(
            icon: Icons.speed_rounded,
            title: appText(context, 'Performance'),
            value: appText(
              context,
              PerformanceScope.settingsOf(context).preset.label,
            ),
            onTap: widget.onOpenPerformance,
          ),
          SettingsTile(
            icon: Icons.inventory_2_outlined,
            title: appText(context, 'Archived'),
            value: appText(context, '${widget.archivedItemCount} items'),
            onTap: widget.onOpenArchived,
          ),
          SettingsTile(
            icon: Icons.explore_outlined,
            title: _profileText(_language, 'interests'),
            value: _interests.isEmpty
                ? appText(context, 'None')
                : '${_interests.length}',
            onTap: _editInterests,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _profileText(_language, 'saveProfile'),
            icon: _isSaving ? Icons.hourglass_top_rounded : Icons.check_rounded,
            onPressed: _isSaving ? null : () => _saveDraft(showFeedback: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_profileText(_language, 'signOut').toUpperCase()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: _isDeleting ? null : _confirmDeleteAccount,
            icon: _isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(_profileText(_language, 'deleteAccount').toUpperCase()),
          ),
        ],
      ),
    );
  }
}
