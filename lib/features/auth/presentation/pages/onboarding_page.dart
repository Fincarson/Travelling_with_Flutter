part of travel_agent_app;

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
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    const tags = [
      'Culture',
      'Food',
      'Nature',
      'Shopping',
      'Museums',
      'Hidden Gems',
    ];
    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 28, bottom: 28),
        children: [
          const IconBadge(icon: Icons.travel_explore_rounded, size: 64),
          const SizedBox(height: 24),
          Text(
            appText(context, 'Pick your travel style'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            appText(
              context,
              'Choose the things you usually look for so routes, packing lists, and budgets start closer to your taste.',
            ),
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          const LabelText('Travel interests'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                ChoiceChip(
                  label: Text(appText(context, tag)),
                  selected: _selected.contains(tag),
                  onSelected: (_) => setState(
                    () => _selected.contains(tag)
                        ? _selected.remove(tag)
                        : _selected.add(tag),
                  ),
                  selectedColor: _accent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Start exploring',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => widget.onComplete(
              UserProfile(
                name: widget.account.name,
                email: widget.account.email ?? '',
                photoUrl: widget.account.photoUrl,
                interests: _selected.toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
