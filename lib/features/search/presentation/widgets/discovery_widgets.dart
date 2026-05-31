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

class PlanningIdeaStrip extends StatelessWidget {
  const PlanningIdeaStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelText('AI planning cards'),
        SizedBox(height: 10),
        ResponsiveSplit(
          children: [
            InfoCard(
              icon: Icons.restaurant_rounded,
              title: 'Food',
              text: 'Market lunch',
            ),
            InfoCard(
              icon: Icons.directions_walk_rounded,
              title: 'Route',
              text: 'Less walking',
            ),
          ],
        ),
      ],
    );
  }
}
