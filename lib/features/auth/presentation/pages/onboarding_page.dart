part of travel_agent_app;

const _draftTermsVersion = 'draft-2026-06-15';

@immutable
class PreAccountOnboardingData {
  const PreAccountOnboardingData({
    required this.name,
    required this.interests,
    required this.travelPace,
    required this.termsVersion,
    this.ageRange,
  });

  final String name;
  final String? ageRange;
  final List<String> interests;
  final String travelPace;
  final String termsVersion;

  UserProfile applyToProfile(UserProfile profile) {
    return profile.copyWith(
      name: name.trim().isEmpty ? profile.name : name.trim(),
      interests: interests,
      ageRange: ageRange,
      travelPace: travelPace,
    );
  }
}

class PreAccountOnboardingFlow extends StatefulWidget {
  const PreAccountOnboardingFlow({
    required this.onComplete,
    required this.onBack,
    this.initialData,
    super.key,
  });

  final ValueChanged<PreAccountOnboardingData> onComplete;
  final VoidCallback onBack;
  final PreAccountOnboardingData? initialData;

  @override
  State<PreAccountOnboardingFlow> createState() =>
      _PreAccountOnboardingFlowState();
}

class _PreAccountOnboardingFlowState extends State<PreAccountOnboardingFlow> {
  static const _stepCount = 4;
  static const _ageRanges = [
    'Under 18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  ];
  static const _interestOptions = [
    ('Culture', Icons.account_balance_rounded),
    ('Food', Icons.restaurant_rounded),
    ('Nature', Icons.landscape_rounded),
    ('Shopping', Icons.shopping_bag_rounded),
    ('Museums', Icons.museum_rounded),
    ('Hidden Gems', Icons.explore_rounded),
    ('Nightlife', Icons.nightlife_rounded),
    ('Relaxation', Icons.spa_rounded),
  ];
  static const _paceOptions = ['Relaxed', 'Balanced', 'Fast'];

  late final TextEditingController _nameController;
  late final TextEditingController _customInterestController;
  final _selectedInterests = <String>{};
  var _step = 0;
  String? _ageRange;
  var _travelPace = 'Balanced';
  var _termsAccepted = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _customInterestController = TextEditingController();
    _ageRange = initial?.ageRange;
    _travelPace = initial?.travelPace ?? 'Balanced';
    _selectedInterests.addAll(initial?.interests ?? const []);
    _termsAccepted = initial?.termsVersion == _draftTermsVersion;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customInterestController.dispose();
    super.dispose();
  }

  void _addCustomInterest() {
    final interest = _customInterestController.text.trim();
    if (interest.isEmpty) return;
    final alreadySelected = _selectedInterests.any(
      (selected) => selected.toLowerCase() == interest.toLowerCase(),
    );
    if (alreadySelected) {
      setState(() => _validationMessage = 'That interest is already selected.');
      return;
    }
    setState(() {
      _selectedInterests.add(interest);
      _customInterestController.clear();
      _validationMessage = null;
    });
  }

  bool _isPresetInterest(String interest) {
    return _interestOptions.any((option) => option.$1 == interest);
  }

  void _goBack() {
    if (_step == 0) {
      widget.onBack();
      return;
    }
    setState(() {
      _step--;
      _validationMessage = null;
    });
  }

  void _continue() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Enter the name you want us to use.');
      return;
    }
    if (_step == 2 && _selectedInterests.isEmpty) {
      setState(
        () => _validationMessage = 'Choose at least one travel interest.',
      );
      return;
    }
    if (_step == 3) {
      if (!_termsAccepted) {
        setState(
          () => _validationMessage =
              'Agree to the draft terms before creating an account.',
        );
        return;
      }
      widget.onComplete(
        PreAccountOnboardingData(
          name: _nameController.text.trim(),
          ageRange: _ageRange,
          interests: _selectedInterests.toList()..sort(),
          travelPace: _travelPace,
          termsVersion: _draftTermsVersion,
        ),
      );
      return;
    }
    setState(() {
      _step++;
      _validationMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final duration = settings.animationsEnabled
        ? settings.transitionDuration
        : Duration.zero;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('pre-account-onboarding'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _responsiveHorizontalPadding(context),
                    18,
                    _responsiveHorizontalPadding(context),
                    10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('onboarding-back'),
                        tooltip: appText(context, 'Back'),
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OnboardingProgress(
                          currentStep: _step,
                          stepCount: _stepCount,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      key: ValueKey('onboarding-step-$_step'),
                      padding: EdgeInsets.fromLTRB(
                        _responsiveHorizontalPadding(context),
                        12,
                        _responsiveHorizontalPadding(context),
                        24,
                      ),
                      child: _buildStep(context),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _responsiveHorizontalPadding(context),
                    12,
                    _responsiveHorizontalPadding(context),
                    14,
                  ),
                  child: Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _goBack,
                            child: Text(appText(context, 'Back')),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const ValueKey('onboarding-continue'),
                          onPressed: _continue,
                          icon: Icon(
                            _step == _stepCount - 1
                                ? Icons.person_add_alt_1_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            appText(
                              context,
                              _step == _stepCount - 1
                                  ? 'Continue to account setup'
                                  : _step == 0
                                  ? 'Get started'
                                  : 'Continue',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      0 => const _OnboardingIntroduction(),
      1 => _buildPersonalDetails(context),
      2 => _buildPreferences(context),
      _ => _buildTerms(context),
    };
  }

  Widget _buildPersonalDetails(BuildContext context) {
    return _OnboardingSection(
      eyebrow: 'ABOUT YOU',
      title: 'Make every plan feel personal',
      description:
          'Tell us what to call you. Age range is optional and only helps us suggest a more suitable travel pace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('onboarding-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_validationMessage != null) {
                setState(() => _validationMessage = null);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'How should we address you?',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 22),
          const LabelText('Age range (optional)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final range in _ageRanges)
                ChoiceChip(
                  label: Text(range),
                  selected: _ageRange == range,
                  onSelected: (selected) {
                    setState(() => _ageRange = selected ? range : null);
                  },
                ),
            ],
          ),
          _buildValidationMessage(),
        ],
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    return _OnboardingSection(
      eyebrow: 'YOUR TRAVEL STYLE',
      title: 'What makes a trip worth taking?',
      description: 'Choose a few interests and your preferred pace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Travel interests'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _interestOptions)
                FilterChip(
                  avatar: Icon(option.$2, size: 17),
                  label: Text(option.$1),
                  selected: _selectedInterests.contains(option.$1),
                  onSelected: (_) {
                    setState(() {
                      if (!_selectedInterests.add(option.$1)) {
                        _selectedInterests.remove(option.$1);
                      }
                      _validationMessage = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('onboarding-custom-interest'),
            controller: _customInterestController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 30,
            onSubmitted: (_) => _addCustomInterest(),
            onChanged: (_) {
              if (_validationMessage != null) {
                setState(() => _validationMessage = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Add another interest',
              counterText: '',
              prefixIcon: const Icon(Icons.add_rounded),
              suffixIcon: IconButton(
                key: const ValueKey('onboarding-add-interest'),
                tooltip: 'Add interest',
                onPressed: _addCustomInterest,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (_selectedInterests.any(
            (interest) => !_isPresetInterest(interest),
          )) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in _selectedInterests.where(
                  (interest) => !_isPresetInterest(interest),
                ))
                  InputChip(
                    label: Text(interest),
                    onDeleted: () =>
                        setState(() => _selectedInterests.remove(interest)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          const LabelText('Preferred pace'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pace in _paceOptions)
                ChoiceChip(
                  label: Text(pace),
                  selected: _travelPace == pace,
                  onSelected: (_) => setState(() => _travelPace = pace),
                ),
            ],
          ),
          _buildValidationMessage(),
        ],
      ),
    );
  }

  Widget _buildTerms(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OnboardingSection(
      eyebrow: 'ONE LAST STEP',
      title: 'Clear expectations before takeoff',
      description:
          'These are draft project terms for the current app prototype. Replace them with reviewed legal terms before a public production release.',
      child: Column(
        children: [
          Material(
            key: const ValueKey('onboarding-terms-collapsed'),
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: const ExpansionTile(
              title: Text(
                'View draft terms and conditions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Version $_draftTermsVersion'),
              leading: Icon(Icons.gavel_rounded),
              childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [_DraftTermsContent()],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: _termsAccepted
                ? scheme.primary.withValues(alpha: .09)
                : scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: _termsAccepted ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: CheckboxListTile(
              key: const ValueKey('onboarding-terms-checkbox'),
              value: _termsAccepted,
              onChanged: (value) {
                setState(() {
                  _termsAccepted = value ?? false;
                  _validationMessage = null;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I agree to the draft terms and conditions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Your acceptance version and date will be saved with your account.',
              ),
            ),
          ),
          _buildValidationMessage(),
        ],
      ),
    );
  }

  Widget _buildValidationMessage() {
    final message = _validationMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _OnboardingStatusMessage(message: message),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({
    required this.currentStep,
    required this.stepCount,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < stepCount; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: PerformanceScope.maybeSettingsOf(
                context,
              ).transitionDuration,
              height: 5,
              decoration: BoxDecoration(
                color: index <= currentStep
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (index != stepCount - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _OnboardingIntroduction extends StatelessWidget {
  const _OnboardingIntroduction();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingSection(
      eyebrow: 'WELCOME ABOARD',
      title: 'Plan smarter. Travel faster.',
      description: 'Plan trips, keep details together, and get help as you go.',
      child: Center(child: _TravelIntroMark()),
    );
  }
}

class _TravelIntroMark extends StatelessWidget {
  const _TravelIntroMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = PerformanceScope.maybeSettingsOf(context);
    return Hero(
      tag: 'travel-plane-logo',
      createRectTween: (begin, end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      child: TweenAnimationBuilder<double>(
        key: const ValueKey('onboarding-plane-logo'),
        tween: Tween<double>(begin: settings.animationsEnabled ? 0 : 1, end: 1),
        duration: settings.animationsEnabled
            ? const Duration(milliseconds: 760)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          final scale = .28 + (.72 * Curves.easeOutBack.transform(progress));
          final verticalOffset =
              (1 - progress) * MediaQuery.sizeOf(context).height * .45;
          return Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .1),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary.withValues(alpha: .22)),
          ),
          child: Icon(Icons.flight_rounded, size: 52, color: scheme.primary),
        ),
      ),
    );
  }
}

class _OnboardingSection extends StatelessWidget {
  const _OnboardingSection({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText(context, eyebrow),
          style: TextStyle(
            color: scheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appText(context, title),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          appText(context, description),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _OnboardingStatusMessage extends StatelessWidget {
  const _OnboardingStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, message),
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftTermsContent extends StatelessWidget {
  const _DraftTermsContent();

  @override
  Widget build(BuildContext context) {
    const sections = [
      (
        '1. Prototype status',
        'This application is a student project and prototype. Features, availability, and stored data structures may change during development.',
      ),
      (
        '2. Account information',
        'You agree to provide accurate account information and keep access credentials secure. You are responsible for activity performed through your account.',
      ),
      (
        '3. Travel and AI information',
        'Routes, prices, schedules, entry requirements, safety notices, translations, and AI suggestions may be incomplete or outdated. Verify important details with official providers before acting.',
      ),
      (
        '4. Safety and emergencies',
        'The app is not an emergency service. Contact local authorities, emergency services, embassies, airlines, or qualified professionals when urgent or high-risk help is required.',
      ),
      (
        '5. User content',
        'You are responsible for trip details, messages, and files you upload. Do not upload unlawful content or information you do not have permission to share.',
      ),
      (
        '6. Acceptable use',
        'Do not misuse the service, interfere with other users, attempt unauthorized access, or use the app for illegal, harmful, or abusive activity.',
      ),
      (
        '7. Availability and liability',
        'The prototype is provided as available without guaranteed uptime or accuracy. To the extent allowed by law, the project team is not responsible for losses caused by reliance on prototype information.',
      ),
      (
        '8. Changes',
        'These draft terms may be replaced or updated. A production release should require acceptance of professionally reviewed terms and a separate privacy policy.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(section.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(section.$2, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.account,
    required this.onComplete,
    super.key,
  });

  final AuthenticatedAccount account;
  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return PreAccountOnboardingFlow(
      initialData: PreAccountOnboardingData(
        name: widget.account.name,
        interests: const [],
        travelPace: 'Balanced',
        termsVersion: '',
      ),
      onBack: () {},
      onComplete: (data) {
        widget.onComplete(
          UserProfile(
            name: data.name,
            email: widget.account.email ?? '',
            photoUrl: widget.account.photoUrl,
            interests: data.interests,
            ageRange: data.ageRange,
            travelPace: data.travelPace,
            termsAcceptedVersion: data.termsVersion,
            termsAcceptedAt: DateTime.now().toUtc(),
          ),
        );
      },
    );
  }
}
