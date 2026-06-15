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

class TripListCard extends StatefulWidget {
  const TripListCard({
    required this.trip,
    required this.onTap,
    required this.onStart,
    required this.onDelete,
    super.key,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  State<TripListCard> createState() => _TripListCardState();
}

class _TripListCardState extends State<TripListCard> {
  static const _deleteRevealWidth = 92.0;
  double _dragOffset = 0;

  void _closeActions() {
    if (_dragOffset == 0) return;
    setState(() => _dragOffset = 0);
  }

  void _deleteTrip() {
    _closeActions();
    widget.onDelete();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta == null || delta == 0) return;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(
        -_deleteRevealWidth,
        _deleteRevealWidth,
      );
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReveal =
        _dragOffset.abs() > _deleteRevealWidth * .35 || velocity.abs() > 420;
    setState(() {
      if (!shouldReveal) {
        _dragOffset = 0;
      } else if (_dragOffset == 0) {
        _dragOffset = velocity.isNegative
            ? -_deleteRevealWidth
            : _deleteRevealWidth;
      } else {
        _dragOffset = _dragOffset.isNegative
            ? -_deleteRevealWidth
            : _deleteRevealWidth;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.settingsOf(context);
    final animationDuration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth < 340 ? 74.0 : 94.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.trip.destination,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.trip.startDate} / ${_travelerCountLabel(widget.trip.numOfTravelers)}',
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
                SmallPill(label: widget.trip.status.name),
                if (widget.trip.status != TripStatus.ongoing)
                  GestureDetector(
                    onTap: widget.onStart,
                    child: const SmallPill(label: 'Start'),
                  ),
              ],
            ),
          ],
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: _TripDeleteRevealBackground(
                  alignment: _dragOffset >= 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  onDelete: _deleteTrip,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(_dragOffset, 0, 0),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _dragOffset == 0
                              ? widget.onTap
                              : _closeActions,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 36),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    widget.trip.images.first,
                                    width: imageSize,
                                    height: imageSize,
                                    fit: BoxFit.cover,
                                    filterQuality:
                                        PerformanceScope.maybeSettingsOf(
                                          context,
                                        ).filterQuality,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: content),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: PopupMenuButton<_TripCardMenuAction>(
                            tooltip: appText(context, 'Trip options'),
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (action) {
                              switch (action) {
                                case _TripCardMenuAction.delete:
                                  _deleteTrip();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _TripCardMenuAction.delete,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFE5484D),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(appText(context, 'Delete trip')),
                                  ],
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
            ],
          ),
        );
      },
    );
  }
}

enum _TripCardMenuAction { delete }

class _TripDeleteRevealBackground extends StatelessWidget {
  const _TripDeleteRevealBackground({
    required this.alignment,
    required this.onDelete,
  });

  final Alignment alignment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE5484D),
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: _TripListCardState._deleteRevealWidth,
          height: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDelete,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_rounded, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    appText(context, 'Delete'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
