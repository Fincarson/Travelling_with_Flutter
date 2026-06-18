part of travel_agent_app;

const _appVersion = '1.0.0';

// Placeholder legal copy. Replace with finalized text before release.
const _termsOfServiceParagraphs = <String>[
  'These Terms of Service are a draft and provided for testing purposes only. They are not legal advice and should be replaced before public release.',
  'By using Travelling with Flutter you agree to use the app for personal trip planning. AI-generated itineraries, prices, transport options, and travel requirements are suggestions only and may be inaccurate.',
  'Always confirm visas, entry rules, bookings, and prices with official sources before you travel. We are not responsible for decisions made based on app content.',
  'You are responsible for the accuracy of information you enter, for any content you share in group chats, and for keeping your account credentials secure.',
  'Accounts or content may be limited or removed if the app is used unlawfully or to harm others.',
  'The service is provided "as is" without warranties. We may update these terms; continued use means you accept the changes.',
];

const _privacyPolicyParagraphs = <String>[
  'This Privacy Policy is a draft for testing and will be replaced with a finalized policy before release.',
  'We store the account information you provide (such as name, email, and sign-in method) and the trips, budgets, checklists, favorites, and chat content you create, so the app can sync them across your devices.',
  'If you enable location access, your approximate location is used only to improve trip and currency suggestions. You can turn this off in Settings at any time.',
  'Trip data you generate may be sent to AI and mapping services to build itineraries, translations, and recommendations. Only the data needed for the request is shared.',
  'Your data is stored using Firebase. You can delete your account and associated data from Settings, which removes your profile and saved trips.',
  'We do not sell your personal data. For questions about your data, contact the app maintainer.',
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.account,
    required this.user,
    required this.authService,
    required this.onSave,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onOpenLinkedAccounts,
    required this.onOpenPerformance,
    required this.onOpenArchived,
    required this.archivedItemCount,
    required this.onBack,
    required this.onShowTutorial,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final AccountAuthService authService;
  final Future<void> Function(UserProfile profile) onSave;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final VoidCallback onOpenLinkedAccounts;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenArchived;
  final int archivedItemCount;
  final VoidCallback onBack;
  final VoidCallback onShowTutorial;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.user.name,
  );
  final _nameFocusNode = FocusNode();
  final _profilePhotoService = ProfilePhotoService();

  var _isSigningOut = false;
  var _isDeleting = false;
  var _isSaving = false;
  var _isEditingName = false;
  var _isUploadingPhoto = false;
  late var _savedName = widget.user.name;
  late var _photoUrl = widget.user.photoUrl?.trim().isNotEmpty == true
      ? widget.user.photoUrl
      : widget.account.photoUrl;
  late final Set<String> _interests = {...widget.user.interests};
  late var _language = widget.user.language;
  late var _notificationsEnabled = widget.user.notificationsEnabled;
  late var _displayCurrencyCode = widget.user.displayCurrencyCode;
  late var _currencyUpdateMode = widget.user.currencyUpdateMode;
  late var _themeMode = widget.user.themeMode;
  final _customInterest = TextEditingController();
  final _deviceContextService = AppDeviceContextService();
  var _locationAccessEnabled = true;
  var _isUpdatingLocationAccess = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFocusNode.dispose();
    _customInterest.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user == widget.user || _isSaving) return;
    _savedName = widget.user.name;
    if (!_isEditingName) _name.text = _savedName;
    _photoUrl = widget.user.photoUrl?.trim().isNotEmpty == true
        ? widget.user.photoUrl
        : widget.account.photoUrl;
    _interests
      ..clear()
      ..addAll(widget.user.interests);
    _language = widget.user.language;
    _notificationsEnabled = widget.user.notificationsEnabled;
    _displayCurrencyCode = widget.user.displayCurrencyCode;
    _currencyUpdateMode = widget.user.currencyUpdateMode;
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
    try {
      await widget.onSignOut();
    } catch (error) {
      if (!mounted) return;
      _showAccountNotice('Could not sign out. $error', isError: true);
      setState(() => _isSigningOut = false);
    }
  }

  void _showAccountNotice(String message, {bool isError = false}) {
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
          backgroundColor: isError ? Colors.red.shade700 : _primary,
        ),
      );
  }

  UserProfile _draftProfile({String? name, String? photoUrl}) => UserProfile(
    name: name ?? _savedName,
    email: widget.account.email ?? widget.user.email,
    bio: widget.user.bio,
    photoUrl: photoUrl ?? _photoUrl,
    interests: _interests.toList(),
    language: _language,
    notificationsEnabled: _notificationsEnabled,
    displayCurrencyCode: _displayCurrencyCode,
    currencyUpdateMode: _currencyUpdateMode,
    themeMode: _themeMode,
    currencySettingsVersion: 1,
    ageRange: widget.user.ageRange,
    travelPace: widget.user.travelPace,
    termsAcceptedVersion: widget.user.termsAcceptedVersion,
    termsAcceptedAt: widget.user.termsAcceptedAt,
    performanceSettings: widget.user.performanceSettings,
  );

  Future<void> _pickDisplayCurrency() async {
    final exchange = CurrencyScope.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CurrencyPickerSheet(
        currencies: exchange.currencies,
        selectedCode: _displayCurrencyCode,
      ),
    );
    if (selected == null || selected == _displayCurrencyCode || !mounted) {
      return;
    }
    setState(() => _displayCurrencyCode = selected);
    await _saveDraft();
  }

  Future<void> _pickCurrencyUpdateMode() async {
    final selected = await showModalBottomSheet<CurrencyUpdateMode>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _responsiveHorizontalPadding(sheetContext),
                vertical: 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    appText(sheetContext, 'Currency updates'),
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appText(
                      sheetContext,
                      'Automatic checks your country when the app opens and asks before changing currency. Manual only changes currency from Settings.',
                    ),
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    leading: const Icon(Icons.travel_explore_rounded),
                    title: Text(appText(sheetContext, 'Automatic')),
                    subtitle: Text(
                      appText(
                        sheetContext,
                        'Detect location changes and ask before switching.',
                      ),
                    ),
                    trailing:
                        _currencyUpdateMode == CurrencyUpdateMode.automatic
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: _primary,
                          )
                        : null,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(CurrencyUpdateMode.automatic),
                  ),
                  ListTile(
                    leading: const Icon(Icons.touch_app_rounded),
                    title: Text(appText(sheetContext, 'Manual')),
                    subtitle: Text(
                      appText(
                        sheetContext,
                        'Never check location for currency changes.',
                      ),
                    ),
                    trailing: _currencyUpdateMode == CurrencyUpdateMode.manual
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: _primary,
                          )
                        : null,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(CurrencyUpdateMode.manual),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected == null || selected == _currencyUpdateMode || !mounted) {
      return;
    }
    setState(() => _currencyUpdateMode = selected);
    await _saveDraft();
  }

  Future<bool> _saveDraft({
    String? name,
    String? photoUrl,
    bool showFeedback = false,
  }) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_draftProfile(name: name, photoUrl: photoUrl));
      if (!mounted) return false;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context, 'Profile saved.'))),
        );
      }
      return true;
    } catch (error, stackTrace) {
      if (mounted) {
        await showUnexpectedErrorDialog(context, error, stackTrace);
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _beginNameEdit() {
    if (_isEditingName || _isSaving) return;
    setState(() => _isEditingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocusNode.requestFocus();
      _name.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _name.text.length,
      );
    });
  }

  void _cancelNameEdit() {
    _name.text = _savedName;
    _nameFocusNode.unfocus();
    setState(() => _isEditingName = false);
  }

  Future<void> _confirmNameEdit() async {
    if (!_isEditingName || _isSaving) return;
    final candidate = _name.text.trim();
    if (candidate.isEmpty) {
      _showAccountNotice('Display name cannot be empty.', isError: true);
      return;
    }
    if (candidate == _savedName) {
      _cancelNameEdit();
      return;
    }

    final saved = await _saveDraft(name: candidate);
    if (!mounted || !saved) return;
    setState(() {
      _savedName = candidate;
      _name.text = candidate;
      _isEditingName = false;
    });
    _nameFocusNode.unfocus();
    _showAccountNotice('Display name updated.');
  }

  Future<void> _pickProfilePhoto() async {
    if (_isUploadingPhoto) return;
    ProfilePhotoSource? source;
    if (_profilePhotoService.cameraAvailable) {
      source = await showModalBottomSheet<ProfilePhotoSource>(
        context: context,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    appText(sheetContext, 'Change profile photo'),
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_rounded),
                    title: Text(appText(sheetContext, 'Take a photo')),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(ProfilePhotoSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_rounded),
                    title: Text(appText(sheetContext, 'Choose from gallery')),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(ProfilePhotoSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      source = ProfilePhotoSource.gallery;
    }
    if (source == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final uploadedUrl = await _profilePhotoService.pickAndUpload(
        userId: widget.account.uid,
        source: source,
        imageQuality: PerformanceScope.settingsOf(context).imageQuality,
      );
      if (uploadedUrl == null || !mounted) return;
      final saved = await _saveDraft(photoUrl: uploadedUrl);
      if (!mounted || !saved) return;
      setState(() => _photoUrl = uploadedUrl);
      _showAccountNotice('Profile photo updated.');
    } catch (error) {
      if (mounted) {
        _showAccountNotice(
          'Could not update profile photo: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
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
                                labelText: appText(
                                  context,
                                  'Add custom interest',
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
                            tooltip: appText(context, 'Add custom interest'),
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
                        label: appText(context, 'Save interests'),
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
        setError(appText(context, 'That interest is not allowed.'));
        return;
      }
      setError(null);
      draft.add(interest);
      _customInterest.clear();
    });
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _LanguagePickerSheet(selectedCode: _language),
    );
    if (selected == null || selected.code == _language || !mounted) return;

    final previous = _language;
    setState(() => _language = selected.code);
    final saved = await _saveDraft();
    if (!mounted) return;
    if (!saved) {
      setState(() => _language = previous);
      return;
    }
    await AppLocaleController.saveLanguageForRestart(selected.code);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.language_rounded,
              color: Theme.of(dialogContext).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appText(
                  dialogContext,
                  'Please restart the app to apply the selected language.',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => AppRestartScope.restart(dialogContext),
            child: Text(appText(dialogContext, 'OK')),
          ),
        ],
      ),
    );
  }

  void _showLegalDocument(String title, List<String> paragraphs) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .85,
          maxChildSize: .95,
          minChildSize: .5,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: paragraphs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => Text(
                      appText(context, paragraphs[index]),
                      style: TextStyle(
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: index == 0
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutApp() {
    showAboutDialog(
      context: context,
      applicationName: appText(context, 'Travelling with Flutter'),
      applicationVersion: 'v$_appVersion',
      applicationIcon: const Icon(Icons.flight_takeoff_rounded, size: 40),
      children: [
        Text(
          appText(
            context,
            'A travel planning companion for itineraries, budgets, packing lists, and group trips.',
          ),
        ),
      ],
    );
  }

  void _pickTheme() {
    _showSettingPicker<String>(
      title: appText(context, 'Theme'),
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
        title: Text(appText(context, 'Delete account?')),
        content: Text(
          appText(
            context,
            'This deletes your sign-in account, profile, and saved trips. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Delete')),
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
      child: ListView(
        padding: _responsivePagePadding(context, top: 18, bottom: 40),
        children: [
          TopBar(title: 'Settings', onBack: widget.onBack),
          const SizedBox(height: 22),
          _SettingsSection(
            title: 'Account',
            description:
                'Profile identity, sign-in methods, and account access.',
            children: [
              _ProfilePhotoEditor(
                photoUrl: _photoUrl,
                displayName: _savedName,
                isUploading: _isUploadingPhoto,
                onTap: _pickProfilePhoto,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                focusNode: _nameFocusNode,
                readOnly: !_isEditingName,
                textInputAction: TextInputAction.done,
                onTap: _beginNameEdit,
                onSubmitted: (_) => _confirmNameEdit(),
                decoration: InputDecoration(
                  labelText: appText(context, 'Display name'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  suffixIcon: _isEditingName
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: appText(context, 'Cancel'),
                              onPressed: _isSaving ? null : _cancelNameEdit,
                              icon: const Icon(Icons.close_rounded),
                            ),
                            IconButton(
                              tooltip: appText(context, 'Save'),
                              onPressed: _isSaving ? null : _confirmNameEdit,
                              icon: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                            ),
                          ],
                        )
                      : IconButton(
                          tooltip: appText(context, 'Edit display name'),
                          onPressed: _beginNameEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SettingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Linked accounts',
                value: switch (widget.authService.linkedProviders.count) {
                  1 => '1 linked account',
                  2 => '2 linked accounts',
                  _ => '3 linked accounts',
                },
                onTap: widget.onOpenLinkedAccounts,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'General',
            description: 'Language, notifications, and device permissions.',
            children: [
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                value: _languageLabel(_language),
                onTap: _pickLanguage,
              ),
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                value: _notificationsEnabled ? 'On' : 'Off',
                onTap: () {
                  setState(
                    () => _notificationsEnabled = !_notificationsEnabled,
                  );
                  unawaited(_saveDraft());
                },
              ),
              LocationAccessTile(
                enabled: _locationAccessEnabled,
                busy: _isUpdatingLocationAccess,
                onChanged: _setLocationAccess,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Travel preferences',
            description:
                'Currency behavior and the interests used for trip planning.',
            children: [
              SettingsTile(
                icon: Icons.currency_exchange_rounded,
                title: appText(context, 'Display currency'),
                value: _displayCurrencyCode,
                onTap: _pickDisplayCurrency,
              ),
              SettingsTile(
                icon: Icons.travel_explore_rounded,
                title: appText(context, 'Currency updates'),
                value: appText(
                  context,
                  _currencyUpdateMode == CurrencyUpdateMode.automatic
                      ? 'Automatic'
                      : 'Manual',
                ),
                onTap: _pickCurrencyUpdateMode,
              ),
              SettingsTile(
                icon: Icons.explore_outlined,
                title: 'Travel interests',
                value: _interests.isEmpty
                    ? appText(context, 'None')
                    : '${_interests.length}',
                onTap: _editInterests,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Appearance & performance',
            description:
                'Theme, animation, image quality, and battery behavior.',
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                value: appText(context, _themeMode),
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
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Data',
            description: 'Review content that is no longer active.',
            children: [
              SettingsTile(
                icon: Icons.inventory_2_outlined,
                title: appText(context, 'Archived'),
                value: appText(context, '${widget.archivedItemCount} items'),
                onTap: widget.onOpenArchived,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Help',
            description: 'Replay the walkthrough of the main features.',
            children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: appText(context, 'Tutorial'),
                value: '',
                onTap: widget.onShowTutorial,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Legal',
            description: 'Terms, privacy, and app information.',
            children: [
              SettingsTile(
                icon: Icons.description_outlined,
                title: appText(context, 'Terms of Service'),
                value: '',
                onTap: () => _showLegalDocument(
                  appText(context, 'Terms of Service'),
                  _termsOfServiceParagraphs,
                ),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: appText(context, 'Privacy Policy'),
                value: '',
                onTap: () => _showLegalDocument(
                  appText(context, 'Privacy Policy'),
                  _privacyPolicyParagraphs,
                ),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: appText(context, 'About'),
                value: 'v$_appVersion',
                onTap: _showAboutApp,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Account actions',
            description: 'Sign out of this device or permanently delete data.',
            children: [
              OutlinedButton.icon(
                onPressed: _isSigningOut ? null : _signOut,
                icon: _isSigningOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(appText(context, 'Sign out')),
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
                label: Text(appText(context, 'Delete account')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoEditor extends StatelessWidget {
  const _ProfilePhotoEditor({
    required this.photoUrl,
    required this.displayName,
    required this.isUploading,
    required this.onTap,
  });

  final String? photoUrl;
  final String displayName;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final performance = PerformanceScope.settingsOf(context);
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();

    return Align(
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: appText(context, 'Change profile photo'),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isUploading ? null : onTap,
            child: SizedBox.square(
              dimension: 116,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: photoUrl == null
                        ? Center(
                            child: Text(
                              initial,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          )
                        : Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            filterQuality: performance.filterQuality,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 36,
                      color: Colors.black.withValues(alpha: .58),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  if (isUploading)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: .48),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selectedCode,
  });

  final List<CurrencyInfo> currencies;
  final String selectedCode;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final currencies = widget.currencies
        .where((currency) {
          return normalized.isEmpty ||
              currency.code.toLowerCase().contains(normalized) ||
              currency.name.toLowerCase().contains(normalized) ||
              currency.symbol.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: .9,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(context),
              18,
              _responsiveHorizontalPadding(context),
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Column(
              children: [
                const _PickerHeader(title: 'Display currency'),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    labelText: appText(context, 'Search currency or code'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: currencies.isEmpty
                      ? Center(
                          child: Text(appText(context, 'No results found.')),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: currencies.length,
                          itemBuilder: (context, index) {
                            final currency = currencies[index];
                            final isSelected =
                                currency.code == widget.selectedCode;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              title: Text(
                                '${currency.code} - ${currency.name}',
                              ),
                              subtitle: currency.symbol == currency.code
                                  ? null
                                  : Text(currency.symbol),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                              onTap: () =>
                                  Navigator.of(context).pop(currency.code),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.selectedCode});

  final String selectedCode;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languages = appLanguages
        .where((language) => language.matches(_query))
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: .9,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(context),
              18,
              _responsiveHorizontalPadding(context),
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Column(
              children: [
                const _PickerHeader(title: 'Language'),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    labelText: appText(context, 'Search languages'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: languages.isEmpty
                      ? Center(
                          child: Text(appText(context, 'No results found.')),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: languages.length,
                          itemBuilder: (context, index) {
                            final language = languages[index];
                            final isSelected =
                                language.code ==
                                appLanguageForCode(widget.selectedCode).code;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              title: Text(language.nativeName),
                              subtitle: Text(
                                '${language.englishName} · ${language.code}',
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(language),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            appText(context, title),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          tooltip: appText(context, 'Close'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          appText(context, title),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          appText(context, description),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _LinkPhoneDialog extends StatefulWidget {
  const _LinkPhoneDialog({required this.authService});

  final AccountAuthService authService;

  @override
  State<_LinkPhoneDialog> createState() => _LinkPhoneDialogState();
}

class _LinkPhoneDialogState extends State<_LinkPhoneDialog> {
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();
  PhoneSignInSession? _session;
  var _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() {
        _error = 'Use international phone format, for example +15551234567.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final session = await widget.authService.sendPhoneLinkCode(phone);
      if (!mounted) return;
      if (session.autoVerified) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _session = session;
        _smsCode.clear();
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _profileAuthMessage(error));
    } on AccountAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the SMS code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmCode() async {
    final session = _session;
    if (session == null) return;
    if (_smsCode.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit SMS code.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await widget.authService.confirmPhoneLinkCode(
        session: session,
        smsCode: _smsCode.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _profileAuthMessage(error));
    } on AccountAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not verify the SMS code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _session != null;
    return AlertDialog(
      title: Text(appText(context, 'Link phone number')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appText(
                  context,
                  'You can use this number to sign in after it is verified.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                enabled: !_isBusy && !hasSession,
                autofocus: true,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: appText(context, 'Phone number'),
                  hintText: '+15551234567',
                  prefixIcon: const Icon(Icons.phone_iphone_rounded),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (hasSession) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _smsCode,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: appText(context, 'SMS code'),
                    prefixIcon: const Icon(Icons.sms_outlined),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _confirmCode(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Text(
                    appText(context, _error!),
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: Text(appText(context, 'Cancel')),
        ),
        if (hasSession)
          TextButton(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                    _session = null;
                    _smsCode.clear();
                    _error = null;
                  }),
            child: Text(appText(context, 'Change phone')),
          ),
        FilledButton(
          onPressed: _isBusy
              ? null
              : hasSession
              ? _confirmCode
              : _sendCode,
          child: _isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  appText(context, hasSession ? 'Verify code' : 'Send code'),
                ),
        ),
      ],
    );
  }
}

String _profileAuthMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'credential-already-in-use' =>
      'That sign-in method is already linked to another account.',
    'provider-already-linked' => 'That sign-in method is already linked.',
    'invalid-verification-code' => 'The SMS code is not correct.',
    'invalid-phone-number' => 'Enter a valid phone number with country code.',
    'quota-exceeded' => 'The SMS limit has been reached. Try again later.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'Check your connection and try again.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled in Firebase.',
    _ => error.message ?? 'Could not update the sign-in methods.',
  };
}
