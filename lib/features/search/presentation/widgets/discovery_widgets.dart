part of travel_agent_app;

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        prefixIcon: IconButton(
          icon: const Icon(Icons.auto_awesome_rounded, color: _accent),
          onPressed: onSubmit,
        ),
        hintText: appText(context, hint),
      ),
    );
  }
}

class AlertRail extends StatelessWidget {
  const AlertRail({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      (
        'Gate changed',
        'Flight JAL 402 now boards at Gate A7.',
        Icons.flight_rounded,
      ),
      ('Rain window', 'Kyoto rain expected after 2 PM.', Icons.cloud_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Important updates'),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => SizedBox(
                width: 188,
                child: GlassPanel(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      IconBadge(icon: alerts[index].$3, size: 38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              appText(context, alerts[index].$1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              appText(context, alerts[index].$2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    );
  }
}

class AnimatedGlobe extends StatefulWidget {
  const AnimatedGlobe({super.key});

  @override
  State<AnimatedGlobe> createState() => _AnimatedGlobeState();
}

class _AnimatedGlobeState extends State<AnimatedGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncController() {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final shouldAnimate =
        settings.animationsEnabled && settings.heavyVisualEffects;
    if (!shouldAnimate) {
      _controller.stop();
      return;
    }

    if (_controller.duration != settings.globeAnimationDuration) {
      _controller.duration = settings.globeAnimationDuration;
      if (_controller.isAnimating) _controller.repeat();
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.settingsOf(context);
    final shouldAnimate =
        settings.animationsEnabled && settings.heavyVisualEffects;
    return SizedBox(
      height: 180,
      child: shouldAnimate
          ? AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: _GlobePainter(_controller.value),
                child: const Center(
                  child: Icon(Icons.public_rounded, size: 76, color: _primary),
                ),
              ),
            )
          : const CustomPaint(
              painter: _GlobePainter(.18),
              child: Center(
                child: Icon(Icons.public_rounded, size: 76, color: _primary),
              ),
            ),
    );
  }
}

class PlanningGoal {
  const PlanningGoal({
    required this.id,
    required this.icon,
    required this.title,
    required this.text,
    required this.tag,
    required this.prompt,
  });

  final String id;
  final IconData icon;
  final String title;
  final String text;
  final String tag;
  final String prompt;
}

class PlanningIdeaStrip extends StatelessWidget {
  const PlanningIdeaStrip({
    required this.goals,
    required this.selectedGoalIds,
    required this.onToggle,
    super.key,
  });

  final List<PlanningGoal> goals;
  final Set<String> selectedGoalIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: LabelText('AI planning cards')),
            if (selectedGoalIds.isNotEmpty)
              SmallPill(label: '${selectedGoalIds.length} active'),
          ],
        ),
        const SizedBox(height: 10),
        ResponsiveSplit(
          children: goals
              .map(
                (goal) => PlanningGoalCard(
                  goal: goal,
                  selected: selectedGoalIds.contains(goal.id),
                  onTap: () => onToggle(goal.id),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class PlanningGoalCard extends StatelessWidget {
  const PlanningGoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PlanningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? _accent : const Color(0xFFEFF3F6),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconBadge(icon: goal.icon, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appText(context, goal.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appText(context, goal.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _secondary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: selected ? _primary : _secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
