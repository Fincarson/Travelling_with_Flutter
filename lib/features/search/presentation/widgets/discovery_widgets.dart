part of travel_agent_app;

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        prefixIcon: IconButton(
          icon: const Icon(Icons.auto_awesome_rounded, color: _accent),
          onPressed: onSubmit,
        ),
        hintText: appText(context, hint),
      ),
    );
  }
}

class AlertRail extends StatefulWidget {
  const AlertRail({required this.trip, super.key});

  final Trip? trip;

  @override
  State<AlertRail> createState() => _AlertRailState();
}

class _AlertRailState extends State<AlertRail> {
  late Future<List<_DailyAgentUpdate>> _generalUpdates;

  @override
  void initState() {
    super.initState();
    _generalUpdates = _loadGeneralAgentUpdates();
  }

  @override
  Widget build(BuildContext context) {
    final tripUpdates = widget.trip == null
        ? const <_DailyAgentUpdate>[]
        : _dailyAgentUpdates(widget.trip!);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Important updates'),
          const SizedBox(height: 8),
          FutureBuilder<List<_DailyAgentUpdate>>(
            future: _generalUpdates,
            builder: (context, snapshot) {
              final alerts = [
                ...(snapshot.data ?? _generalAgentFallbackUpdates()),
                ...tripUpdates,
              ].take(6).toList(growable: false);
              return SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => SizedBox(
                    width: 230,
                    child: GlassPanel(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          IconBadge(icon: alerts[index].icon, size: 38),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  appText(context, alerts[index].title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  appText(context, alerts[index].detail),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _secondary,
                                    fontSize: 11,
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<List<_DailyAgentUpdate>> _loadGeneralAgentUpdates() async {
  final updates = <_DailyAgentUpdate>[];
  final context = await AppDeviceContextService().loadCurrentLocation();
  if (context.hasLocation) {
    final weatherFuture = _loadLocalWeatherUpdate(context);
    final placeFuture = _loadCurrentPlace(context);
    final weather = await weatherFuture;
    final place = await placeFuture;
    if (weather != null) updates.add(weather);
    updates.add(_generalRoadWatchUpdate(hasLocation: true));
    final city = _cityLabelFromPlace(place);
    if (city != null) {
      updates.addAll(await _loadLocalNewsUpdates(city: city));
    }
  } else {
    updates.addAll(_generalAgentFallbackUpdates());
  }
  return updates.take(5).toList(growable: false);
}

Future<PlaceSuggestion?> _loadCurrentPlace(AppDeviceContext context) async {
  final latitude = context.latitude;
  final longitude = context.longitude;
  if (latitude == null || longitude == null) return null;
  return GeoapifyPlacesService().reverseLocation(
    latitude: latitude,
    longitude: longitude,
  );
}

String? _cityLabelFromPlace(PlaceSuggestion? place) {
  if (place == null) return null;
  final candidates = [
    place.name,
    ...place.formatted.split(',').map((part) => part.trim()),
  ];
  for (final candidate in candidates) {
    final value = candidate.trim();
    if (value.length < 3) continue;
    final lower = value.toLowerCase();
    if (lower.contains('city') ||
        lower.contains('county') ||
        lower.contains('municipality') ||
        lower.contains('prefecture')) {
      return value;
    }
  }
  final parts = place.formatted
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.length >= 3)
      .toList();
  if (parts.length >= 2) return parts[parts.length - 2];
  final name = place.name.split(',').first.trim();
  return name.length >= 3 ? name : null;
}

Future<List<_DailyAgentUpdate>> _loadLocalNewsUpdates({
  required String city,
}) async {
  final queryCity = city.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (queryCity.length < 3) return const [];
  final uri = Uri.https('api.gdeltproject.org', '/api/v2/doc/doc', {
    'query': '"$queryCity"',
    'mode': 'ArtList',
    'format': 'json',
    'maxrecords': '3',
    'sort': 'DateDesc',
    'timespan': '7d',
  });

  final client = http.Client();
  try {
    final response = await client.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final articles = decoded['articles'];
    if (articles is! List) return const [];
    final seen = <String>{};
    final updates = <_DailyAgentUpdate>[];
    for (final item in articles.whereType<Map>()) {
      final title = (item['title'] as String?)?.trim();
      if (title == null || title.length < 8 || !seen.add(title)) continue;
      final domain = (item['domain'] as String?)?.trim();
      updates.add(
        _DailyAgentUpdate(
          title: title,
          detail: domain == null || domain.isEmpty
              ? 'Recent local update for $queryCity'
              : 'Recent local update for $queryCity - $domain',
          icon: Icons.article_outlined,
        ),
      );
      if (updates.length >= 3) break;
    }
    return updates;
  } catch (_) {
    return const [];
  } finally {
    client.close();
  }
}

Future<_DailyAgentUpdate?> _loadLocalWeatherUpdate(
  AppDeviceContext context,
) async {
  final latitude = context.latitude;
  final longitude = context.longitude;
  if (latitude == null || longitude == null) return null;

  final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
    queryParameters: {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'current': 'weather_code,temperature_2m,precipitation,wind_speed_10m',
      'timezone': 'auto',
      'forecast_days': '1',
    },
  );

  final client = http.Client();
  try {
    final response = await client.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final current = decoded['current'];
    if (current is! Map<String, dynamic>) return null;

    final code = (current['weather_code'] as num?)?.round();
    final temperature = current['temperature_2m'] as num?;
    final precipitation = current['precipitation'] as num?;
    final wind = current['wind_speed_10m'] as num?;
    final isRain =
        (code != null && _rainWeatherCodes.contains(code)) ||
        (precipitation != null && precipitation > 0);

    final parts = <String>[];
    if (temperature != null) {
      parts.add('${temperature.toStringAsFixed(0)} C');
    }
    parts.add(_weatherCodeLabel(code));
    if (precipitation != null && precipitation > 0) {
      parts.add('${precipitation.toStringAsFixed(1)} mm rain');
    }
    if (wind != null) parts.add('${wind.toStringAsFixed(0)} km/h wind');

    return _DailyAgentUpdate(
      title: isRain ? 'Rain nearby' : 'Local weather',
      detail: parts.join(' - '),
      icon: isRain ? Icons.cloud_rounded : Icons.wb_sunny_rounded,
    );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

List<_DailyAgentUpdate> _generalAgentFallbackUpdates() => [
  const _DailyAgentUpdate(
    title: 'Weather watch',
    detail: 'Turn on location to show live local rain and wind alerts.',
    icon: Icons.cloud_queue_rounded,
  ),
  _generalRoadWatchUpdate(hasLocation: false),
];

_DailyAgentUpdate _generalRoadWatchUpdate({required bool hasLocation}) {
  return _DailyAgentUpdate(
    title: 'Road watch',
    detail: hasLocation
        ? 'Monitoring nearby travel context. Add a route for exact stop alerts.'
        : 'Add location or a trip route to monitor nearby transport context.',
    icon: Icons.traffic_rounded,
  );
}

String _weatherCodeLabel(int? code) {
  return switch (code) {
    0 => 'clear',
    1 || 2 || 3 => 'cloudy',
    45 || 48 => 'fog',
    51 || 53 || 55 || 56 || 57 => 'drizzle',
    61 || 63 || 65 || 66 || 67 => 'rain',
    71 || 73 || 75 || 77 => 'snow',
    80 || 81 || 82 => 'showers',
    95 || 96 || 99 => 'storm risk',
    _ => 'weather check',
  };
}

class _DailyAgentUpdate {
  const _DailyAgentUpdate({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}

List<_DailyAgentUpdate> _dailyAgentUpdates(Trip trip) {
  final updates = <_DailyAgentUpdate>[];
  final runtime = _tripRuntimePlan(trip);
  final now = _travelAgentNow();

  updates.addAll(_weatherAgentUpdates(trip, now));

  final nextItem = _nextActionableHomeItem(trip, now);
  final nextStart = nextItem == null
      ? null
      : _scheduleItemStartAt(trip, nextItem);
  if (nextItem != null) {
    updates.add(
      _DailyAgentUpdate(
        title: _nextItemTitle(runtime, nextStart),
        detail: nextStart == null
            ? nextItem.activity
            : '${_relativeScheduleDate(nextStart, now)} at ${_clockLabel(nextStart)}: ${nextItem.activity}',
        icon: nextItem.type,
      ),
    );
  } else if (runtime.phase == _TripRuntimePhase.beforeStart) {
    updates.add(
      _DailyAgentUpdate(
        title: 'Trip starts soon',
        detail:
            '${trip.destination} starts on ${trip.startDate}. Review day 1 before departure.',
        icon: Icons.event_available_rounded,
      ),
    );
  }

  if (updates.isEmpty) {
    updates.add(
      const _DailyAgentUpdate(
        title: 'All clear',
        detail:
            'No urgent weather or itinerary updates for this trip right now.',
        icon: Icons.verified_rounded,
      ),
    );
  }
  return updates.take(4).toList(growable: false);
}

List<_DailyAgentUpdate> _weatherAgentUpdates(Trip trip, DateTime now) {
  final today = _dateOnly(now);
  final items = trip.items.where((item) {
    if (!_isContextScheduleItem(item)) return false;
    final startsAt = _scheduleItemStartAt(trip, item);
    if (startsAt == null) return item.day >= _tripRuntimePlan(trip).currentDay;
    return !_dateOnly(startsAt).isBefore(today);
  }).toList()..sort(_compareRuntimeScheduleItems);

  return items
      .take(2)
      .map((item) {
        final startsAt = _scheduleItemStartAt(trip, item);
        return _DailyAgentUpdate(
          title: startsAt == null
              ? 'Weather check'
              : 'Weather ${_relativeScheduleDate(startsAt, now).toLowerCase()}',
          detail: _cleanWeatherActivity(item.activity),
          icon: Icons.cloud_rounded,
        );
      })
      .toList(growable: false);
}

ScheduleItem? _nextActionableHomeItem(Trip trip, DateTime now) {
  final runtime = _tripRuntimePlan(trip, now: now);
  final items =
      trip.items.where((item) => !_isContextScheduleItem(item)).toList()
        ..sort((a, b) {
          final aStart = _scheduleItemStartAt(trip, a);
          final bStart = _scheduleItemStartAt(trip, b);
          if (aStart != null && bStart != null) return aStart.compareTo(bStart);
          return _compareRuntimeScheduleItems(a, b);
        });

  if (runtime.phase == _TripRuntimePhase.beforeStart ||
      runtime.phase == _TripRuntimePhase.unknown) {
    return items.isEmpty ? null : items.first;
  }
  if (runtime.phase == _TripRuntimePhase.afterTrip) return null;

  for (final item in items) {
    final startsAt = _scheduleItemStartAt(trip, item);
    if (startsAt == null) continue;
    if (startsAt.isAfter(now)) return item;
  }
  return null;
}

String _nextItemTitle(_TripRuntimePlan runtime, DateTime? startsAt) {
  if (runtime.phase == _TripRuntimePhase.beforeStart) return 'First itinerary';
  if (startsAt == null) return 'Upcoming stop';
  final minutes = startsAt.difference(_travelAgentNow()).inMinutes;
  if (minutes >= 0 && minutes <= 90) return 'Coming up';
  return 'Next itinerary';
}

String _relativeScheduleDate(DateTime date, DateTime now) {
  final target = _dateOnly(date);
  final today = _dateOnly(now);
  if (target == today) return 'Today';
  if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
  return _dateKey(target);
}

String _cleanWeatherActivity(String value) {
  return value
      .replaceFirst(RegExp(r'^AI weather check:\s*', caseSensitive: false), '')
      .trim();
}

class TravelGlobePreview extends StatelessWidget {
  const TravelGlobePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    if (kReleaseMode && kIsWasm && settings.heavyVisualEffects) {
      return const AnimatedGlobe();
    }
    return const SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _GlobePainter(.18),
        child: Center(
          child: Icon(Icons.public_rounded, size: 76, color: _primary),
        ),
      ),
    );
  }
}

class AnimatedGlobe extends StatefulWidget {
  const AnimatedGlobe({super.key});

  @override
  State<AnimatedGlobe> createState() => _AnimatedGlobeState();
}

class _AnimatedGlobeState extends State<AnimatedGlobe>
    with SingleTickerProviderStateMixin {
  FlutterEarthGlobeController? _earthController;
  late final AnimationController _orbitController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
    _syncOrbit();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    final earthController = _earthController;
    if (earthController?.isReady == true) {
      earthController!.dispose();
    } else {
      earthController?.onLoaded = null;
    }
    super.dispose();
  }

  // Drives the lightweight fallback globe (used on device / debug, where the
  // WASM-only earth renderer is unavailable) so it still rotates.
  void _syncOrbit() {
    final settings = PerformanceScope.maybeSettingsOf(context);
    if (settings.animationsEnabled) {
      if (!_orbitController.isAnimating) _orbitController.repeat();
    } else {
      _orbitController.stop();
    }
  }

  void _syncController() {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final shouldAnimate =
        kReleaseMode &&
        kIsWasm &&
        settings.animationsEnabled &&
        settings.heavyVisualEffects;
    final earthController = _earthController;
    if (earthController != null) {
      if (!earthController.isReady) {
        earthController.isRotating = shouldAnimate;
      } else if (shouldAnimate) {
        earthController.startRotation(rotationSpeed: .04);
      } else {
        earthController.stopRotation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.settingsOf(context);
    final useEarthRenderer =
        kReleaseMode && kIsWasm && settings.heavyVisualEffects;
    final shouldAnimate = settings.animationsEnabled && useEarthRenderer;
    if (!useEarthRenderer) {
      _syncOrbit();
      return SizedBox(
        height: 260,
        child: settings.animationsEnabled
            ? AnimatedBuilder(
                animation: _orbitController,
                builder: (context, child) => CustomPaint(
                  painter: _GlobePainter(_orbitController.value),
                  child: child,
                ),
                child: const Center(
                  child: Icon(Icons.public_rounded, size: 92, color: _primary),
                ),
              )
            : const CustomPaint(
                painter: _GlobePainter(.18),
                child: Center(
                  child: Icon(Icons.public_rounded, size: 92, color: _primary),
                ),
              ),
      );
    }
    if (useEarthRenderer && _earthController == null) {
      _earthController = FlutterEarthGlobeController(
        surface: const AssetImage('assets/globe/earth_day.jpg'),
        nightSurface: const AssetImage('assets/globe/earth_night.jpg'),
        background: const AssetImage('assets/globe/stars.jpg'),
        rotationSpeed: .04,
        isRotating: shouldAnimate,
        zoom: .1,
        minZoom: -.6,
        maxZoom: 1.4,
        atmosphereOpacity: .42,
        zoomToMousePosition: true,
      );
      _earthController!.onLoaded = () {
        if (!mounted) return;
        final current = PerformanceScope.maybeSettingsOf(context);
        if (current.animationsEnabled && current.heavyVisualEffects) {
          _earthController?.startRotation(rotationSpeed: .04);
        }
      };
    }
    return SizedBox(
      height: 260,
      child: LayoutBuilder(
        builder: (context, constraints) => FlutterEarthGlobe(
          radius: math.min(122, constraints.maxWidth * .34),
          controller: _earthController!,
        ),
      ),
    );
  }
}

class PlanningGoal {
  const PlanningGoal({
    required this.id,
    required this.icon,
    required this.title,
    required this.text,
    required this.tag,
    required this.prompt,
  });

  final String id;
  final IconData icon;
  final String title;
  final String text;
  final String tag;
  final String prompt;
}

class PlanningIdeaStrip extends StatelessWidget {
  const PlanningIdeaStrip({
    required this.goals,
    required this.selectedGoalIds,
    required this.onToggle,
    super.key,
  });

  final List<PlanningGoal> goals;
  final Set<String> selectedGoalIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: LabelText('AI planning cards')),
            if (selectedGoalIds.isNotEmpty)
              SmallPill(label: '${selectedGoalIds.length} active'),
          ],
        ),
        const SizedBox(height: 10),
        ResponsiveSplit(
          children: goals
              .map(
                (goal) => PlanningGoalCard(
                  goal: goal,
                  selected: selectedGoalIds.contains(goal.id),
                  onTap: () => onToggle(goal.id),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class PlanningGoalCard extends StatelessWidget {
  const PlanningGoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PlanningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? _accent : const Color(0xFFEFF3F6),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconBadge(icon: goal.icon, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appText(context, goal.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appText(context, goal.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _secondary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: selected ? _primary : _secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
