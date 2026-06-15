part of travel_agent_app;

class TripMapTab extends StatefulWidget {
  const TripMapTab({required this.trip, super.key});
  final Trip trip;

  @override
  State<TripMapTab> createState() => _TripMapTabState();
}

class _TripMapTabState extends State<TripMapTab> {
  final _places = GeoapifyPlacesService();
  final _mapController = MapController();
  var _stops = const <_MapItineraryStop>[];
  _MapItineraryStop? _selectedStop;
  var _mapReady = false;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStops());
  }

  @override
  void didUpdateWidget(covariant TripMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.items.length != widget.trip.items.length) {
      unawaited(_loadStops());
    }
  }

  Future<void> _loadStops() async {
    final trip = widget.trip;
    final runtime = _tripRuntimePlan(trip);
    final todaysItems = runtime.todaysItems.where(_isMappableMapItem).toList();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _selectedStop = null;
    });

    final loaded = <_MapItineraryStop>[];
    for (final item in todaysItems.take(10)) {
      var place = _savedPlaceForMapItem(item);
      final usedSavedPlace = place != null;
      place ??= await _places.searchItineraryStop(
        query: _mapSearchQuery(item),
        destination: trip.formattedAddress ?? trip.destination,
        latitude: trip.latitude,
        longitude: trip.longitude,
      );
      if (!mounted || widget.trip.id != trip.id) return;
      if (place == null || place.latitude == 0 || place.longitude == 0) {
        continue;
      }
      if (!_mapPlaceLooksRelevant(
        item: item,
        place: place,
        trip: trip,
        usedSavedPlace: usedSavedPlace,
      )) {
        continue;
      }
      loaded.add(
        _MapItineraryStop(
          item: item,
          place: place,
          imageUrl: _imageForMapStop(item: item, trip: trip),
        ),
      );
    }

    if (!mounted || widget.trip.id != trip.id) return;
    setState(() {
      _stops = loaded;
      _selectedStop = loaded.isEmpty ? null : loaded.first;
      _loading = false;
      _error = todaysItems.isNotEmpty && loaded.isEmpty
          ? 'Could not place today\'s stops on the map yet.'
          : null;
    });
    _fitMapToStops();
  }

  void _fitMapToStops() {
    if (!_mapReady || _stops.isEmpty) return;
    _mapController.move(_averageMapCenter(_stops), _zoomForStops(_stops));
  }

  void _selectStop(_MapItineraryStop stop) {
    setState(() => _selectedStop = stop);
    if (_mapReady) _mapController.move(stop.position, 14.5);
  }

  _MapItineraryStop? _stopForItem(ScheduleItem item) {
    for (final stop in _stops) {
      if (identical(stop.item, item) ||
          (stop.item.day == item.day &&
              stop.item.time == item.time &&
              stop.item.activity == item.activity)) {
        return stop;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _tripRuntimePlan(widget.trip);
    final fallbackCenter = LatLng(
      widget.trip.latitude ?? 0,
      widget.trip.longitude ?? 0,
    );
    final center = _stops.isNotEmpty
        ? _averageMapCenter(_stops)
        : fallbackCenter.latitude != 0 || fallbackCenter.longitude != 0
        ? fallbackCenter
        : const LatLng(-6.9175, 107.6191);
    final dayLabel = 'Day ${runtime.currentDay} of ${runtime.totalDays}';

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Today\'s route map'),
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  widget.trip.formattedAddress ?? widget.trip.destination,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appText(context, dayLabel),
                style: const TextStyle(
                  color: Color(0xFF79ACD8),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              _TodayMapPanel(
                mapController: _mapController,
                center: center,
                initialZoom: _stops.isEmpty ? 12.5 : _zoomForStops(_stops),
                stops: _stops,
                selectedStop: _selectedStop,
                loading: _loading,
                error: _error,
                onMapReady: () {
                  _mapReady = true;
                  _fitMapToStops();
                },
                onSelectStop: _selectStop,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (runtime.todaysItems.isNotEmpty)
          for (final item in runtime.todaysItems)
            _MapSelectableScheduleTile(
              item: item,
              currency: widget.trip.currency,
              stop: _stopForItem(item),
              selected: _selectedStop?.id == _stopForItem(item)?.id,
              onSelectStop: _selectStop,
            )
        else if (widget.trip.items.isNotEmpty)
          for (final item in widget.trip.items.take(6))
            ScheduleTile(item: item, currency: widget.trip.currency)
        else
          const _MapEmptyPanel(),
      ],
    );
  }
}

class _MapEmptyPanel extends StatelessWidget {
  const _MapEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const Icon(Icons.map_rounded, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, 'Today does not have schedule items yet.'),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMapPanel extends StatelessWidget {
  const _TodayMapPanel({
    required this.mapController,
    required this.center,
    required this.initialZoom,
    required this.stops,
    required this.selectedStop,
    required this.loading,
    required this.error,
    required this.onMapReady,
    required this.onSelectStop,
  });

  final MapController mapController;
  final LatLng center;
  final double initialZoom;
  final List<_MapItineraryStop> stops;
  final _MapItineraryStop? selectedStop;
  final bool loading;
  final String? error;
  final VoidCallback onMapReady;
  final ValueChanged<_MapItineraryStop> onSelectStop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 430,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: initialZoom,
                maxZoom: 18,
                minZoom: 3,
                onMapReady: onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'travelling_with_flutter',
                  maxZoom: 19,
                ),
                if (stops.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: stops
                            .map((stop) => stop.position)
                            .toList(growable: false),
                        color: _primary.withValues(alpha: .72),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var index = 0; index < stops.length; index += 1)
                      _mapMarkerForStop(
                        stop: stops[index],
                        index: index,
                        selected: stops[index].id == selectedStop?.id,
                        onTap: () => onSelectStop(stops[index]),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _MapStatusPill(
                    icon: Icons.route_rounded,
                    label: loading
                        ? 'Placing today\'s stops'
                        : '${stops.length} mapped stops',
                  ),
                ],
              ),
            ),
            if (loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (error != null && !loading)
              Positioned(
                left: 12,
                right: 12,
                top: 64,
                child: FormNotice(message: error!),
              ),
            if (selectedStop != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _MapStopCard(stop: selectedStop!),
              ),
          ],
        ),
      ),
    );
  }
}

Marker _mapMarkerForStop({
  required _MapItineraryStop stop,
  required int index,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Marker(
    point: stop.position,
    width: selected ? 54 : 46,
    height: selected ? 54 : 46,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E5D7C) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2E5D7C), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF2E5D7C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MapStopCard extends StatelessWidget {
  const _MapStopCard({required this.stop});

  final _MapItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EEF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              stop.imageUrl,
              width: 104,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 104,
                height: 96,
                color: const Color(0xFFEAF6FF),
                child: const Icon(Icons.map_rounded, color: _primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stop.item.time.trim().isEmpty
                      ? appText(context, 'Today')
                      : stop.item.time,
                  style: const TextStyle(
                    color: Color(0xFF79ACD8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.item.activity,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stop.place.formatted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5E6A72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

class _MapSelectableScheduleTile extends StatelessWidget {
  const _MapSelectableScheduleTile({
    required this.item,
    required this.currency,
    required this.stop,
    required this.selected,
    required this.onSelectStop,
  });

  final ScheduleItem item;
  final String currency;
  final _MapItineraryStop? stop;
  final bool selected;
  final ValueChanged<_MapItineraryStop> onSelectStop;

  @override
  Widget build(BuildContext context) {
    final mappedStop = stop;
    if (mappedStop == null) return ScheduleTile(item: item, currency: currency);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: selected
            ? Border.all(color: const Color(0xFF79ACD8), width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => onSelectStop(mappedStop),
          child: ScheduleTile(item: item, currency: currency),
        ),
      ),
    );
  }
}

class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 17),
          const SizedBox(width: 7),
          Text(
            appText(context, label),
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapItineraryStop {
  const _MapItineraryStop({
    required this.item,
    required this.place,
    required this.imageUrl,
  });

  final ScheduleItem item;
  final PlaceSuggestion place;
  final String imageUrl;

  String get id => '${item.day}-${item.time}-${item.activity}';

  LatLng get position => LatLng(place.latitude, place.longitude);
}

LatLng _averageMapCenter(List<_MapItineraryStop> stops) {
  final lat =
      stops
          .map((stop) => stop.place.latitude)
          .reduce((value, element) => value + element) /
      stops.length;
  final lon =
      stops
          .map((stop) => stop.place.longitude)
          .reduce((value, element) => value + element) /
      stops.length;
  return LatLng(lat, lon);
}

double _zoomForStops(List<_MapItineraryStop> stops) {
  if (stops.length <= 1) return 14;
  var minLat = stops.first.place.latitude;
  var maxLat = stops.first.place.latitude;
  var minLon = stops.first.place.longitude;
  var maxLon = stops.first.place.longitude;
  for (final stop in stops.skip(1)) {
    minLat = math.min(minLat, stop.place.latitude);
    maxLat = math.max(maxLat, stop.place.latitude);
    minLon = math.min(minLon, stop.place.longitude);
    maxLon = math.max(maxLon, stop.place.longitude);
  }
  final span = math.max(maxLat - minLat, maxLon - minLon).abs();
  if (span < .01) return 14.5;
  if (span < .04) return 13.5;
  if (span < .1) return 12.5;
  if (span < .25) return 11.5;
  if (span < .6) return 10.5;
  if (span < 1.5) return 9;
  return 7.5;
}

bool _isMappableMapItem(ScheduleItem item) {
  final activity = item.activity.trim().toLowerCase();
  if (activity.length < 3) return false;
  if (_isContextScheduleItem(item)) return false;
  if (_isGenericMapActivity(activity)) return false;
  if (activity.startsWith('pack ') ||
      activity.startsWith('prepare ') ||
      activity.startsWith('bring ') ||
      activity.contains('umbrella') ||
      activity.contains('raincoat') ||
      activity.contains('protect tickets')) {
    return false;
  }
  return true;
}

bool _isGenericMapActivity(String activity) {
  return activity.contains('signature landmark') ||
      activity.contains('transit-friendly district route') ||
      activity.contains('scenic walk, riverside, or viewpoint') ||
      activity.contains('find the best local scene') ||
      activity.contains('nearby cafe or market stop') ||
      activity.contains('known landmark or historic area') ||
      activity.contains('local lunch area') ||
      activity.contains('dinner near the evening area') ||
      activity.contains('easy evening viewpoint') ||
      activity.contains('shopping street or neighborhood browse') ||
      activity.contains('food market or local specialty lunch') ||
      activity.contains('golden-hour park, bridge, or plaza');
}

bool _mapPlaceLooksRelevant({
  required ScheduleItem item,
  required PlaceSuggestion place,
  required Trip trip,
  required bool usedSavedPlace,
}) {
  final tripLat = trip.latitude;
  final tripLng = trip.longitude;
  if (tripLat == null || tripLng == null || tripLat == 0 || tripLng == 0) {
    return true;
  }
  final distance = _distanceKm(
    tripLat,
    tripLng,
    place.latitude,
    place.longitude,
  );
  if (distance <= _maxLocalMapStopDistanceKm) return true;
  if (_isLongDistanceMapItem(item)) return usedSavedPlace;
  return false;
}

bool _isLongDistanceMapItem(ScheduleItem item) {
  final activity = item.activity.toLowerCase();
  return item.type == Icons.flight_takeoff_rounded ||
      activity.contains('flight ') ||
      activity.contains('fly ') ||
      activity.contains('airport') ||
      activity.contains('intercity') ||
      activity.contains('long-haul') ||
      activity.contains('return home') ||
      activity.contains('go home');
}

const _maxLocalMapStopDistanceKm = 80.0;

String _mapSearchQuery(ScheduleItem item) {
  return item.activity
      .replaceAll(
        RegExp(
          r'\b(move|transfer|walk|visit|stop|check)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

PlaceSuggestion? _savedPlaceForMapItem(ScheduleItem item) {
  final latitude = item.latitude;
  final longitude = item.longitude;
  if (latitude == null || longitude == null) return null;
  if (latitude == 0 || longitude == 0) return null;
  final address = item.address?.trim();
  return PlaceSuggestion(
    name: item.activity,
    formatted: address == null || address.isEmpty ? item.activity : address,
    latitude: latitude,
    longitude: longitude,
    placeId: address == null || address.isEmpty ? item.activity : address,
  );
}

String _imageForMapStop({required ScheduleItem item, required Trip trip}) {
  final saved = item.imageUrl?.trim();
  if (saved != null && saved.startsWith('https://')) return saved;
  if (trip.images.isNotEmpty) return trip.images.first;
  return destinations.first.image;
}
