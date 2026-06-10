part of travel_agent_app;

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    required this.trips,
    required this.onBack,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    required this.onDeleteTrip,
    super.key,
  });
  final List<Trip> trips;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;
  final ValueChanged<Trip> onDeleteTrip;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 18, bottom: 112),
        children: [
          TopBar(
            title: 'Trips',
            onBack: onBack,
            action: Icons.add_rounded,
            onAction: onCreate,
          ),
          const SizedBox(height: 18),
          if (trips.isEmpty)
            GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(icon: Icons.travel_explore_rounded, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    appText(context, 'No trips yet'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appText(context, 'Create a trip to see it here.'),
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Create trip',
                    icon: Icons.add_rounded,
                    onPressed: onCreate,
                  ),
                ],
              ),
            )
          else
            for (final trip in trips)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TripListCard(
                  trip: trip,
                  onTap: () => onOpenTrip(trip),
                  onStart: () => onStartTrip(trip),
                  onDelete: () => onDeleteTrip(trip),
                ),
              ),
        ],
      ),
    );
  }
}
