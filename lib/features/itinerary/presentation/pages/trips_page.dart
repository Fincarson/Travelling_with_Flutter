part of travel_agent_app;

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    required this.trips,
    required this.memories,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    required this.onDeleteTrip,
    super.key,
  });
  final List<Trip> trips;
  final List<TripMemory> memories;
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
          if (memories.isNotEmpty) ...[
            const SizedBox(height: 10),
            const LabelText('Trip memories'),
            const SizedBox(height: 10),
            for (final memory in memories)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TripMemoryCard(memory: memory),
              ),
          ],
        ],
      ),
    );
  }
}

class _TripMemoryCard extends StatelessWidget {
  const _TripMemoryCard({required this.memory});

  final TripMemory memory;

  @override
  Widget build(BuildContext context) {
    final image = memory.imageUrls.isEmpty
        ? destinations.first.image
        : memory.imageUrls.first;
    final dateLabel = memory.startDate == memory.endDate
        ? memory.startDate
        : '${memory.startDate} to ${memory.endDate}';
    final missedLabel = memory.missedStops.isEmpty
        ? 'No missed stops logged'
        : memory.missedStops.join(' / ');

    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              image,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              filterQuality: PerformanceScope.maybeSettingsOf(
                context,
              ).filterQuality,
              errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: _secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        memory.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memory.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallPill(
                      label:
                          '${_displayMoney(context, memory.actualSpend, memory.currency)} remembered',
                    ),
                    SmallPill(label: missedLabel),
                    for (final place in memory.favoritePlaces.take(2))
                      SmallPill(label: place),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
