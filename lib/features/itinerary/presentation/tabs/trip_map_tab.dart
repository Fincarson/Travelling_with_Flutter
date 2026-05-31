part of travel_agent_app;

class TripMapTab extends StatelessWidget {
  const TripMapTab({required this.trip, required this.onOpenMap, super.key});
  final Trip trip;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Route map'),
              const SizedBox(height: 8),
              Text(
                appText(context, trip.formattedAddress ?? trip.destination),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Open map',
                icon: Icons.map_rounded,
                onPressed: onOpenMap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in trip.items.take(6)) ScheduleTile(item: item),
      ],
    );
  }
}
