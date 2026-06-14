part of travel_agent_app;

const _cleanGoogleMapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.medical","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.school","stylers":[{"visibility":"off"}]},
  {"featureType":"transit.station","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f7f8f8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#dceef7"}]}
]
''';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.trip,
    required this.onBack,
    this.onUpdateTrip,
    this.onAskAi,
    this.useGoogleMaps,
    super.key,
  });

  final Trip trip;
  final VoidCallback onBack;
  final Future<void> Function(Trip trip)? onUpdateTrip;
  final ValueChanged<String>? onAskAi;
  final bool? useGoogleMaps;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _fallbackCenter = LatLng(25.0330, 121.5654);
  late final _TripMapService _mapService = _TripMapService();
  final MapController _mapController = MapController();
  final TextEditingController _aiController = TextEditingController();
  google_maps.GoogleMapController? _googleMapController;
  late Trip _trip;
  LatLng? _userLocation;
  String? _locationMessage;
  String? _mapMessage;
  bool _isLocating = true;
  bool _isResolving = false;
  bool _isRouting = false;
  bool _mapReady = false;
  int _selectedDay = 1;
  int _selectedSpotIndex = 0;
  double? _panelHeight;
  MapTravelMode _travelMode = MapTravelMode.transit;
  _TripMapRoute? _route;

  bool get _usesGoogleMap =>
      widget.useGoogleMaps ??
      (kIsWeb
          ? LocalApiKeys.googleMapsWebEnabled
          : defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);

  LatLng get _initialCenter {
    final firstStop = _mappedStops.isEmpty ? null : _mappedStops.first;
    if (firstStop != null) return firstStop.point;
    final latitude = _trip.latitude;
    final longitude = _trip.longitude;
    if (latitude == null || longitude == null) return _fallbackCenter;
    return LatLng(latitude, longitude);
  }

  List<int> get _days =>
      (_trip.items.map((item) => item.day).toSet().toList()..sort());

  List<_TripMapStop> get _mapStops =>
      _trip.items.indexed
          .where((entry) => entry.$2.day == _selectedDay)
          .map((entry) => _TripMapStop(index: entry.$1, item: entry.$2))
          .toList(growable: false)
        ..sort((a, b) => _compareRuntimeScheduleItems(a.item, b.item));

  List<_TripMapStop> get _mappedStops =>
      _mapStops.where((stop) => stop.hasMapLocation).toList(growable: false);

  _TripMapStop? get _selectedStop {
    final stops = _mapStops;
    if (stops.isEmpty) return null;
    return stops[_selectedSpotIndex.clamp(0, stops.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _selectedDay = _initialDay(_trip);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateUser();
      _prepareDay();
    });
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip != widget.trip) {
      _trip = widget.trip;
      if (!_days.contains(_selectedDay)) _selectedDay = _initialDay(_trip);
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareDay());
    }
  }

  @override
  void dispose() {
    _aiController.dispose();
    _mapController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationFailure('Turn on location services to find your position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationFailure('Location permission was not granted.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationFailure(
          'Location is blocked. Enable it in your device settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = location;
        _isLocating = false;
        _locationMessage = null;
        _selectedSpotIndex = 0;
      });
      if (_mapReady) _recenter();
    } on TimeoutException {
      _setLocationFailure('Location took too long. Tap the locate button.');
    } catch (_) {
      _setLocationFailure('We could not access your current location.');
    }
  }

  void _setLocationFailure(String message) {
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _locationMessage = message;
    });
  }

  Future<void> _prepareDay() async {
    if (_days.isEmpty) {
      if (!mounted) return;
      setState(() {
        _mapMessage = 'Add itinerary stops to build your route.';
        _route = null;
      });
      return;
    }

    final unresolved = _trip.items.any(
      (item) => item.day == _selectedDay && !item.hasMapLocation,
    );
    if (widget.onUpdateTrip != null && unresolved) {
      await _resolveDayPlaces();
    }
    await _loadRoute();
    _fitDayRoute();
  }

  Future<void> _resolveDayPlaces() async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _mapMessage = null;
    });
    try {
      final resolved = await _mapService.resolvePlaces(
        trip: _trip,
        day: _selectedDay,
      );
      if (!mounted) return;
      final items = [..._trip.items];
      var changed = false;
      for (final place in resolved) {
        if (place.index < 0 || place.index >= items.length) continue;
        final current = items[place.index];
        final updatedItem = current.copyWith(
          placeId: place.placeId,
          formattedAddress: place.formattedAddress,
          latitude: place.latitude,
          longitude: place.longitude,
        );
        items[place.index] = updatedItem;
        changed =
            changed ||
            !current.hasMapLocation ||
            current.placeId != updatedItem.placeId ||
            current.formattedAddress != updatedItem.formattedAddress;
      }
      if (changed) {
        final updated = _trip.copyWith(items: items);
        setState(() => _trip = updated);
        final onUpdateTrip = widget.onUpdateTrip;
        if (onUpdateTrip != null) await onUpdateTrip(updated);
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(
        () => _mapMessage =
            error.message ?? 'Some itinerary stops could not be located.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _mapMessage = 'Some itinerary stops could not be located.',
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _loadRoute() async {
    final stops = _mappedStops;
    if (stops.length < 2) {
      if (mounted) setState(() => _route = null);
      return;
    }
    setState(() {
      _isRouting = true;
      _mapMessage = null;
    });
    try {
      final route = await _mapService.computeRoute(
        tripId: _trip.id,
        stops: stops,
        mode: _travelMode,
      );
      if (!mounted) return;
      setState(() => _route = route);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _mapMessage = error.message ?? 'Route details are unavailable.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _mapMessage = 'Route details are unavailable.';
      });
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  void _recenter() {
    final location = _userLocation;
    if (location == null) {
      _locateUser();
      return;
    }
    if (_usesGoogleMap) {
      _googleMapController?.animateCamera(
        google_maps.CameraUpdate.newLatLngZoom(
          google_maps.LatLng(location.latitude, location.longitude),
          15,
        ),
      );
    } else if (_mapReady) {
      _mapController.move(location, 15);
    }
  }

  void _selectSpot(int index) {
    final stops = _mapStops;
    if (index < 0 || index >= stops.length) return;
    final stop = stops[index];
    setState(() => _selectedSpotIndex = index);
    if (!stop.hasMapLocation) return;
    if (_usesGoogleMap) {
      _googleMapController?.animateCamera(
        google_maps.CameraUpdate.newLatLngZoom(stop.googlePoint, 16),
      );
    } else if (_mapReady) {
      _mapController.move(stop.point, 16);
    }
  }

  void _selectDay(int day) {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
      _selectedSpotIndex = 0;
      _route = null;
      _mapMessage = null;
    });
    unawaited(_prepareDay());
  }

  void _selectTravelMode(MapTravelMode mode) {
    if (mode == _travelMode) return;
    setState(() {
      _travelMode = mode;
      _route = null;
    });
    unawaited(_loadRoute().then((_) => _fitDayRoute()));
  }

  Future<void> _openSelectedInGoogleMaps() async {
    final stop = _selectedStop;
    if (stop == null || !stop.hasMapLocation) return;
    final point = stop.item;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${point.latitude},${point.longitude}',
      if ((point.placeId ?? '').isNotEmpty) 'query_place_id': point.placeId!,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _askAi() {
    final prompt = _aiController.text.trim();
    if (prompt.isEmpty) return;
    widget.onAskAi?.call(prompt);
    _aiController.clear();
  }

  void _dragPanel({
    required double delta,
    required double initialHeight,
    required double minHeight,
    required double maxHeight,
  }) {
    setState(() {
      _panelHeight = ((_panelHeight ?? initialHeight) - delta).clamp(
        minHeight,
        maxHeight,
      );
    });
  }

  void _settlePanel({
    required double velocity,
    required double initialHeight,
    required double minHeight,
    required double maxHeight,
  }) {
    final current = _panelHeight ?? initialHeight;
    final target = velocity < -500
        ? maxHeight
        : velocity > 500
        ? minHeight
        : [minHeight, initialHeight, maxHeight].reduce(
            (closest, candidate) =>
                (candidate - current).abs() < (closest - current).abs()
                ? candidate
                : closest,
          );
    setState(() => _panelHeight = target);
  }

  void _togglePanel({
    required double halfHeight,
    required double minHeight,
    required double maxHeight,
  }) {
    final current = _panelHeight ?? halfHeight;
    setState(() {
      _panelHeight = current <= minHeight + 24
          ? halfHeight
          : current < maxHeight - 24
          ? maxHeight
          : minHeight;
    });
  }

  void _fitDayRoute() {
    final stops = _mappedStops;
    if (stops.isEmpty) return;
    if (stops.length == 1) {
      _selectSpot(0);
      return;
    }
    final latitudes = stops.map((stop) => stop.item.latitude!);
    final longitudes = stops.map((stop) => stop.item.longitude!);
    final southWest = LatLng(
      latitudes.reduce(math.min),
      longitudes.reduce(math.min),
    );
    final northEast = LatLng(
      latitudes.reduce(math.max),
      longitudes.reduce(math.max),
    );
    if (!_mapReady) return;
    if (_usesGoogleMap) {
      _googleMapController?.animateCamera(
        google_maps.CameraUpdate.newLatLngBounds(
          google_maps.LatLngBounds(
            southwest: google_maps.LatLng(
              southWest.latitude,
              southWest.longitude,
            ),
            northeast: google_maps.LatLng(
              northEast.latitude,
              northEast.longitude,
            ),
          ),
          74,
        ),
      );
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(southWest, northEast),
          padding: const EdgeInsets.fromLTRB(54, 150, 54, 330),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final horizontal = compact ? 14.0 : 24.0;
          final minPanelHeight = compact ? 128.0 : 122.0;
          final maxPanelHeight = math.max(
            minPanelHeight,
            constraints.maxHeight - (compact ? 92.0 : 104.0),
          );
          final halfPanelHeight = math.min(
            maxPanelHeight,
            math.max(compact ? 340.0 : 310.0, constraints.maxHeight * .5),
          );
          final bottomPanelHeight = (_panelHeight ?? halfPanelHeight).clamp(
            minPanelHeight,
            maxPanelHeight,
          );
          return Stack(
            children: [
              Positioned.fill(child: _buildMap()),
              Positioned(
                top: 14,
                left: horizontal,
                right: horizontal,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _MapTopBar(
                      destination: _trip.destination,
                      days: _days,
                      selectedDay: _selectedDay,
                      onSelectDay: _selectDay,
                      onBack: widget.onBack,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: compact ? 76 : 80,
                left: horizontal,
                child: _isLocating || _locationMessage != null
                    ? _LocationStatusChip(
                        locating: _isLocating,
                        hasLocation: _userLocation != null,
                        message: _locationMessage,
                        onTap: _recenter,
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                top: compact ? 76 : 80,
                right: horizontal,
                child: _MapControlButton(
                  tooltip: 'Center on my location',
                  icon: _isLocating
                      ? Icons.hourglass_top_rounded
                      : Icons.my_location_rounded,
                  onTap: _isLocating ? null : _recenter,
                ),
              ),
              Positioned(
                left: horizontal,
                bottom: bottomPanelHeight + 12,
                child: _usesGoogleMap
                    ? const SizedBox.shrink()
                    : const _MapAttribution(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _TripMapBottomPanel(
                  compact: compact,
                  height: bottomPanelHeight,
                  minHeight: minPanelHeight,
                  halfHeight: halfPanelHeight,
                  maxHeight: maxPanelHeight,
                  stops: _mapStops,
                  selectedIndex: _selectedSpotIndex,
                  selectedStop: _selectedStop,
                  travelMode: _travelMode,
                  route: _route,
                  message: _mapMessage,
                  resolving: _isResolving,
                  routing: _isRouting,
                  aiController: _aiController,
                  aiEnabled: widget.onAskAi != null,
                  onSelectStop: _selectSpot,
                  onSelectMode: _selectTravelMode,
                  onOpenGoogleMaps: _openSelectedInGoogleMaps,
                  onAskAi: _askAi,
                  onDrag: (delta) => _dragPanel(
                    delta: delta,
                    initialHeight: halfPanelHeight,
                    minHeight: minPanelHeight,
                    maxHeight: maxPanelHeight,
                  ),
                  onDragEnd: (velocity) => _settlePanel(
                    velocity: velocity,
                    initialHeight: halfPanelHeight,
                    minHeight: minPanelHeight,
                    maxHeight: maxPanelHeight,
                  ),
                  onToggle: () => _togglePanel(
                    halfHeight: halfPanelHeight,
                    minHeight: minPanelHeight,
                    maxHeight: maxPanelHeight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return _usesGoogleMap ? _buildGoogleMap() : _buildOpenStreetMap();
  }

  Widget _buildGoogleMap() {
    final routePoints = _route?.points ?? const <LatLng>[];
    return google_maps.GoogleMap(
      initialCameraPosition: google_maps.CameraPosition(
        target: google_maps.LatLng(
          _initialCenter.latitude,
          _initialCenter.longitude,
        ),
        zoom: 14,
      ),
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      style: _cleanGoogleMapStyle,
      markers: {
        if (_userLocation != null)
          google_maps.Marker(
            markerId: const google_maps.MarkerId('current-location'),
            position: google_maps.LatLng(
              _userLocation!.latitude,
              _userLocation!.longitude,
            ),
            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
              google_maps.BitmapDescriptor.hueAzure,
            ),
            infoWindow: const google_maps.InfoWindow(title: 'You are here'),
          ),
        for (final entry in _mapStops.indexed)
          if (entry.$2.hasMapLocation)
            google_maps.Marker(
              markerId: google_maps.MarkerId('itinerary-${entry.$1}'),
              position: entry.$2.googlePoint,
              icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
                entry.$1 == _selectedSpotIndex
                    ? google_maps.BitmapDescriptor.hueAzure
                    : google_maps.BitmapDescriptor.hueRed,
              ),
              infoWindow: google_maps.InfoWindow(
                title: entry.$2.item.activity,
                snippet: entry.$2.item.time,
              ),
              onTap: () => _selectSpot(entry.$1),
            ),
      },
      polylines: routePoints.isEmpty
          ? const {}
          : {
              google_maps.Polyline(
                polylineId: const google_maps.PolylineId('itinerary-route'),
                points: routePoints
                    .map(
                      (point) =>
                          google_maps.LatLng(point.latitude, point.longitude),
                    )
                    .toList(growable: false),
                color: const Color(0xFF1A73E8),
                width: 5,
              ),
            },
      onMapCreated: (controller) {
        _googleMapController = controller;
        _mapReady = true;
        _fitDayRoute();
      },
    );
  }

  Widget _buildOpenStreetMap() {
    final routePoints = _route?.points ?? const <LatLng>[];
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: 14,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: () {
          _mapReady = true;
          final location = _userLocation;
          if (location != null) _mapController.move(location, 15);
          _fitDayRoute();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.lab05_example',
          maxZoom: 19,
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: const Color(0xFF1A73E8),
                strokeWidth: 5,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 58,
                height: 58,
                child: const _CurrentLocationMarker(),
              ),
            for (final entry in _mapStops.indexed)
              if (entry.$2.hasMapLocation)
                Marker(
                  point: entry.$2.point,
                  width: 50,
                  height: 58,
                  alignment: Alignment.topCenter,
                  child: _NearbySpotMarker(
                    icon: entry.$2.item.type,
                    selected: entry.$1 == _selectedSpotIndex,
                    onTap: () => _selectSpot(entry.$1),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.destination,
    required this.days,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onBack,
  });

  final String destination;
  final List<int> days;
  final int selectedDay;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MapControlButton(
          tooltip: 'Back',
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.white.withValues(alpha: .96),
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF1A73E8),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appText(context, destination),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (days.isNotEmpty)
                    PopupMenuButton<int>(
                      tooltip: 'Choose itinerary day',
                      initialValue: selectedDay,
                      onSelected: onSelectDay,
                      itemBuilder: (context) => [
                        for (final day in days)
                          PopupMenuItem(value: day, child: Text('Day $day')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Day $selectedDay',
                              style: const TextStyle(
                                color: Color(0xFF3C4043),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.expand_more_rounded,
                              color: Color(0xFF5F6368),
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationStatusChip extends StatelessWidget {
  const _LocationStatusChip({
    required this.locating,
    required this.hasLocation,
    required this.message,
    required this.onTap,
  });

  final bool locating;
  final bool hasLocation;
  final String? message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = locating
        ? 'Finding your location'
        : hasLocation
        ? 'You are here'
        : message ?? 'Location unavailable';
    final color = hasLocation
        ? const Color(0xFF1A73E8)
        : const Color(0xFF3C4043);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Material(
        color: Colors.white.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(99),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .1),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locating)
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A73E8),
                    ),
                  )
                else
                  Icon(
                    hasLocation
                        ? Icons.near_me_rounded
                        : Icons.location_off_rounded,
                    color: color,
                    size: 16,
                  ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .96),
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .1),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        color: const Color(0xFF3C4043),
        icon: Icon(icon),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(
          color: _primary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: .35),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1687D9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbySpotMarker extends StatelessWidget {
  const _NearbySpotMarker({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: selected ? 44 : 38,
          height: selected ? 44 : 38,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A73E8) : Colors.white,
            borderRadius: BorderRadius.circular(selected ? 16 : 14),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : const Color(0xFF5F6368),
            size: selected ? 22 : 19,
          ),
        ),
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: _responsivePagePadding(context, top: 18, bottom: 40),
            children: [
              TopBar(title: 'Travel Info', onBack: onBack),
              const SizedBox(height: 18),
              const _TravelReadinessBanner(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Important notices',
                subtitle: 'Review before departure and again before entry.',
              ),
              const SizedBox(height: 12),
              const _TravelNoticeGrid(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Emergency contacts',
                subtitle: 'Japan example for the current Kyoto trip.',
              ),
              const SizedBox(height: 12),
              const _EmergencyContactsPanel(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Useful local details',
                subtitle: 'Practical reminders for the day.',
              ),
              const SizedBox(height: 12),
              const _LocalDetailsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelReadinessBanner extends StatelessWidget {
  const _TravelReadinessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0C979)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5AD),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.gpp_maybe_rounded,
              color: Color(0xFF8A5A00),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Check official requirements'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF684600),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(
                    context,
                    'Entry, visa, customs, and health rules can change. Confirm them with official authorities for your passport and travel dates.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF795B20),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _InfoSectionTitle extends StatelessWidget {
  const _InfoSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText(context, title),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          appText(context, subtitle),
          style: const TextStyle(
            color: _secondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TravelNoticeGrid extends StatelessWidget {
  const _TravelNoticeGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 680;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.badge_outlined,
                title: 'Entry and immigration',
                text:
                    'Verify passport validity, visa or visa-free eligibility, and permitted stay for your nationality.',
                tone: _NoticeTone.important,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.assignment_rounded,
                title: 'Arrival and customs',
                text:
                    'Keep accommodation and onward travel details available. Complete declarations and report controlled goods when required.',
                tone: _NoticeTone.warning,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.medical_services_outlined,
                title: 'Health and medication',
                text:
                    'Carry insurance details and prescriptions. Check destination rules before bringing medication across a border.',
                tone: _NoticeTone.neutral,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.account_balance_rounded,
                title: 'Embassy or consulate',
                text:
                    'Save your nearest embassy or consulate contact before departure in case your passport is lost or stolen.',
                tone: _NoticeTone.neutral,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _NoticeTone { important, warning, neutral }

class _TravelNoticeCard extends StatelessWidget {
  const _TravelNoticeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (tone) {
      _NoticeTone.important => (
        const Color(0xFFFFF1F1),
        const Color(0xFFF1B5B5),
        const Color(0xFF9B3030),
      ),
      _NoticeTone.warning => (
        const Color(0xFFFFF8E8),
        const Color(0xFFF0D08E),
        const Color(0xFF8A5A00),
      ),
      _NoticeTone.neutral => (Colors.white, const Color(0xFFE4E9EC), _primary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: foreground, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, title),
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(context, text),
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _EmergencyContactsPanel extends StatelessWidget {
  const _EmergencyContactsPanel();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _EmergencyContactRow(
            icon: Icons.local_police_outlined,
            label: 'Police',
            value: '110',
            detail: 'Emergency police assistance in Japan',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.local_fire_department_outlined,
            label: 'Fire and ambulance',
            value: '119',
            detail: 'Fire or urgent medical assistance in Japan',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.account_balance_outlined,
            label: 'Your embassy',
            value: 'Add contact',
            detail: 'Save the correct office for your nationality',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.health_and_safety_outlined,
            label: 'Travel insurer',
            value: 'Add policy',
            detail: 'Keep your assistance number and policy ID offline',
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appText(context, label),
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appText(context, detail),
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          appText(context, value),
          textAlign: TextAlign.end,
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _LocalDetailsGrid extends StatelessWidget {
  const _LocalDetailsGrid();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveSplit(
      breakpoint: 620,
      children: [
        InfoCard(
          icon: Icons.cloudy_snowing,
          title: 'Weather',
          text: 'Rain expected after 2 PM. Move outdoor shrines earlier.',
        ),
        InfoCard(
          icon: Icons.train_rounded,
          title: 'Transport',
          text: 'IC cards work across trains and buses around central Kyoto.',
        ),
        InfoCard(
          icon: Icons.payments_rounded,
          title: 'Local costs',
          text: 'Cash is still useful for markets and smaller local venues.',
        ),
      ],
    );
  }
}

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'Translate',
      onBack: onBack,
      children: const [
        InfoCard(
          icon: Icons.record_voice_over_rounded,
          title: 'Where is Kyoto Station?',
          text: '京都駅はどこですか？',
        ),
        InfoCard(
          icon: Icons.restaurant_rounded,
          title: 'No pork, please.',
          text: '豚肉なしでお願いします。',
        ),
        InfoCard(
          icon: Icons.confirmation_number_rounded,
          title: 'I have a reservation.',
          text: '予約があります。',
        ),
      ],
    );
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

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
    return SimpleToolScreen(
      title: 'Budget',
      onBack: onBack,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Spent'),
              Text(
                '${_displayMoney(context, actual, trip.currency)} of '
                '${_displayMoney(context, trip.budget, trip.currency)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: trip.budget == 0
                      ? 0
                      : (actual / trip.budget).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: _primary.withValues(alpha: .12),
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
        for (final category in categories)
          BudgetBar(
            name: category.category,
            planned: category.planned,
            actual: category.actual,
            currency: trip.currency,
            color: _budgetColor(category.id),
          ),
      ],
    );
  }
}

Color _budgetColor(String id) {
  switch (id) {
    case 'transport':
      return _primary;
    case 'stay':
      return _secondary;
    case 'food':
      return _accent;
    default:
      return Colors.blueGrey.shade200;
  }
}

class PackingScreen extends StatelessWidget {
  const PackingScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'AI Packing List',
      onBack: onBack,
      children: [
        for (final group in trip.checklist)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, group.category),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in group.items)
                  Builder(
                    builder: (context) {
                      final isAiAdded = _isAiChecklistItem(item);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item == group.items.first,
                        onChanged: (_) {},
                        activeColor: _primary,
                        title: Text(
                          appText(context, _checklistDisplayText(item)),
                          style: TextStyle(
                            color: isAiAdded ? const Color(0xFFB7791F) : null,
                            fontWeight: isAiAdded
                                ? FontWeight.w900
                                : FontWeight.w700,
                            backgroundColor: isAiAdded
                                ? const Color(0xFFFFF3BF)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SimpleToolScreen extends StatelessWidget {
  const SimpleToolScreen({
    required this.title,
    required this.onBack,
    required this.children,
    super.key,
  });
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18),
        children: [
          TopBar(title: title, onBack: onBack),
          const SizedBox(height: 18),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
