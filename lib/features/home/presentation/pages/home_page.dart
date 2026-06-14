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
                    LabelText(_profileText(widget.user.language, 'welcome')),
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
                          backgroundColor: Colors.white,
                          foregroundColor: _primary,
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
          AlertRail(trip: trip),
          const SizedBox(height: 28),
          if (trip == null) ...[
            _EmptyTripCard(onCreate: widget.onCreate),
          ] else ...[
            LabelText(_profileText(widget.user.language, 'currentTrip')),
            const SizedBox(height: 8),
            CurrentTripCard(
              trip: trip,
              onTap: () => widget.onOpenTrip(trip),
              onStart: trip.status == TripStatus.ongoing
                  ? null
                  : () => widget.onStartTrip(trip),
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

class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet({
    required this.notificationsEnabled,
    required this.trip,
    required this.upcomingTripCount,
    required this.onEnableNotifications,
    required this.onOpenTrip,
  });

  final bool notificationsEnabled;
  final Trip? trip;
  final int upcomingTripCount;
  final VoidCallback onEnableNotifications;
  final VoidCallback? onOpenTrip;

  @override
  Widget build(BuildContext context) {
    final updates = [
      ..._generalAgentFallbackUpdates(),
      if (trip != null) ..._dailyAgentUpdates(trip!),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const IconBadge(
                      icon: Icons.notifications_active_rounded,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LabelText('Notification center'),
                          const SizedBox(height: 3),
                          Text(
                            notificationsEnabled
                                ? 'Daily agent notifications are ready.'
                                : 'Notifications are off for this browser.',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
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
                    SmallPill(
                      label: notificationsEnabled ? 'Enabled' : 'Needs setup',
                    ),
                    SmallPill(label: '$upcomingTripCount active/upcoming'),
                    if (trip != null) SmallPill(label: trip!.destination),
                  ],
                ),
                const SizedBox(height: 16),
                for (final update in updates.take(4)) ...[
                  _NotificationUpdateTile(update: update),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenTrip,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(appText(context, 'Open trip')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onEnableNotifications,
                        icon: Icon(
                          notificationsEnabled
                              ? Icons.sync_rounded
                              : Icons.notifications_active_rounded,
                          size: 18,
                        ),
                        label: Text(
                          appText(
                            context,
                            notificationsEnabled ? 'Refresh' : 'Enable',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationUpdateTile extends StatelessWidget {
  const _NotificationUpdateTile({required this.update});

  final _DailyAgentUpdate update;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconBadge(icon: update.icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, update.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, update.detail),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
