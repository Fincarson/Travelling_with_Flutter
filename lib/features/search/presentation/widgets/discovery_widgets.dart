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

class TravelGlobePreview extends StatelessWidget {
  const TravelGlobePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    if (kReleaseMode && kIsWasm && settings.heavyVisualEffects) {
      return const AnimatedGlobe();
    }
    return const SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _GlobePainter(.18),
        child: Center(
          child: Icon(Icons.public_rounded, size: 76, color: _primary),
        ),
      ),
    );
  }
}

class AnimatedGlobe extends StatefulWidget {
  const AnimatedGlobe({super.key});

  @override
  State<AnimatedGlobe> createState() => _AnimatedGlobeState();
}

class _AnimatedGlobeState extends State<AnimatedGlobe> {
  FlutterEarthGlobeController? _earthController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void dispose() {
    final earthController = _earthController;
    if (earthController?.isReady == true) {
      earthController!.dispose();
    } else {
      earthController?.onLoaded = null;
    }
    super.dispose();
  }

  void _syncController() {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final shouldAnimate =
        kReleaseMode &&
        kIsWasm &&
        settings.animationsEnabled &&
        settings.heavyVisualEffects;
    final earthController = _earthController;
    if (earthController != null) {
      if (!earthController.isReady) {
        earthController.isRotating = shouldAnimate;
      } else if (shouldAnimate) {
        earthController.startRotation(rotationSpeed: .04);
      } else {
        earthController.stopRotation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.settingsOf(context);
    final useEarthRenderer =
        kReleaseMode && kIsWasm && settings.heavyVisualEffects;
    final shouldAnimate = settings.animationsEnabled && useEarthRenderer;
    if (useEarthRenderer && _earthController == null) {
      _earthController = FlutterEarthGlobeController(
        surface: const AssetImage('assets/globe/earth_day.jpg'),
        nightSurface: const AssetImage('assets/globe/earth_night.jpg'),
        background: const AssetImage('assets/globe/stars.jpg'),
        rotationSpeed: .04,
        isRotating: shouldAnimate,
        zoom: .1,
        minZoom: -.6,
        maxZoom: 1.4,
        atmosphereOpacity: .42,
        zoomToMousePosition: true,
      );
      _earthController!.onLoaded = () {
        if (!mounted) return;
        final current = PerformanceScope.maybeSettingsOf(context);
        if (current.animationsEnabled && current.heavyVisualEffects) {
          _earthController?.startRotation(rotationSpeed: .04);
        }
      };
    }
    return SizedBox(
      height: 260,
      child: LayoutBuilder(
        builder: (context, constraints) => FlutterEarthGlobe(
          radius: math.min(122, constraints.maxWidth * .34),
          controller: _earthController!,
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
