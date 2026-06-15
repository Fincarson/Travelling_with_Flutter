part of travel_agent_app;

class CurrentTripCard extends StatelessWidget {
  const CurrentTripCard({
    required this.trip,
    required this.onTap,
    this.onStart,
    super.key,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final hasStarted = trip.status == TripStatus.ongoing;
    final runtime = _tripRuntimePlan(trip);
    final booking = trip.bookings.isEmpty ? null : trip.bookings.first;
    final image = trip.images.isEmpty
        ? destinations.first.image
        : trip.images.first;
    final eyebrow = hasStarted ? _runtimeEyebrow(runtime) : 'READY TO GO';
    final nextTitle = hasStarted
        ? _runtimeTitle(trip, runtime)
        : 'Start your trip';
    final nextDetail = hasStarted
        ? _runtimeDetail(trip, runtime)
        : '${trip.destination} / ${trip.startDate} to ${trip.endDate}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _primary,
        border: Border.all(color: Colors.white.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              image,
              fit: BoxFit.cover,
              filterQuality: PerformanceScope.maybeSettingsOf(
                context,
              ).filterQuality,
              errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _primary.withValues(alpha: .28),
                    _primary.withValues(alpha: .76),
                    _primary.withValues(alpha: .95),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return FittedBox(
                          alignment: Alignment.bottomLeft,
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appText(context, eyebrow),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  appText(context, nextTitle),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    height: .95,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  appText(context, nextDetail),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .75),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (hasStarted) ...[
                  _RuntimeDayStrip(runtime: runtime),
                  const SizedBox(height: 14),
                ],
                ResponsiveSplit(
                  children: [
                    _CurrentTripOverlayStat(
                      title: 'Booking',
                      value: booking?.title ?? 'TBD',
                      detail: booking == null
                          ? 'No bookings yet'
                          : '${booking.date} / confirmed',
                    ),
                    _CurrentTripOverlayStat(
                      title: 'Budget',
                      value: _displayMoney(context, trip.spent, trip.currency),
                      detail:
                          'of ${_displayMoney(context, trip.budget, trip.currency)}',
                      trailing: Icons.add_rounded,
                    ),
                  ],
                ),
                if (onStart != null) ...[
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Start your trip',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onStart!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTripOverlayStat extends StatelessWidget {
  const _CurrentTripOverlayStat({
    required this.title,
    required this.value,
    required this.detail,
    this.trailing,
  });

  final String title;
  final String value;
  final String detail;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabelText(title),
                const SizedBox(height: 4),
                Text(
                  appText(context, value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, detail),
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, color: _primary),
          ],
        ],
      ),
    );
  }
}

class _RuntimeDayStrip extends StatelessWidget {
  const _RuntimeDayStrip({required this.runtime});

  final _TripRuntimePlan runtime;

  @override
  Widget build(BuildContext context) {
    final next = runtime.nextItem;
    final nextStart = runtime.nextItemStartAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const IconBadge(icon: Icons.today_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabelText('Day ${runtime.currentDay} of ${runtime.totalDays}'),
                const SizedBox(height: 3),
                Text(
                  next == null
                      ? 'No more scheduled stops today'
                      : nextStart == null
                      ? next.activity
                      : '${_clockLabel(nextStart)} / ${next.activity}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
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

String _runtimeEyebrow(_TripRuntimePlan runtime) {
  return switch (runtime.phase) {
    _TripRuntimePhase.beforeStart => 'STARTING SOON',
    _TripRuntimePhase.afterTrip => 'TRIP WRAPPED',
    _ => 'UP NEXT',
  };
}

String _runtimeTitle(Trip trip, _TripRuntimePlan runtime) {
  final next = runtime.nextItem;
  if (runtime.phase == _TripRuntimePhase.beforeStart) {
    return 'Trip starts ${trip.startDate}';
  }
  if (runtime.phase == _TripRuntimePhase.afterTrip) return 'Trip complete';
  return next?.activity ?? 'Day ${runtime.currentDay} is open';
}

String _runtimeDetail(Trip trip, _TripRuntimePlan runtime) {
  final next = runtime.nextItem;
  if (runtime.phase == _TripRuntimePhase.beforeStart) {
    return '${trip.destination} / ${trip.startDate} to ${trip.endDate}';
  }
  if (runtime.phase == _TripRuntimePhase.afterTrip) {
    return '${trip.destination} / ${trip.startDate} to ${trip.endDate}';
  }
  if (next == null) return 'Day ${runtime.currentDay} / no more stops';
  return '${next.time} / Day ${next.day} route';
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
            _travelerCountLabel(trip.numOfTravelers).toUpperCase(),
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
    this.onStart,
    this.canDelete = true,
    this.favorite = false,
    this.onToggleFavorite,
    super.key,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final bool canDelete;
  final bool favorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = PerformanceScope.maybeSettingsOf(context);
    final fallbackImage = destinations.first.image;
    final images = trip.images
        .where((image) => image.trim().isNotEmpty)
        .toList();
    String imageAt(int index) =>
        images.isEmpty ? fallbackImage : images[index % images.length];
    final isPast = trip.status == TripStatus.past;
    final isOngoing = trip.status == TripStatus.ongoing;
    final actionLabel = onStart == null
        ? 'VIEW TRIP'
        : isPast
        ? 'VIEW TRIP'
        : isOngoing
        ? 'CONTINUE TRIP'
        : 'START TRIP';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Material(
          key: ValueKey('trip-card-${trip.id}'),
          color: scheme.surfaceContainerLowest,
          elevation: settings.heavyVisualEffects ? 4 : 0,
          shadowColor: Colors.black.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TripListAvatar(
                        image: imageAt(0),
                        size: compact ? 44 : 50,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: compact ? 18 : 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              trip.startDate == trip.endDate
                                  ? trip.startDate
                                  : '${trip.startDate} to ${trip.endDate}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (onToggleFavorite != null)
                        IconButton(
                          tooltip: favorite
                              ? 'Remove favorite trip'
                              : 'Favorite trip',
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB6D8F2).withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          appText(
                            context,
                            _travelerCountLabel(trip.numOfTravelers),
                          ).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: compact ? 112 : 150,
                    child: Row(
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageAt(index),
                                height: double.infinity,
                                fit: BoxFit.cover,
                                filterQuality: settings.filterQuality,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: scheme.primaryContainer,
                                  child: Icon(
                                    Icons.landscape_rounded,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (index != 2) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TripListStat(
                          value: _displayMoney(
                            context,
                            trip.spent,
                            trip.currency,
                          ),
                          label: 'SPENT',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TripListStat(
                          value: '${trip.items.length}',
                          label: 'PLACES',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TripListStat(
                          value: '${trip.bookings.length}',
                          label: 'BOOKINGS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isPast || isOngoing || onStart == null
                          ? onTap
                          : onStart,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF3D5A6C),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Swipe left or right to delete',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TripListAvatar extends StatelessWidget {
  const _TripListAvatar({required this.image, required this.size});

  final String image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: Image.network(
        image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: PerformanceScope.maybeSettingsOf(context).filterQuality,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: scheme.primaryContainer,
          child: SizedBox.square(
            dimension: size,
            child: Icon(Icons.flight_takeoff_rounded, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

class _TripListStat extends StatelessWidget {
  const _TripListStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.light
            ? const Color(0xFFF5F4EE)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    required this.item,
    required this.currency,
    this.onDelete,
    super.key,
  });
  final ScheduleItem item;
  final String currency;
  final VoidCallback? onDelete;

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
                    appText(context, item.activity),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            // Flexible(
            //   fit: FlexFit.loose,
            //   child: Text(
            //     item.cost == 0
            //         ? appText(context, 'Free')
            //         : _displayMoney(context, item.cost, currency),
            //     maxLines: 2,
            //     overflow: TextOverflow.ellipsis,
            //     textAlign: TextAlign.end,
            //     style: const TextStyle(fontWeight: FontWeight.w900),
            //   ),
            // ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: appText(context, 'Remove activity'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookingTile extends StatelessWidget {
  const BookingTile({required this.booking, required this.currency, super.key});
  final Booking booking;
  final String currency;

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
                    appText(context, booking.title),
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
            Flexible(
              fit: FlexFit.loose,
              child: booking.cost <= 0
                  ? const SmallPill(label: 'Confirmed')
                  : Text(
                      _displayMoney(context, booking.cost, currency),
                      maxLines: 2,
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
