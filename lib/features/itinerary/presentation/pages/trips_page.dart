part of travel_agent_app;

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    required this.trips,
    required this.onBack,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    super.key,
  });
  final List<Trip> trips;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;

  @override
  Widget build(BuildContext context) {
    final items = trips.isEmpty ? [mockKyotoTrip] : trips;
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
          for (final trip in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripListCard(
                trip: trip,
                onTap: () => onOpenTrip(trip),
                onStart: () => onStartTrip(trip),
              ),
            ),
        ],
      ),
    );
  }
}
