part of travel_agent_app;

class TripOverviewTab extends StatelessWidget {
  const TripOverviewTab({required this.trip, required this.onSave, super.key});
  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: trip.budget,
            actual: trip.spent,
            items: trip.items,
            bookings: trip.bookings,
          )
        : trip.budgetCategories;
    final actual = categories.fold<int>(
      0,
      (total, item) => total + item.actual,
    );
    final runtime = _tripRuntimePlan(trip);
    final budgetInsight = _budgetGuardianInsight(trip, categories: categories);
    final repairs = _itineraryRepairSuggestions(trip);
    final previewItems = trip.status == TripStatus.ongoing
        ? runtime.todaysItems
        : trip.items.take(3).toList();

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        if (trip.status == TripStatus.ongoing) ...[
          _DailyAgentPanel(trip: trip, runtime: runtime),
          const SizedBox(height: 12),
        ],
        _RepairAgentPanel(
          suggestions: repairs,
          onApply: (suggestion) {
            onSave(_applyItineraryRepair(trip, suggestion.kind));
          },
        ),
        const SizedBox(height: 12),
        _BudgetGuardianPanel(trip: trip, insight: budgetInsight),
        const SizedBox(height: 12),
        _LocalContextAgentPanel(trip: trip),
        const SizedBox(height: 12),
        ResponsiveSplit(
          children: [
            StatCard(
              title: 'Dates',
              value: _dateKey(_travelAgentNow()),
              detail: '',
            ),
            StatCard(
              title: 'Budget',
              value: _displayMoney(context, actual, trip.currency),
              detail:
                  'of ${_displayMoney(context, trip.budget, trip.currency)}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Trip tags'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (trip.preferences.isEmpty
                            ? ['Culture', 'Food']
                            : trip.preferences)
                        .map((tag) => SmallPill(label: tag))
                        .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Bookings'),
        const SizedBox(height: 10),
        for (final booking in trip.bookings.take(2))
          BookingTile(booking: booking, currency: trip.currency),
        const SizedBox(height: 12),
        SectionHeader(
          title: trip.status == TripStatus.ongoing
              ? 'Today schedule'
              : 'First schedule stops',
        ),
        const SizedBox(height: 10),
        if (previewItems.isEmpty)
          GlassPanel(
            child: Text(
              appText(context, 'No activities yet'),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        for (final item in previewItems)
          ScheduleTile(item: item, currency: trip.currency),
      ],
    );
  }
}

class _BudgetGuardianPanel extends StatelessWidget {
  const _BudgetGuardianPanel({required this.trip, required this.insight});

  final Trip trip;
  final _BudgetGuardianInsight insight;

  @override
  Widget build(BuildContext context) {
    final accent = switch (insight.severity) {
      _BudgetGuardianSeverity.warning => const Color(0xFFE5484D),
      _BudgetGuardianSeverity.watch => const Color(0xFFE09F3E),
      _BudgetGuardianSeverity.calm => _primary,
    };
    final riskyCategories =
        insight.categories
            .where((item) => item.planned > 0 && item.actual > 0)
            .toList()
          ..sort(
            (a, b) => (b.actual / b.planned).compareTo(a.actual / a.planned),
          );

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: insight.icon, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelText('Budget guardian'),
                    const SizedBox(height: 8),
                    Text(
                      appText(context, insight.title),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appText(context, insight.detail),
                      style: const TextStyle(
                        color: _secondary,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GuardianProgressRow(
            label: 'Trip progress',
            percent: insight.tripProgressPercent,
            color: _secondary,
          ),
          const SizedBox(height: 8),
          _GuardianProgressRow(
            label: 'Budget used',
            percent: insight.spendPercent,
            color: accent,
          ),
          if (riskyCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in riskyCategories.take(3))
                  SmallPill(
                    label:
                        '${category.category} ${(category.actual / category.planned * 100).round()}%',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardianProgressRow extends StatelessWidget {
  const _GuardianProgressRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return Row(
      children: [
        SizedBox(
          width: 102,
          child: Text(
            appText(context, label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: .16),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '$percent%',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalContextAgentPanel extends StatefulWidget {
  const _LocalContextAgentPanel({required this.trip});

  final Trip trip;

  @override
  State<_LocalContextAgentPanel> createState() =>
      _LocalContextAgentPanelState();
}

class _LocalContextAgentPanelState extends State<_LocalContextAgentPanel> {
  final _deviceContextService = AppDeviceContextService();
  final _places = GeoapifyPlacesService();
  late Future<_LocalContextAgentData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LocalContextAgentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      _future = _load();
    }
  }

  Future<_LocalContextAgentData> _load() async {
    final context = await _deviceContextService.load();
    final origin = _localContextOrigin(widget.trip, context);
    if (origin == null) {
      return _LocalContextAgentData(
        title: 'Location context unavailable',
        detail: 'Turn on location or add trip coordinates to get nearby help.',
        recommendations: _fallbackLocalRecommendations(
          trip: widget.trip,
          now: context.now,
        ),
      );
    }

    final now = context.now;
    const kinds = [
      _LocalContextKind.food,
      _LocalContextKind.transport,
      _LocalContextKind.convenience,
      _LocalContextKind.relief,
    ];
    final groups = await Future.wait([
      _nearbyRecommendation(
        origin: origin,
        kind: _LocalContextKind.food,
        categories: _foodCategoriesFor(now),
      ),
      _nearbyRecommendation(
        origin: origin,
        kind: _LocalContextKind.transport,
        categories: const ['public_transport', 'airport.terminal'],
      ),
      _nearbyRecommendation(
        origin: origin,
        kind: _LocalContextKind.convenience,
        categories: const ['commercial.convenience', 'commercial.supermarket'],
      ),
      _nearbyRecommendation(
        origin: origin,
        kind: _LocalContextKind.relief,
        categories: const [
          'amenity.toilet',
          'commercial.shopping_mall',
          'entertainment.museum',
        ],
      ),
    ]);

    return _LocalContextAgentData(
      title: origin.fromDevice
          ? 'Nearby help from your location'
          : 'Nearby help around the trip area',
      detail: '${_timeOfDayLabel(now)} context near ${origin.label}.',
      recommendations: [
        for (var index = 0; index < groups.length; index++)
          groups[index] ??
              _fallbackLocalRecommendation(
                kind: kinds[index],
                trip: widget.trip,
                now: now,
              ),
      ],
    );
  }

  Future<_LocalContextRecommendation?> _nearbyRecommendation({
    required _LocalContextOrigin origin,
    required _LocalContextKind kind,
    required List<String> categories,
  }) async {
    try {
      final places = await _places
          .searchNearbyPlaces(
            latitude: origin.latitude,
            longitude: origin.longitude,
            categories: categories,
            radiusMeters: kind == _LocalContextKind.transport ? 1800 : 900,
            limit: 5,
          )
          .timeout(const Duration(seconds: 6));
      if (places.isEmpty) return null;
      final place = places.first;
      return _LocalContextRecommendation(
        icon: _localContextIcon(kind),
        title: _localContextTitle(kind),
        detail: '${place.name}${_distanceLabel(place.distanceMeters)}',
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _foodCategoriesFor(DateTime now) {
    final hour = now.hour;
    if ((hour >= 11 && hour <= 14) || (hour >= 17 && hour <= 21)) {
      return const [
        'catering.restaurant',
        'catering.fast_food',
        'catering.food_court',
      ];
    }
    return const ['catering.cafe', 'commercial.convenience'];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LocalContextAgentData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isLoading = snapshot.connectionState != ConnectionState.done;
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(icon: Icons.explore_rounded, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LabelText('Local context agent'),
                        const SizedBox(height: 8),
                        Text(
                          appText(
                            context,
                            isLoading
                                ? 'Checking what is useful nearby'
                                : data?.title ?? 'Local context unavailable',
                          ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appText(
                            context,
                            isLoading
                                ? 'Using time and location to prepare practical options.'
                                : data?.detail ??
                                      'Add location access for nearby food, transport, and backup options.',
                          ),
                          style: const TextStyle(
                            color: _secondary,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    IconButton(
                      tooltip: appText(context, 'Refresh local context'),
                      onPressed: () => setState(() => _future = _load()),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const LinearProgressIndicator(minHeight: 3)
              else
                for (final recommendation
                    in data?.recommendations ??
                        _fallbackLocalRecommendations(
                          trip: widget.trip,
                          now: _travelAgentNow(),
                        ))
                  _LocalContextRecommendationTile(
                    recommendation: recommendation,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalContextOrigin {
  const _LocalContextOrigin({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.fromDevice,
  });

  final double latitude;
  final double longitude;
  final String label;
  final bool fromDevice;
}

_LocalContextOrigin? _localContextOrigin(Trip trip, AppDeviceContext context) {
  if (context.hasLocation) {
    return _LocalContextOrigin(
      latitude: context.latitude!,
      longitude: context.longitude!,
      label: 'you',
      fromDevice: true,
    );
  }
  if (trip.latitude != null && trip.longitude != null) {
    return _LocalContextOrigin(
      latitude: trip.latitude!,
      longitude: trip.longitude!,
      label: trip.destination,
      fromDevice: false,
    );
  }
  if (trip.originLatitude != null && trip.originLongitude != null) {
    return _LocalContextOrigin(
      latitude: trip.originLatitude!,
      longitude: trip.originLongitude!,
      label: trip.originLabel ?? 'trip start',
      fromDevice: false,
    );
  }
  return null;
}

enum _LocalContextKind { food, transport, convenience, relief }

class _LocalContextAgentData {
  const _LocalContextAgentData({
    required this.title,
    required this.detail,
    required this.recommendations,
  });

  final String title;
  final String detail;
  final List<_LocalContextRecommendation> recommendations;
}

class _LocalContextRecommendation {
  const _LocalContextRecommendation({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class _LocalContextRecommendationTile extends StatelessWidget {
  const _LocalContextRecommendationTile({required this.recommendation});

  final _LocalContextRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(recommendation.icon, color: _primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, recommendation.title),
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appText(context, recommendation.detail),
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
      ),
    );
  }
}

IconData _localContextIcon(_LocalContextKind kind) {
  return switch (kind) {
    _LocalContextKind.food => Icons.restaurant_rounded,
    _LocalContextKind.transport => Icons.train_rounded,
    _LocalContextKind.convenience => Icons.local_convenience_store_rounded,
    _LocalContextKind.relief => Icons.umbrella_rounded,
  };
}

String _localContextTitle(_LocalContextKind kind) {
  return switch (kind) {
    _LocalContextKind.food => 'Food nearby',
    _LocalContextKind.transport => 'Transport nearby',
    _LocalContextKind.convenience => 'Convenience stop',
    _LocalContextKind.relief => 'Toilet or indoor backup',
  };
}

String _distanceLabel(int? meters) {
  if (meters == null) return '';
  if (meters < 1000) return ' / ${meters}m away';
  return ' / ${(meters / 1000).toStringAsFixed(1)}km away';
}

String _timeOfDayLabel(DateTime now) {
  final hour = now.hour;
  if (hour < 6) return 'Late-night';
  if (hour < 11) return 'Morning';
  if (hour < 15) return 'Lunch-time';
  if (hour < 18) return 'Afternoon';
  if (hour < 22) return 'Evening';
  return 'Late-night';
}

List<_LocalContextRecommendation> _fallbackLocalRecommendations({
  required Trip trip,
  required DateTime now,
}) {
  return [
    _fallbackLocalRecommendation(
      kind: _LocalContextKind.food,
      trip: trip,
      now: now,
    ),
    _fallbackLocalRecommendation(
      kind: _LocalContextKind.transport,
      trip: trip,
      now: now,
    ),
    _fallbackLocalRecommendation(
      kind: _LocalContextKind.convenience,
      trip: trip,
      now: now,
    ),
    _fallbackLocalRecommendation(
      kind: _LocalContextKind.relief,
      trip: trip,
      now: now,
    ),
  ];
}

_LocalContextRecommendation _fallbackLocalRecommendation({
  required _LocalContextKind kind,
  required Trip trip,
  required DateTime now,
}) {
  final destination = trip.destination.split(',').first;
  return switch (kind) {
    _LocalContextKind.food => _LocalContextRecommendation(
      icon: _localContextIcon(kind),
      title: _localContextTitle(kind),
      detail: now.hour >= 17
          ? 'Look for dinner within one transit stop of today\'s area.'
          : 'Keep a cafe or quick lunch option near the next stop.',
    ),
    _LocalContextKind.transport => _LocalContextRecommendation(
      icon: _localContextIcon(kind),
      title: _localContextTitle(kind),
      detail:
          'Prefer the closest station or bus stop before crossing $destination.',
    ),
    _LocalContextKind.convenience => _LocalContextRecommendation(
      icon: _localContextIcon(kind),
      title: _localContextTitle(kind),
      detail:
          'Use a convenience store for water, transit card top-up, or snacks.',
    ),
    _LocalContextKind.relief => _LocalContextRecommendation(
      icon: _localContextIcon(kind),
      title: _localContextTitle(kind),
      detail:
          'Keep a mall, museum, station, or department store as the backup.',
    ),
  };
}

class _DailyAgentPanel extends StatelessWidget {
  const _DailyAgentPanel({required this.trip, required this.runtime});

  final Trip trip;
  final _TripRuntimePlan runtime;

  @override
  Widget build(BuildContext context) {
    final next = runtime.nextItem;
    final nextStart = runtime.nextItemStartAt;
    final advice = _dailyAgentAdvice(trip, runtime);
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.auto_awesome_rounded, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelText('Daily agent'),
                const SizedBox(height: 8),
                Text(
                  advice.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advice.detail,
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallPill(label: _dateKey(_travelAgentNow())),
                    SmallPill(
                      label:
                          'Day ${runtime.currentDay} of ${runtime.totalDays}',
                    ),
                    if (next != null && nextStart != null)
                      SmallPill(label: _clockLabel(nextStart)),
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

class _DailyAgentAdvice {
  const _DailyAgentAdvice({required this.title, required this.detail});

  final String title;
  final String detail;
}

_DailyAgentAdvice _dailyAgentAdvice(
  Trip trip,
  _TripRuntimePlan runtime, {
  DateTime? now,
}) {
  final current = now ?? _travelAgentNow();
  final next = runtime.nextItem;
  final nextStart = runtime.nextItemStartAt;

  if (runtime.phase == _TripRuntimePhase.beforeStart) {
    return _DailyAgentAdvice(
      title: 'Trip starts on ${trip.startDate}',
      detail: 'Keep bookings, packing, and the first route ready before day 1.',
    );
  }
  if (runtime.phase == _TripRuntimePhase.afterTrip) {
    return const _DailyAgentAdvice(
      title: 'This active trip is past its dates',
      detail: 'Run the repair agent below to sync the itinerary with today.',
    );
  }
  if (next == null) {
    return _DailyAgentAdvice(
      title: 'Day ${runtime.currentDay} is open now',
      detail: runtime.todaysItems.isEmpty
          ? 'No stops are planned for today yet.'
          : 'All scheduled stops for today are already behind you.',
    );
  }
  if (nextStart == null) {
    return _DailyAgentAdvice(
      title: 'Next: ${next.activity}',
      detail: 'This stop needs a cleaner time before the agent can time it.',
    );
  }

  final minutes = nextStart.difference(current).inMinutes;
  if (minutes <= 0) {
    return _DailyAgentAdvice(
      title: 'Next stop is ready',
      detail: '${next.activity} is scheduled for ${next.time}.',
    );
  }
  if (minutes <= 60) {
    return _DailyAgentAdvice(
      title: 'Leave window is coming up',
      detail: '${next.activity} starts in $minutes minutes at ${next.time}.',
    );
  }
  return _DailyAgentAdvice(
    title: 'Next: ${next.activity}',
    detail: 'You have ${minutes ~/ 60}h ${minutes % 60}m until ${next.time}.',
  );
}

class _RepairAgentPanel extends StatelessWidget {
  const _RepairAgentPanel({required this.suggestions, required this.onApply});

  final List<_ItineraryRepairSuggestion> suggestions;
  final ValueChanged<_ItineraryRepairSuggestion> onApply;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: Icons.verified_rounded, size: 44),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelText('Repair agent'),
                  SizedBox(height: 4),
                  Text(
                    'No obvious itinerary issues found.',
                    style: TextStyle(
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

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.build_circle_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelText('Repair agent'),
                    const SizedBox(height: 4),
                    Text(
                      '${suggestions.length} fix${suggestions.length == 1 ? '' : 'es'} to review',
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
          const SizedBox(height: 12),
          for (var index = 0; index < suggestions.length; index++) ...[
            _RepairSuggestionTile(
              suggestion: suggestions[index],
              onApply: suggestions[index].canApply
                  ? () => onApply(suggestions[index])
                  : null,
            ),
            if (index != suggestions.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RepairSuggestionTile extends StatelessWidget {
  const _RepairSuggestionTile({required this.suggestion, this.onApply});

  final _ItineraryRepairSuggestion suggestion;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(suggestion.icon, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, suggestion.title),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, suggestion.detail),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (onApply != null && suggestion.actionLabel != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onApply,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: Text(
                        appText(context, suggestion.actionLabel!),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
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
