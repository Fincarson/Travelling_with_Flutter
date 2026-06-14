part of travel_agent_app;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.trips,
    required this.activeTrip,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    required this.onAskAi,
    required this.onOpenMap,
    required this.onOpenInfo,
    required this.onOpenTranslate,
    required this.onOpenNotifications,
    super.key,
  });
  final UserProfile user;
  final List<Trip> trips;
  final Trip? activeTrip;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;
  final ValueChanged<String> onAskAi;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenTranslate;
  final VoidCallback onOpenNotifications;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _query = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final trip =
        widget.activeTrip ?? (widget.trips.isEmpty ? null : widget.trips.first);
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 24, bottom: 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelText(appText(context, 'Welcome Back')),
                    Text(
                      '${widget.user.name.isEmpty ? 'Explorer' : widget.user.name}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IconButton.filled(
                        tooltip: appText(context, 'Notifications'),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: widget.onOpenNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ),
                    if (widget.user.notificationsEnabled)
                      const Positioned(right: 10, top: 10, child: Dot()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SearchBox(
            controller: _query,
            hint: "Ask AI: 'Best ramen in Kyoto?'",
            onSubmit: () {
              final query = _query.text.trim();
              if (query.isNotEmpty) widget.onAskAi(query);
            },
          ),
          const SizedBox(height: 10),
          if (widget.user.notificationsEnabled) const AlertRail(),
          const SizedBox(height: 28),
          if (trip == null) ...[
            _EmptyTripCard(onCreate: widget.onCreate),
          ] else ...[
            LabelText(appText(context, 'Current trip')),
            const SizedBox(height: 8),
            CurrentTripCard(
              trip: trip,
              onTap: () => widget.onOpenTrip(trip),
              onStart: trip.status == TripStatus.ongoing
                  ? null
                  : () => widget.onStartTrip(trip),
            ),
            const SizedBox(height: 22),
            ResponsiveActionWrap(
              children: [
                QuickAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Info',
                  onTap: widget.onOpenInfo,
                ),
                QuickAction(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  onTap: widget.onOpenMap,
                ),
                QuickAction(
                  icon: Icons.translate_rounded,
                  label: 'Translate',
                  onTap: widget.onOpenTranslate,
                ),
                QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI',
                  onTap: () => widget.onAskAi(_dailyTripPrompt(trip)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const SectionHeader(title: 'Ready for your next Adventure'),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => DestinationCard(
                destination: destinations[index],
                onTap: widget.onCreate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dailyTripPrompt(Trip trip) {
  if (trip.status != TripStatus.ongoing) {
    return 'Help me prepare to start my ${trip.destination} trip.';
  }
  final runtime = _tripRuntimePlan(trip);
  final next = runtime.nextItem;
  final base =
      'I am currently running my ${trip.destination} trip. Today is day ${runtime.currentDay} of ${runtime.totalDays}.';
  if (next == null) {
    return '$base Help me plan the rest of today based on my schedule, current time, and location if available.';
  }
  return '$base My next scheduled activity is "${next.activity}" at ${next.time}. Help me run today smoothly using current time and location if available.';
}

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.add_location_alt_rounded, size: 48),
          const SizedBox(height: 14),
          Text(
            appText(context, 'Start your trip'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            appText(context, 'Create a schedule to see your route here.'),
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Create schedule',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
