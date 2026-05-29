part of travel_agent_app;

class CurrentTripCard extends StatelessWidget {
  const CurrentTripCard({required this.trip, required this.onTap, super.key});
  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ImageHero(
              image: trip.images.first,
              height: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'UP NEXT',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kyoto City Zoo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: .95,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '10:30 AM / Day 1 route',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ResponsiveSplit(
            children: [
              StatCard(
                title: 'Booking',
                value: trip.bookings.first.title,
                detail: '${trip.bookings.first.date} / confirmed',
              ),
              StatCard(
                title: 'Budget',
                value: '${trip.currency} ${trip.spent}',
                detail: 'of ${trip.currency} ${trip.budget}',
                trailing: Icons.add_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroTripCard extends StatelessWidget {
  const HeroTripCard({required this.trip, super.key});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ImageHero(
      image: trip.images.first,
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            trip.groupType.toUpperCase(),
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            trip.destination,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${trip.startDate} / ${trip.endDate}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageHero extends StatelessWidget {
  const ImageHero({
    required this.image,
    required this.child,
    this.height = 140,
    super.key,
  });
  final String image;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: _primary,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image,
            fit: BoxFit.cover,
            filterQuality: PerformanceScope.maybeSettingsOf(
              context,
            ).filterQuality,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary.withValues(alpha: .95),
                  _primary.withValues(alpha: .65),
                  _primary.withValues(alpha: .1),
                ],
              ),
            ),
          ),
          Positioned.fill(left: 18, right: 18, bottom: 18, child: child),
        ],
      ),
    );
  }
}

class DestinationCard extends StatelessWidget {
  const DestinationCard({
    required this.destination,
    required this.onTap,
    super.key,
  });
  final Destination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width < 360 ? 132.0 : 150.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.network(
                    destination.image,
                    fit: BoxFit.cover,
                    filterQuality: PerformanceScope.maybeSettingsOf(
                      context,
                    ).filterQuality,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  destination.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceSuggestionList extends StatelessWidget {
  const PlaceSuggestionList({
    required this.suggestions,
    required this.onSelect,
    super.key,
  });
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final suggestion in suggestions)
            InkWell(
              onTap: () => onSelect(suggestion),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: _secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggestion.formatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _secondary,
                              fontSize: 12,
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
        ],
      ),
    );
  }
}

class SelectedPlaceCard extends StatelessWidget {
  const SelectedPlaceCard({required this.place, super.key});
  final PlaceSuggestion place;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const IconBadge(icon: Icons.check_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  place.formatted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class TripListCard extends StatelessWidget {
  const TripListCard({
    required this.trip,
    required this.onTap,
    required this.onStart,
    super.key,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth < 340 ? 74.0 : 94.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.destination,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${trip.startDate} / ${trip.groupType}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SmallPill(label: trip.status.name),
                GestureDetector(
                  onTap: onStart,
                  child: const SmallPill(label: 'Start'),
                ),
              ],
            ),
          ],
        );

        return GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  trip.images.first,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  filterQuality: PerformanceScope.maybeSettingsOf(
                    context,
                  ).filterQuality,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: content),
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ItineraryTile extends StatelessWidget {
  const ItineraryTile({required this.item, super.key});
  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: item.type, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _secondary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    item.activity,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                item.cost == 0 ? 'Free' : '\$${item.cost}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingTile extends StatelessWidget {
  const BookingTile({required this.booking, super.key});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: booking.icon, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${booking.date} / ${booking.reference}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Flexible(
              fit: FlexFit.loose,
              child: SmallPill(label: 'Confirmed'),
            ),
          ],
        ),
      ),
    );
  }
}
