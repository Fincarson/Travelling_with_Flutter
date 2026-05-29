part of travel_agent_app;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.trips,
    required this.activeTrip,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onAskAi,
    required this.onOpenMap,
    required this.onOpenInfo,
    required this.onOpenTranslate,
    super.key,
  });
  final UserProfile user;
  final List<Trip> trips;
  final Trip? activeTrip;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<String> onAskAi;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenTranslate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _query = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final trip = widget.activeTrip ?? widget.trips.first;
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
              Stack(
                children: [
                  const IconSquare(icon: Icons.notifications_none_rounded),
                  if (widget.user.notificationsEnabled)
                    const Positioned(right: 10, top: 10, child: Dot()),
                ],
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
          LabelText(_profileText(widget.user.language, 'currentTrip')),
          const SizedBox(height: 8),
          CurrentTripCard(trip: trip, onTap: () => widget.onOpenTrip(trip)),
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
                onTap: () => widget.onAskAi('Plan my next Kyoto stop.'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Ready for your next Adventure',
            action: 'Create',
            onTap: widget.onCreate,
          ),
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
