part of travel_agent_app;

const _previewJobStartedMessage =
    'I am building the preview in the background. You can leave this screen and come back when it is ready.';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({
    required this.accountId,
    required this.onBack,
    required this.onGenerate,
    required this.profileLanguage,
    required this.savedTrips,
    super.key,
  });
  final String accountId;
  final VoidCallback onBack;
  final Future<void> Function(Trip trip) onGenerate;
  final String profileLanguage;
  final List<Trip> savedTrips;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _TripTemplate {
  const _TripTemplate({
    required this.trip,
    required this.source,
    required this.description,
    required this.badge,
  });

  final Trip trip;
  final String source;
  final String description;
  final String badge;
}

class _PendingAiTripPreview {
  const _PendingAiTripPreview({
    required this.place,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.currency,
    required this.groupType,
    required this.preferences,
    required this.plan,
    required this.startLocation,
    required this.images,
    this.jobId,
  });

  final PlaceSuggestion place;
  final DateTime startDate;
  final DateTime endDate;
  final int budget;
  final String currency;
  final String groupType;
  final List<String> preferences;
  final GeneratedTripPlan plan;
  final TripStartLocation? startLocation;
  final List<String> images;
  final String? jobId;
}

enum _TimingPresetProfile { nearby, farDomestic, international }

class _CreateTripScreenState extends State<CreateTripScreen> {
  static const _createTripChatTurnTimeout = Duration(seconds: 35);

  final _places = GeoapifyPlacesService();
  final _assistant = TravelAssistantService();
  final _previewJobs = TripPreviewJobService();
  final _plannerSessions = CreateTripPlannerSessionRepository(
    FirebaseFirestore.instance,
  );
  final _deviceContextService = AppDeviceContextService();
  final _destination = TextEditingController();
  final _budget = TextEditingController();
  final _chatInput = TextEditingController();
  final _customPreference = TextEditingController();
  final _startLocation = TextEditingController();
  final _airline = TextEditingController();
  final _flightCode = TextEditingController();
  final _ticketPassengerName = TextEditingController();
  final _ticketPaidAmount = TextEditingController();
  final _flightDepartTime = TextEditingController();
  final _flightDepartPlace = TextEditingController();
  final _flightLandingTime = TextEditingController();
  final _flightLandingPlace = TextEditingController();
  Timer? _searchTimer;
  Timer? _originSearchTimer;
  Timer? _plannerSessionSaveTimer;
  StreamSubscription<List<TripPreviewJob>>? _previewJobSubscription;
  StreamSubscription<CreateTripPlannerSession?>? _plannerSessionSubscription;
  PlaceSuggestion? _selectedPlace;
  PlaceSuggestion? _selectedOriginPlace;
  List<PlaceSuggestion> _placeSuggestions = const [];
  List<PlaceSuggestion> _originSuggestions = const [];
  List<TransportRecommendation> _transportRecommendations = const [];
  List<TransportRecommendation> get _visibleTransportRecommendations {
    final combined = [
      ..._purchasedTransportRecommendations,
      ..._transportRecommendations,
    ];
    combined.sort((a, b) {
      final aPrice = a.price <= 0 ? 1 << 30 : a.price;
      final bPrice = b.price <= 0 ? 1 << 30 : b.price;
      return aPrice.compareTo(bPrice);
    });
    return combined;
  }

  final List<CreateTripChatMessage> _chatMessages = [];
  CreateTripDraft? _pendingDraft;
  var _group = 'Friends';
  var _currency = AppCurrency.fallbackCurrencyCode;
  var _mode = 0;
  String? _formError;
  var _isSearching = false;
  var _isOriginSearching = false;
  var _isGenerating = false;
  var _isLoadingTransport = false;
  var _isPreparingPreview = false;
  var _isCreatingTrip = false;
  var _isThinking = false;
  var _pendingDraftConfirmed = false;
  var _appliedDeviceCurrency = false;
  var _hasBudgetText = false;
  String? _lastAiError;
  String? _activePreviewJobId;
  var _plannerSessionLoaded = false;
  var _hasLocalPlannerSessionChanges = false;
  var _suppressPlannerSessionSave = false;
  String? _transportRecommendationSummary;
  String? _transportRecommendationError;
  _PendingAiTripPreview? _pendingAiTripPreview;
  AppDeviceContext? _deviceContext;
  TripStartLocation? _tripStartLocation;
  int? _aiExpandedStep;
  final Set<int> _aiCompletedSteps = {};
  var _aiPreviewExpanded = false;
  int? _manualExpandedStep;
  final Set<int> _manualCompletedSteps = {};
  var _manualPreviewExpanded = false;
  DateTime _startDate = _travelAgentNow();
  DateTime _endDate = _travelAgentNow().add(const Duration(days: 5));
  String? _selectedImage;
  final Set<String> _preferences = {'Culture', 'Food'};
  final Set<String> _planningGoalIds = {};

  static const _preferenceOptions = [
    'Culture',
    'Food',
    'Nature',
    'Shopping',
    'Relax',
    'Nightlife',
    'Museums',
    'Adventure',
    'Budget-friendly',
    'Luxury',
    'Walking',
  ];

  static const _currencyOptions = ['USD', 'TWD', 'IDR', 'JPY', 'EUR'];
  static const _groupOptions = ['Friends', 'Family', 'Tour'];
  static const _twdToIdrFallbackRate = 562.0;

  static const _planningGoals = [
    PlanningGoal(
      id: 'local_food',
      icon: Icons.restaurant_rounded,
      title: 'Food',
      text: 'Local meals',
      tag: 'Local food',
      prompt:
          'AI focus: include local food, market meals, cafes, and realistic meal timing.',
    ),
    PlanningGoal(
      id: 'low_walking',
      icon: Icons.directions_walk_rounded,
      title: 'Route',
      text: 'Less walking',
      tag: 'Low walking',
      prompt:
          'AI focus: reduce walking distance, group nearby stops, and prefer easy transit.',
    ),
    PlanningGoal(
      id: 'rain_ready',
      icon: Icons.cloud_rounded,
      title: 'Weather',
      text: 'Rain backup',
      tag: 'Rain-ready',
      prompt:
          'AI focus: include indoor backups and weather-flexible activities.',
    ),
    PlanningGoal(
      id: 'family_pace',
      icon: Icons.family_restroom_rounded,
      title: 'Pace',
      text: 'Easy day',
      tag: 'Easy pace',
      prompt:
          'AI focus: leave buffer time, avoid overpacking the day, and keep the route comfortable.',
    ),
  ];

  static const _galleryOptions = [
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=600',
    'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=600',
    'https://images.unsplash.com/photo-1492571350019-22de08371fd3?q=80&w=600',
    'https://images.unsplash.com/photo-1464817739973-0128fe72aa1b?q=80&w=600',
    'https://images.unsplash.com/photo-1454391304352-2bf4678b1a7a?q=80&w=600',
    'https://images.unsplash.com/photo-1533105079780-92b9be482077?q=80&w=600',
  ];

  static const _recommendedTemplates = [
    _TripTemplate(
      source: 'Online recommendation',
      description:
          'A city-first route with food neighborhoods, shrines, museums, and easy transit.',
      badge: 'Trending',
      trip: Trip(
        id: 'template-tokyo-food-culture',
        title: 'Tokyo food and culture',
        destination: 'Tokyo, Japan',
        startDate: '2026-09-10',
        endDate: '2026-09-15',
        budget: 4200,
        spent: 0,
        groupType: 'Friends',
        currency: 'USD',
        status: TripStatus.upcoming,
        images: [
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?q=80&w=900',
          'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=900',
        ],
        preferences: ['Food', 'Culture', 'Shopping'],
        items: [
          ScheduleItem(
            1,
            '10:00 AM',
            'Shinjuku arrival and station-area orientation',
            Icons.train_rounded,
            0,
          ),
          ScheduleItem(
            1,
            '01:00 PM',
            'Omoide Yokocho lunch crawl',
            Icons.restaurant_rounded,
            55,
          ),
          ScheduleItem(
            2,
            '09:30 AM',
            'Meiji Shrine and Harajuku walk',
            Icons.temple_buddhist_rounded,
            0,
          ),
          ScheduleItem(
            3,
            '11:00 AM',
            'Ueno museums and Ameyoko market',
            Icons.museum_rounded,
            45,
          ),
          ScheduleItem(
            4,
            '05:00 PM',
            'Shibuya crossing, dinner, and skyline views',
            Icons.restaurant_rounded,
            80,
          ),
        ],
        bookings: [
          Booking(
            'Tokyo hotel placeholder',
            '2026-09-10',
            '15:00',
            'HOTEL-TBD',
            980,
            Icons.hotel_rounded,
          ),
          Booking(
            'Airport rail transfer',
            '2026-09-10',
            '11:00',
            'TRANSIT-TBD',
            40,
            Icons.train_rounded,
          ),
        ],
        checklist: [
          ChecklistCategory('Essentials', [
            'Passport',
            'Transit card setup',
            'Comfortable walking shoes',
          ]),
          ChecklistCategory('Reservations', [
            'Popular restaurant shortlist',
            'Museum tickets',
          ]),
        ],
        budgetCategories: [
          BudgetCategory(
            id: 'transport',
            category: 'Transport',
            planned: 900,
            actual: 0,
          ),
          BudgetCategory(
            id: 'stay',
            category: 'Stay',
            planned: 1200,
            actual: 0,
          ),
          BudgetCategory(id: 'food', category: 'Food', planned: 900, actual: 0),
          BudgetCategory(
            id: 'activities',
            category: 'Activities',
            planned: 700,
            actual: 0,
          ),
        ],
      ),
    ),
    _TripTemplate(
      source: 'Online recommendation',
      description:
          'A calmer beach-and-nature plan with temples, rice terraces, and slow mornings.',
      badge: 'Relaxed',
      trip: Trip(
        id: 'template-bali-nature-reset',
        title: 'Bali nature reset',
        destination: 'Bali, Indonesia',
        startDate: '2026-10-05',
        endDate: '2026-10-11',
        budget: 3200,
        spent: 0,
        groupType: 'Family',
        currency: 'USD',
        status: TripStatus.upcoming,
        images: [
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=900',
          'https://images.unsplash.com/photo-1518548419970-58e3b4079ab2?q=80&w=900',
        ],
        preferences: ['Nature', 'Relax', 'Culture'],
        items: [
          ScheduleItem(
            1,
            '11:00 AM',
            'Arrive in Ubud and settle into the villa',
            Icons.hotel_rounded,
            0,
          ),
          ScheduleItem(
            2,
            '08:30 AM',
            'Tegalalang rice terrace walk',
            Icons.hiking_rounded,
            20,
          ),
          ScheduleItem(
            3,
            '09:00 AM',
            'Tirta Empul temple visit',
            Icons.temple_buddhist_rounded,
            15,
          ),
          ScheduleItem(
            4,
            '10:30 AM',
            'Seminyak beach morning and seafood lunch',
            Icons.beach_access_rounded,
            65,
          ),
          ScheduleItem(
            5,
            '04:30 PM',
            'Uluwatu sunset and dinner',
            Icons.restaurant_rounded,
            85,
          ),
        ],
        bookings: [
          Booking(
            'Ubud villa placeholder',
            '2026-10-05',
            '15:00',
            'STAY-TBD',
            760,
            Icons.hotel_rounded,
          ),
          Booking(
            'Private driver day',
            '2026-10-07',
            '08:00',
            'DRIVER-TBD',
            120,
            Icons.train_rounded,
          ),
        ],
        checklist: [
          ChecklistCategory('Essentials', [
            'Passport',
            'Sun protection',
            'Swimwear',
          ]),
          ChecklistCategory('Comfort', [
            'Light layers',
            'Mosquito repellent',
            'Temple scarf or sarong',
          ]),
        ],
        budgetCategories: [
          BudgetCategory(
            id: 'transport',
            category: 'Transport',
            planned: 650,
            actual: 0,
          ),
          BudgetCategory(id: 'stay', category: 'Stay', planned: 900, actual: 0),
          BudgetCategory(id: 'food', category: 'Food', planned: 620, actual: 0),
          BudgetCategory(
            id: 'activities',
            category: 'Activities',
            planned: 500,
            actual: 0,
          ),
        ],
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _budget.addListener(_syncBudgetTextState);
    unawaited(_loadDeviceContext());
    _watchPreviewJobs();
    _watchPlannerSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedDeviceCurrency) return;
    _appliedDeviceCurrency = true;

    final deviceCurrency = AppCurrency.defaultForDevice(
      supportedCurrencies: _currencyOptions,
    );
    if (deviceCurrency == _currency) return;

    _currency = deviceCurrency;
  }

  @override
  void dispose() {
    if (_chatMessages.isNotEmpty || _pendingDraft != null) {
      unawaited(_savePlannerSessionNow());
    }
    _previewJobSubscription?.cancel();
    _plannerSessionSubscription?.cancel();
    _plannerSessionSaveTimer?.cancel();
    _searchTimer?.cancel();
    _originSearchTimer?.cancel();
    _budget.removeListener(_syncBudgetTextState);
    _destination.dispose();
    _budget.dispose();
    _chatInput.dispose();
    _customPreference.dispose();
    _startLocation.dispose();
    _airline.dispose();
    _flightCode.dispose();
    _ticketPassengerName.dispose();
    _ticketPaidAmount.dispose();
    _flightDepartTime.dispose();
    _flightDepartPlace.dispose();
    _flightLandingTime.dispose();
    _flightLandingPlace.dispose();
    super.dispose();
  }

  void _syncBudgetTextState() {
    final hasText = _budget.text.trim().isNotEmpty;
    setState(() => _hasBudgetText = hasText);
  }

  Future<void> _loadDeviceContext() async {
    final context = await _deviceContextService.load();
    if (!mounted) return;
    final oldToday = _today();
    final newToday = context.today;
    setState(() {
      _deviceContext = context;
      _tripStartLocation ??= TripStartLocation.fromContext(context);
      if (_tripStartLocation?.isCurrentLocation == true &&
          _startLocation.text.trim().isEmpty) {
        _startLocation.text = 'Finding nearby address...';
      }
      if (_startDate.difference(oldToday).inDays == 0 &&
          _endDate.difference(oldToday).inDays == 5) {
        _startDate = newToday;
        _endDate = newToday.add(const Duration(days: 5));
      }
    });
    final start = _tripStartLocation;
    if (start?.isCurrentLocation == true &&
        start!.hasCoordinates &&
        start.address == null &&
        _startLocation.text.trim() == 'Finding nearby address...') {
      unawaited(_resolveCurrentStartLocationAddress(start));
    }
  }

  void _watchPreviewJobs() {
    _previewJobSubscription = _previewJobs
        .watchRecentJobs(widget.accountId)
        .listen(
          (jobs) => unawaited(_handlePreviewJobs(jobs)),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              if (_activePreviewJobId != null) {
                _isPreparingPreview = false;
                _isGenerating = false;
                _formError = 'Could not sync the itinerary preview job.';
              }
            });
          },
        );
  }

  void _watchPlannerSession() {
    _plannerSessionSubscription = _plannerSessions
        .watchCurrentSession(widget.accountId)
        .listen(
          (session) {
            if (!mounted || _plannerSessionLoaded) return;
            _plannerSessionLoaded = true;
            if (_hasLocalPlannerSessionChanges) return;
            if (_chatMessages.isNotEmpty || _pendingDraft != null) return;
            if (session == null || session.isEmpty) return;
            _suppressPlannerSessionSave = true;
            setState(() {
              _chatMessages
                ..clear()
                ..addAll(session.messages);
              _pendingDraft = session.pendingDraft;
              _pendingDraftConfirmed = session.pendingDraftConfirmed;
              if (_currencyOptions.contains(session.currency)) {
                _currency = session.currency;
              }
            });
            _suppressPlannerSessionSave = false;
          },
          onError: (_) {
            _plannerSessionLoaded = true;
          },
        );
  }

  void _schedulePlannerSessionSave() {
    if (_suppressPlannerSessionSave) return;
    _hasLocalPlannerSessionChanges = true;
    _plannerSessionSaveTimer?.cancel();
    _plannerSessionSaveTimer = Timer(
      const Duration(milliseconds: 450),
      _savePlannerSessionNow,
    );
  }

  Future<void> _savePlannerSessionNow() async {
    if (_suppressPlannerSessionSave) return;
    final session = CreateTripPlannerSession(
      messages: _chatMessages.take(40).toList(),
      pendingDraft: _pendingDraft,
      pendingDraftConfirmed: _pendingDraftConfirmed,
      currency: _currency,
    );
    try {
      if (session.isEmpty) {
        await _plannerSessions.clearCurrentSession(widget.accountId);
      } else {
        await _plannerSessions.saveCurrentSession(widget.accountId, session);
      }
    } catch (_) {}
  }

  Future<void> _clearPlannerSession() async {
    _plannerSessionSaveTimer?.cancel();
    _suppressPlannerSessionSave = true;
    _hasLocalPlannerSessionChanges = false;
    try {
      await _plannerSessions.clearCurrentSession(widget.accountId);
    } catch (_) {
    } finally {
      _suppressPlannerSessionSave = false;
    }
  }

  Future<void> _handlePreviewJobs(List<TripPreviewJob> jobs) async {
    if (!mounted || jobs.isEmpty) return;
    final job = _previewJobToDisplay(jobs);
    if (job == null) {
      if (_activePreviewJobId == null) return;
      setState(() {
        _activePreviewJobId = null;
        _isPreparingPreview = false;
        _isGenerating = false;
        _formError =
            'The itinerary preview is taking too long. Try previewing again.';
      });
      return;
    }
    if (job.isActive) {
      setState(() {
        _activePreviewJobId = job.id;
        _isPreparingPreview = true;
        _isGenerating = true;
        _formError = null;
      });
      return;
    }

    if (job.status == TripPreviewJobStatus.failed) {
      if (_activePreviewJobId != job.id) return;
      setState(() {
        _isPreparingPreview = false;
        _isGenerating = false;
        _activePreviewJobId = null;
        _pendingAiTripPreview = null;
        _formError =
            job.errorMessage ??
            'AI could not finish the itinerary preview. Please try again.';
      });
      return;
    }

    if (!job.isReady) return;
    final preview = _pendingPreviewFromJob(job);
    if (preview == null) return;
    setState(() {
      _activePreviewJobId = null;
      _isPreparingPreview = false;
      _isGenerating = false;
      _formError = null;
      _pendingAiTripPreview = preview;
    });
  }

  TripPreviewJob? _previewJobToDisplay(List<TripPreviewJob> jobs) {
    final activeJobId = _activePreviewJobId;
    if (activeJobId != null) {
      final matching = jobs.where((job) => job.id == activeJobId).toList();
      if (matching.isNotEmpty) {
        final job = matching.first;
        if (job.isReady || job.status == TripPreviewJobStatus.failed) {
          return job;
        }
        if (job.isActive && !_isStalePreviewJob(job)) return job;
      }
    }

    final ready = jobs.where((job) => job.isReady).toList();
    if (ready.isNotEmpty) return ready.first;

    final active = jobs
        .where((job) => job.isActive && !_isStalePreviewJob(job))
        .toList();
    if (active.isNotEmpty) return active.first;

    final failed = jobs.where(
      (job) => job.status == TripPreviewJobStatus.failed,
    );
    return failed.isEmpty ? null : failed.first;
  }

  bool _isStalePreviewJob(TripPreviewJob job) {
    final createdAt = job.createdAt;
    if (createdAt == null) return false;
    return _travelAgentNow().difference(createdAt).inMinutes >= 3;
  }

  _PendingAiTripPreview? _pendingPreviewFromJob(TripPreviewJob job) {
    final place = job.place;
    final startDate = job.startDate;
    final endDate = job.endDate;
    final plan = job.plan;
    if (place == null || startDate == null || endDate == null || plan == null) {
      return null;
    }
    return _PendingAiTripPreview(
      place: place,
      startDate: startDate,
      endDate: endDate,
      budget: job.budget,
      currency: job.currency,
      groupType: job.groupType,
      preferences: job.preferences,
      plan: plan,
      startLocation: job.startLocation,
      images: job.images,
      jobId: job.id,
    );
  }

  DateTime _today() {
    final value = _deviceContext?.today ?? _travelAgentNow();
    return DateTime(value.year, value.month, value.day);
  }

  void _scheduleOriginSearch(String value) {
    _originSearchTimer?.cancel();
    setState(() {
      _selectedOriginPlace = null;
      _tripStartLocation = null;
      _formError = null;
      _isOriginSearching = value.trim().length >= 3;
      if (value.trim().isEmpty) _originSuggestions = const [];
    });
    _originSearchTimer = Timer(
      const Duration(milliseconds: 450),
      () => _searchOrigins(value),
    );
  }

  Future<void> _searchOrigins(String value) async {
    final query = value.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _isOriginSearching = false;
        _originSuggestions = const [];
      });
      return;
    }

    try {
      final suggestions = await _places.searchDestinations(query);
      if (!mounted || _startLocation.text.trim() != query) return;
      setState(() {
        _originSuggestions = suggestions;
        _isOriginSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isOriginSearching = false;
        _originSuggestions = const [];
        _formError =
            'Start location search is unavailable. You can still type a starting point.';
      });
    }
  }

  void _selectOriginPlace(PlaceSuggestion place) {
    setState(() {
      _selectedOriginPlace = place;
      _tripStartLocation = TripStartLocation.fromPlace(place);
      _startLocation.text = _tripStartLocation!.displayLabel;
      _originSuggestions = const [];
      _formError = null;
    });
  }

  Future<void> _useCurrentStartLocation() async {
    setState(() {
      _isOriginSearching = true;
      _formError = null;
      _selectedOriginPlace = null;
      _originSuggestions = const [];
      _tripStartLocation = null;
      _startLocation.text = 'Finding your location...';
    });
    final status = await _deviceContextService.enableLocationAccess();
    if (!mounted) return;
    if (status != AppLocationAccessStatus.granted) {
      setState(() {
        _isOriginSearching = false;
        _tripStartLocation = null;
        _formError = switch (status) {
          AppLocationAccessStatus.denied =>
            'Location permission was denied. Turn it on or type a starting place.',
          AppLocationAccessStatus.deniedForever =>
            'Android will not show the permission popup again. App settings opened.',
          AppLocationAccessStatus.serviceDisabled =>
            'Turn on device location services, then try again.',
          AppLocationAccessStatus.granted => null,
        };
        _startLocation.clear();
      });
      return;
    }

    final context = await _deviceContextService.loadCurrentLocation();
    if (!mounted) return;
    final start = TripStartLocation.fromContext(context);
    setState(() {
      _deviceContext = context;
      if (start == null) {
        _isOriginSearching = false;
        _tripStartLocation = null;
        _startLocation.text = 'Location unavailable';
        _formError =
            'Location access is on, but the phone has not returned coordinates yet. Try again or type a starting place.';
      } else {
        _tripStartLocation = TripStartLocation(
          label: 'Current location',
          latitude: start.latitude,
          longitude: start.longitude,
          isCurrentLocation: true,
        );
        _startLocation.text = 'Finding nearby address...';
      }
    });
    if (start == null) return;

    await _resolveCurrentStartLocationAddress(_tripStartLocation!);
  }

  Future<void> _resolveCurrentStartLocationAddress(
    TripStartLocation start,
  ) async {
    if (!start.hasCoordinates) return;

    PlaceSuggestion? resolvedPlace;
    try {
      resolvedPlace = await _places
          .reverseLocation(
            latitude: start.latitude!,
            longitude: start.longitude!,
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (!mounted) return;

    setState(() {
      _isOriginSearching = false;
      if (resolvedPlace == null ||
          resolvedPlace.formatted.trim().isEmpty ||
          resolvedPlace.formatted == 'Unknown place') {
        _tripStartLocation = start;
        _startLocation.text = '';
        _formError =
            'Could not resolve an address for your location. Try again or type the starting address.';
        return;
      }

      _selectedOriginPlace = resolvedPlace;
      _tripStartLocation = TripStartLocation(
        label: resolvedPlace.formatted,
        address: resolvedPlace.formatted,
        latitude: start.latitude,
        longitude: start.longitude,
        isCurrentLocation: true,
      );
      _startLocation.text = resolvedPlace.formatted;
      _formError = null;
    });
  }

  TripStartLocation? _startLocationForGeneration(
    AppDeviceContext generationContext,
  ) {
    final existing = _tripStartLocation;
    if (existing?.isCurrentLocation == true) return existing;
    if (_selectedOriginPlace != null) {
      return TripStartLocation.fromPlace(_selectedOriginPlace!);
    }
    if (existing != null) return existing;
    final typed = _startLocation.text.trim();
    if (typed.isNotEmpty) return TripStartLocation(label: typed);
    return TripStartLocation.fromContext(generationContext);
  }

  Future<TripStartLocation?> _startLocationWithResolvedAddress(
    TripStartLocation? startLocation,
  ) async {
    final start = startLocation;
    if (start == null || !start.hasCoordinates) return start;
    if (start.address != null && start.address!.trim().isNotEmpty) {
      return start;
    }

    try {
      final resolvedPlace = await _places
          .reverseLocation(
            latitude: start.latitude!,
            longitude: start.longitude!,
          )
          .timeout(const Duration(seconds: 5));
      if (resolvedPlace == null) return start;
      return TripStartLocation(
        label: resolvedPlace.name,
        address: resolvedPlace.formatted,
        latitude: start.latitude,
        longitude: start.longitude,
        isCurrentLocation: start.isCurrentLocation,
      );
    } catch (_) {
      return start;
    }
  }

  bool _canReplaceStartLocationText() {
    final text = _startLocation.text.trim();
    return text.isEmpty ||
        text == 'Current location' ||
        text == 'Finding nearby address...' ||
        text == 'Finding your location...';
  }

  void _schedulePlaceSearch(String value) {
    _searchTimer?.cancel();
    setState(() {
      _selectedPlace = null;
      _formError = null;
      _isSearching = value.trim().length >= 3;
    });
    _searchTimer = Timer(
      const Duration(milliseconds: 450),
      () => _searchPlaces(value),
    );
  }

  Future<void> _searchPlaces(String value) async {
    final query = value.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _placeSuggestions = const [];
      });
      return;
    }

    try {
      final suggestions = await _places.searchDestinations(query);
      if (!mounted || _destination.text.trim() != query) return;
      setState(() {
        _placeSuggestions = suggestions;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _placeSuggestions = const [];
        _formError =
            'Place search is unavailable. You can still generate using the destination you typed.';
      });
    }
  }

  void _selectPlace(PlaceSuggestion place) {
    setState(() {
      _selectedPlace = place;
      _destination.text = place.name;
      _placeSuggestions = const [];
      _formError = null;
    });
  }

  Future<void> _pickDateRange() async {
    final today = _today();
    final firstDate = DateTime(today.year, today.month, today.day);
    final initialStart = _startDate.isBefore(firstDate)
        ? firstDate
        : _startDate;
    final initialEnd = _endDate.isBefore(initialStart)
        ? initialStart.add(const Duration(days: 4))
        : _endDate;
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: _roundedDateRangePickerBuilder,
    );
    if (range == null) return;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      _formError = null;
    });
  }

  void _togglePreference(String preference) {
    setState(() {
      if (_preferences.contains(preference)) {
        _preferences.remove(preference);
      } else {
        _preferences.add(preference);
      }
      _formError = null;
    });
  }

  void _addCustomPreference() {
    final tag = _customPreference.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      _preferences.add(tag);
      _customPreference.clear();
      _formError = null;
    });
  }

  void _togglePlanningGoal(String id) {
    setState(() {
      if (_planningGoalIds.contains(id)) {
        _planningGoalIds.remove(id);
      } else {
        _planningGoalIds.add(id);
      }
      _formError = null;
    });
  }

  List<PlanningGoal> get _selectedPlanningGoals => _planningGoals
      .where((goal) => _planningGoalIds.contains(goal.id))
      .toList();

  List<String> get _aiGenerationPreferences => [
    ..._preferences,
    ..._selectedPlanningGoals.map((goal) => goal.prompt),
  ];

  List<String> get _savedTripPreferences => [
    ..._preferences,
    ..._selectedPlanningGoals.map((goal) => goal.tag),
  ];

  List<String> get _visiblePreferenceOptions {
    final options = [..._preferenceOptions];
    for (final preference in _preferences) {
      final alreadyVisible = options.any(
        (option) => option.toLowerCase() == preference.toLowerCase(),
      );
      if (!alreadyVisible) options.add(preference);
    }
    return options;
  }

  Future<void> _showImagePicker() async {
    final image = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              margin: EdgeInsets.all(_responsiveHorizontalPadding(context)),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SizedBox(
                height: math.min(MediaQuery.sizeOf(context).height * .7, 520),
                child: GridView.builder(
                  itemCount: _galleryOptions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width < 380
                        ? 1
                        : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final option = _galleryOptions[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(option),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          option,
                          fit: BoxFit.cover,
                          filterQuality: PerformanceScope.maybeSettingsOf(
                            context,
                          ).filterQuality,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (image == null) return;
    setState(() => _selectedImage = image);
  }

  void _startAiChat() {
    setState(() {
      _mode = 3;
      _formError = null;
    });
  }

  void _closeAiChatPlanner() {
    _plannerSessionSaveTimer?.cancel();
    if (_chatMessages.isNotEmpty || _pendingDraft != null) {
      _hasLocalPlannerSessionChanges = true;
      unawaited(_savePlannerSessionNow());
    }
    setState(() => _mode = 0);
  }

  Future<void> _resetCreateTripChat() async {
    _plannerSessionSaveTimer?.cancel();
    setState(() {
      _chatMessages.clear();
      _pendingDraft = null;
      _pendingDraftConfirmed = false;
      _pendingAiTripPreview = null;
      _isThinking = false;
      _formError = null;
      _lastAiError = null;
    });
    await _clearPlannerSession();
  }

  Future<void> _sendCreateTripChat([String? value]) async {
    var text = (value ?? _chatInput.text).trim();
    if (text == _customDateRangeValue) {
      final rangeText = await _pickCreateTripChatDateRange();
      if (rangeText == null) return;
      text = rangeText;
    }
    if (text.isEmpty || _isThinking || _isGenerating) return;

    _chatInput.clear();

    if (_pendingDraft != null &&
        RegExp(
          r'^(confirm|confirmed|approve|approved|yes|use it|looks good)$',
          caseSensitive: false,
        ).hasMatch(text)) {
      setState(() {
        _pendingDraftConfirmed = true;
        _chatMessages.add(CreateTripChatMessage(fromUser: true, text: text));
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text: 'Confirmed. I will use this draft for the schedule.',
          ),
        );
      });
      _schedulePlannerSessionSave();
      return;
    }

    setState(() {
      _isThinking = true;
      _pendingDraftConfirmed = false;
      _pendingAiTripPreview = null;
      _chatMessages.add(CreateTripChatMessage(fromUser: true, text: text));
    });
    _schedulePlannerSessionSave();

    CreateTripAiResponse aiResponse;
    try {
      aiResponse = await _assistant
          .createTripReply(
            message: text,
            currentDraft: _currentChatDraftForAi(),
            history: _chatMessages,
            profileLanguage: widget.profileLanguage,
          )
          .timeout(_createTripChatTurnTimeout);
      final rawDraft = aiResponse.draft;
      final protectedDraft = _protectDraftCurrency(rawDraft, text);
      aiResponse = CreateTripAiResponse(
        message: _protectBudgetReplyMessage(
          aiResponse.message,
          rawDraft: rawDraft,
          protectedDraft: protectedDraft,
          userText: text,
        ),
        draft: protectedDraft,
        widget: aiResponse.widget,
      );
      _lastAiError = null;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _lastAiError = _friendlyAiError(error);
        _chatMessages.add(
          CreateTripChatMessage(fromUser: false, text: _lastAiError!),
        );
      });
      _schedulePlannerSessionSave();
      return;
    }

    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _pendingDraft = aiResponse.draft;
      _pendingAiTripPreview = null;
      final currency = aiResponse.draft.currency;
      if (currency != null) _currency = currency;
      _chatMessages.add(
        CreateTripChatMessage(
          fromUser: false,
          text: _lastAiError == null
              ? aiResponse.message
              : '${_lastAiError!}\n\n${aiResponse.message}',
          widget: aiResponse.widget,
        ),
      );
    });
    _schedulePlannerSessionSave();
  }

  CreateTripDraft _currentChatDraftForAi() {
    return (_pendingDraft ?? const CreateTripDraft()).copyWith(
      currency: _currency,
    );
  }

  CreateTripDraft _protectDraftCurrency(CreateTripDraft draft, String text) {
    final explicitCurrency = _currencyFromText(text);
    final selectedCurrency = explicitCurrency ?? _currency;
    return draft.copyWith(currency: selectedCurrency);
  }

  String _protectBudgetReplyMessage(
    String message, {
    required CreateTripDraft rawDraft,
    required CreateTripDraft protectedDraft,
    required String userText,
  }) {
    if (_currencyFromText(userText) != null) return message;
    final rawCurrency = rawDraft.currency;
    final protectedCurrency = protectedDraft.currency;
    if (rawCurrency == null ||
        protectedCurrency == null ||
        rawCurrency == protectedCurrency) {
      return message;
    }
    return message.replaceAll(
      RegExp('\\b${RegExp.escape(rawCurrency)}\\b'),
      protectedCurrency,
    );
  }

  void _setCreateChatCurrency(String currency) {
    setState(() {
      _currency = currency;
      _pendingDraft = (_pendingDraft ?? const CreateTripDraft()).copyWith(
        currency: currency,
      );
      _pendingAiTripPreview = null;
    });
    _schedulePlannerSessionSave();
  }

  Future<String?> _pickCreateTripChatDateRange() async {
    final today = _today();
    final firstDate = DateTime(today.year, today.month, today.day);
    final draft = _pendingDraft;
    final initialStart = draft?.startDate ?? _startDate;
    final safeStart = initialStart.isBefore(firstDate)
        ? firstDate
        : initialStart;
    final initialEnd = draft?.endDate ?? _endDate;
    final safeEnd = initialEnd.isBefore(safeStart)
        ? safeStart.add(const Duration(days: 4))
        : initialEnd;
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      builder: _roundedDateRangePickerBuilder,
    );
    if (range == null) return null;
    return '${_dateKey(range.start)} to ${_dateKey(range.end)}';
  }

  Widget _roundedDateRangePickerBuilder(BuildContext context, Widget? child) {
    final base = TravelAgentTheme.light();
    const primary = Color(0xFF355872);
    const onSurface = Color(0xFF243B4D);
    const surface = Color(0xFFF8FAFC);
    final scheme = base.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: const Color(0xFFEAF3FA),
      outline: const Color(0xFF9CB6C9),
      outlineVariant: const Color(0xFFD4E2EC),
    );
    return Theme(
      data: base.copyWith(
        brightness: Brightness.light,
        colorScheme: scheme,
        scaffoldBackgroundColor: surface,
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: primary),
        ),
        datePickerTheme: base.datePickerTheme.copyWith(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: surface,
          headerForegroundColor: primary,
          rangePickerBackgroundColor: surface,
          rangePickerHeaderBackgroundColor: surface,
          rangePickerHeaderForegroundColor: primary,
          rangePickerShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          weekdayStyle: const TextStyle(
            color: Color(0xFF607D92),
            fontWeight: FontWeight.w800,
          ),
          dayStyle: const TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w700,
          ),
          yearStyle: const TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w700,
          ),
          rangeSelectionBackgroundColor: const Color(
            0xFF9FC3DA,
          ).withValues(alpha: .52),
          rangeSelectionOverlayColor: WidgetStatePropertyAll(
            primary.withValues(alpha: .12),
          ),
          dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF9AA8B2);
            }
            return onSurface;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return null;
          }),
          todayForegroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : primary,
          ),
          todayBorder: const BorderSide(color: primary, width: 1.4),
          yearForegroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : onSurface,
          ),
          yearBackgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected) ? primary : null,
          ),
          dayShape: WidgetStateProperty.resolveWith<OutlinedBorder?>((states) {
            if (states.contains(WidgetState.selected)) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              );
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              );
            }
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            );
          }),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  String _friendlyAiError(Object error) {
    final text = error.toString();
    if (error is TimeoutException ||
        text.contains('TimeoutException') ||
        text.contains('deadline-exceeded') ||
        text.contains('DEADLINE_EXCEEDED') ||
        text.contains('AI itinerary generation failed')) {
      return 'AI took longer than expected to build the itinerary. Please try again, or use Preview Itinerary so it can finish in the background.';
    }
    if (text.contains('not-found') ||
        text.contains('NOT_FOUND') ||
        text.contains('failed-precondition') ||
        text.contains('SERVICE_DISABLED')) {
      return 'AI is not connected yet. Set the Firebase Function secrets and deploy Functions, or run Flutter with an OPENAI_API_KEY dart define.';
    }
    if (text.contains('unauthenticated') ||
        text.contains('permission-denied')) {
      return 'AI could not be reached because the backend rejected the request.';
    }
    return 'AI is unavailable right now. Please try again.';
  }

  // ignore: unused_element
  CreateTripDraft _parseTripDraft(String text, CreateTripDraft? current) {
    final lower = text.toLowerCase();
    final draft = (current ?? const CreateTripDraft()).copyWith();

    String? destination = draft.destination;
    final destinationMatch =
        RegExp(
          r'(?:to|in|for)\s+([A-Za-z][A-Za-z\s.,-]+?)(?:\s+(?:from|on|with|for|under|budget|solo|family|friends|tour)|[.!?]|$)',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'^(?:plan\s+)?(?:a\s+)?(?:trip\s+)?([A-Za-z][A-Za-z\s.,-]{2,50})(?:\s+\d|\s+for|\s+with|[.!?]|$)',
          caseSensitive: false,
        ).firstMatch(text);
    if (destinationMatch != null) {
      final candidate = destinationMatch.group(1)?.trim().replaceAll(',', '');
      if (_normalCurrencyCode(candidate) == null) {
        destination = candidate;
      }
    }

    String? groupType = draft.groupType;
    if (lower.contains('solo')) groupType = 'Solo';
    if (lower.contains('friend')) groupType = 'Friends';
    if (lower.contains('family')) groupType = 'Family';
    if (lower.contains('tour')) groupType = 'Tour';

    final currency = _currencyFromText(text) ?? _currency;
    String? budget = draft.budget;
    final currencyAmount = _currencyAmountFromText(text);
    if (currencyAmount != null) {
      budget = _budgetInCurrency(
        amount: currencyAmount.amount,
        fromCurrency: currencyAmount.currency,
        toCurrency: currency,
      ).toString();
    }

    final budgetMatch = RegExp(
      r'\$\s?(\d{1,7}(?:[,.]\d{3})*|\d{1,7})\s*([kK])?|(?:budget|under|around|about|maybe|roughly)\D{0,12}(\d{1,7}(?:[,.]\d{3})*|\d{1,7})\s*([kK])?|(\d{1,7}(?:[,.]\d{3})*|\d{1,7})\s*([kK])?\s?(?:usd|dollars?)',
      caseSensitive: false,
    ).firstMatch(text);
    budget =
        _amountMatchToBudget(budgetMatch, const [(1, 2), (3, 4), (5, 6)]) ??
        budget;
    _currency = currency;

    DateTime? startDate = draft.startDate;
    DateTime? endDate = draft.endDate;
    final isoRangeMatch = RegExp(
      r'(\d{4}-\d{2}-\d{2})\s*(?:-|to|until|through)\s*(\d{4}-\d{2}-\d{2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (isoRangeMatch != null) {
      startDate = _parseIsoDate(isoRangeMatch.group(1));
      endDate = _parseIsoDate(isoRangeMatch.group(2));
    }

    final rangeMatch = RegExp(
      r'(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?\s*(?:-|to|until|through)\s*(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (rangeMatch != null && (startDate == null || endDate == null)) {
      final year = _fullYear(rangeMatch.group(3) ?? rangeMatch.group(6));
      final endYear = _fullYear(rangeMatch.group(6) ?? rangeMatch.group(3));
      startDate = _dateFromNumericParts(
        year,
        int.parse(rangeMatch.group(1)!),
        int.parse(rangeMatch.group(2)!),
      );
      endDate = _dateFromNumericParts(
        endYear,
        int.parse(rangeMatch.group(4)!),
        int.parse(rangeMatch.group(5)!),
      );
    }

    final durationMatch = RegExp(
      r'\b(\d{1,2})\s*(?:days?|nights?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (durationMatch != null &&
        lower.contains('tomorrow') &&
        (startDate == null || endDate == null)) {
      final duration = math.max(1, int.parse(durationMatch.group(1)!));
      final today = _today();
      startDate = today.add(const Duration(days: 1));
      endDate = startDate.add(Duration(days: duration - 1));
    }

    final preferenceAdds = <String>{...draft.preferences};
    for (final option in _preferenceOptions) {
      if (lower.contains(option.toLowerCase())) preferenceAdds.add(option);
    }
    if (lower.contains('cheap') || lower.contains('budget')) {
      preferenceAdds.add('Budget-friendly');
    }

    return draft.copyWith(
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currency: currency,
      groupType: groupType,
      preferences: preferenceAdds.toList(),
    );
  }

  ({int amount, String currency})? _currencyAmountFromText(String text) {
    final match = RegExp(
      r'(?:\b(idr|rp|rupiah|twd|ntd|nt\$|nt|usd|dollars?|jpy|yen|eur|euros?)\b\s*([0-9][0-9,._]*)\s*([kK])?)|(?:([0-9][0-9,._]*)\s*([kK])?\s*\b(idr|rp|rupiah|twd|ntd|nt\$|nt|usd|dollars?|jpy|yen|eur|euros?)\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final currency = _normalCurrencyCode(match.group(1) ?? match.group(6));
    final amount = _parseCompactAmount(
      match.group(2) ?? match.group(4),
      match.group(3) ?? match.group(5),
    );
    if (currency == null || amount == null) return null;
    return (amount: amount, currency: currency);
  }

  String? _amountMatchToBudget(
    RegExpMatch? match,
    List<(int amountGroup, int suffixGroup)> groups,
  ) {
    if (match == null) return null;
    for (final group in groups) {
      final amount = _parseCompactAmount(
        match.group(group.$1),
        match.group(group.$2),
      );
      if (amount != null && amount > 0) return amount.toString();
    }
    return null;
  }

  int? _parseCompactAmount(String? value, String? suffix) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final amount = int.tryParse(digits);
    if (amount == null) return null;
    return suffix?.toLowerCase() == 'k' ? amount * 1000 : amount;
  }

  String? _currencyFromText(String text) {
    final match = RegExp(
      r'\b(idr|rupiah|rp|twd|ntd|nt\$|nt|usd|dollars?|jpy|yen|eur|euros?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return _normalCurrencyCode(match?.group(1));
  }

  int _budgetInCurrency({
    required int amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return amount;
    if (fromCurrency == 'TWD' && toCurrency == 'IDR') {
      return (amount * _twdToIdrFallbackRate).round();
    }
    if (fromCurrency == 'IDR' && toCurrency == 'TWD') {
      return (amount / _twdToIdrFallbackRate).round();
    }
    return amount;
  }

  // ignore: unused_element
  String? _conversionMessage(String text, CreateTripDraft draft) {
    final source = _currencyAmountFromText(text);
    final target = draft.currency;
    final budget = int.tryParse((draft.budget ?? '').replaceAll(',', ''));
    if (source == null || target == null || budget == null) return null;
    if (source.currency == target) return null;
    return '${source.currency} ${_formatWholeNumber(source.amount)} is about '
        '$target ${_formatWholeNumber(budget)}. I added that as your trip budget.';
  }

  int _fullYear(String? value) {
    final year = int.tryParse(value ?? '') ?? _today().year;
    return year < 100 ? 2000 + year : year;
  }

  DateTime _dateFromNumericParts(int year, int first, int second) {
    final month = second > 12 && first <= 12 ? first : second;
    final day = second > 12 && first <= 12 ? second : first;
    return DateTime(year, month, day);
  }

  List<String> _missingDraftFields(CreateTripDraft draft) {
    final missing = <String>[];
    if ((draft.destination ?? '').trim().isEmpty) missing.add('destination');
    if (draft.startDate == null || draft.endDate == null) missing.add('dates');
    if ((draft.budget ?? '').trim().isEmpty) missing.add('total budget');
    if ((draft.groupType ?? '').trim().isEmpty) missing.add('who is coming');
    return missing;
  }

  String _questionForMissingField(String field) {
    switch (field) {
      case 'destination':
        return 'Where would you like to go? Pick one or type your own.';
      case 'dates':
        return 'Choose a suggested date range or pick exact dates.';
      case 'total budget':
        return 'What total budget should I plan around in $_currency?';
      case 'who is coming':
        return 'Who is coming with you: Solo, Friends, Family, or Tour?';
      default:
        return 'Tell me one more detail for the trip.';
    }
  }

  // ignore: unused_element
  CreateTripChoiceWidget? _fallbackWidgetForMissingField(String? field) {
    switch (field) {
      case 'destination':
        return const CreateTripChoiceWidget(
          title: 'Popular starting points',
          options: [
            CreateTripChoiceOption(
              label: 'Kyoto',
              value: 'Kyoto, Japan',
              description: 'Culture, temples, food streets',
            ),
            CreateTripChoiceOption(
              label: 'Tokyo',
              value: 'Tokyo, Japan',
              description: 'City energy, shopping, day trips',
            ),
            CreateTripChoiceOption(
              label: 'Bali',
              value: 'Bali, Indonesia',
              description: 'Beaches, villas, relaxed pace',
            ),
          ],
        );
      case 'dates':
        return CreateTripChoiceWidget(
          title: 'Suggested dates',
          options: _fallbackDateChoiceOptions(),
        );
      case 'total budget':
        return CreateTripChoiceWidget(
          title: 'Total budget',
          options: _budgetChoiceOptionsForCurrentDraft(),
        );
      case 'who is coming':
        return const CreateTripChoiceWidget(
          title: 'Travel party',
          options: [
            CreateTripChoiceOption(
              label: 'Solo',
              value: 'Solo',
              description: 'Personal route and pace',
            ),
            CreateTripChoiceOption(
              label: 'Friends',
              value: 'Friends',
              description: 'Shared plans and votes',
            ),
            CreateTripChoiceOption(
              label: 'Family',
              value: 'Family',
              description: 'Comfortable timing',
            ),
          ],
        );
      default:
        return null;
    }
  }

  List<CreateTripChoiceOption> _fallbackDateChoiceOptions() {
    final today = _today();
    final destination = (_pendingDraft?.destination ?? _destination.text)
        .toLowerCase();
    final international =
        destination.isNotEmpty &&
        !_containsAnyText(destination, const [
          'taiwan',
          'taipei',
          'hsinchu',
          'taichung',
          'tainan',
          'kaohsiung',
        ]);
    final suggestions = international
        ? [
            (
              label: 'Flight-friendly week',
              start: _nextSeasonalHolidayStart(today),
              days: 6,
              description: 'More buffer for flights and arrival timing',
            ),
            (
              label: 'Longer holiday',
              start: _nextSeasonalHolidayStart(
                today.add(const Duration(days: 14)),
              ),
              days: 8,
              description: 'Slower pace with recovery time',
            ),
            (
              label: 'Compact escape',
              start: _nextWeekday(
                today.add(const Duration(days: 14)),
                DateTime.friday,
              ),
              days: 4,
              description: 'Shorter trip with efficient routing',
            ),
          ]
        : [
            (
              label: 'Nearest weekend',
              start: _nextWeekday(today, DateTime.saturday),
              days: 2,
              description: 'Quick nearby trip',
            ),
            (
              label: 'Easy 3-day loop',
              start: _nextWeekday(today, DateTime.friday),
              days: 3,
              description: 'Relaxed timing with one extra day',
            ),
            (
              label: 'Balanced local trip',
              start: _nextLongWeekendStart(today),
              days: 4,
              description: 'More room for food and sightseeing',
            ),
          ];
    return [
      for (final suggestion in suggestions)
        CreateTripChoiceOption(
          label: suggestion.label,
          value:
              '${_dateKey(suggestion.start)} to ${_dateKey(suggestion.start.add(Duration(days: suggestion.days - 1)))}',
          description: suggestion.description,
        ),
      const CreateTripChoiceOption(
        label: 'Pick exact dates',
        value: _customDateRangeValue,
        description: 'Open the calendar',
      ),
    ];
  }

  List<({String currency, int amount, String description})>
  _budgetOptionsForCurrency(String currency) {
    final destination = _pendingDraft?.destination ?? _destination.text;
    final days = _budgetEstimateDays();
    final tiers = _usdBudgetTiersForDestination(destination, days);
    return [
      (
        currency: currency,
        amount: _usdBudgetTierToCurrency(tiers.lean, currency),
        description: '${days}d lean stays, local food, public transit',
      ),
      (
        currency: currency,
        amount: _usdBudgetTierToCurrency(tiers.mid, currency),
        description: '${days}d comfortable hotels and dining',
      ),
      (
        currency: currency,
        amount: _usdBudgetTierToCurrency(tiers.premium, currency),
        description: '${days}d flexible stays and experiences',
      ),
    ];
  }

  List<CreateTripChoiceOption> _budgetChoiceOptionsForCurrentDraft() {
    final options = _budgetOptionsForCurrency(_currency);
    return [
      CreateTripChoiceOption(
        label: 'Budget',
        value: 'budget ${options[0].amount} ${options[0].currency}',
        description:
            '${_formatWholeNumber(options[0].amount)} ${options[0].currency} - ${options[0].description}',
      ),
      CreateTripChoiceOption(
        label: 'Mid-range',
        value: 'budget ${options[1].amount} ${options[1].currency}',
        description:
            '${_formatWholeNumber(options[1].amount)} ${options[1].currency} - ${options[1].description}',
      ),
      CreateTripChoiceOption(
        label: 'Premium',
        value: 'budget ${options[2].amount} ${options[2].currency}',
        description:
            '${_formatWholeNumber(options[2].amount)} ${options[2].currency} - ${options[2].description}',
      ),
      const CreateTripChoiceOption(
        label: 'Custom',
        value: _customBudgetValue,
        description: 'Choose your own total budget',
      ),
    ];
  }

  int _budgetEstimateDays() {
    final draft = _pendingDraft;
    final start = draft?.startDate ?? _startDate;
    final end = draft?.endDate ?? _endDate;
    return math.max(1, end.difference(start).inDays + 1);
  }

  ({int lean, int mid, int premium}) _usdBudgetTiersForDestination(
    String? destination,
    int days,
  ) {
    final text = (destination ?? '').toLowerCase();
    final daily = _destinationDailyUsdTiers(text);
    final transport = _destinationTransportUsdBuffer(text, days);
    return (
      lean: _roundUsdBudget(daily.lean * days + transport.lean),
      mid: _roundUsdBudget(daily.mid * days + transport.mid),
      premium: _roundUsdBudget(daily.premium * days + transport.premium),
    );
  }

  ({int lean, int mid, int premium}) _destinationDailyUsdTiers(String text) {
    if (_containsAnyText(text, const ['bali', 'indonesia'])) {
      return (lean: 65, mid: 135, premium: 260);
    }
    if (_containsAnyText(text, const ['tokyo', 'kyoto', 'osaka', 'japan'])) {
      return (lean: 115, mid: 230, premium: 430);
    }
    if (_containsAnyText(text, const ['paris', 'france'])) {
      return (lean: 135, mid: 275, premium: 520);
    }
    if (_containsAnyText(text, const ['taipei', 'taiwan'])) {
      return (lean: 80, mid: 170, premium: 320);
    }
    if (_containsAnyText(text, const ['singapore'])) {
      return (lean: 130, mid: 260, premium: 500);
    }
    if (_containsAnyText(text, const ['seoul', 'korea'])) {
      return (lean: 95, mid: 200, premium: 380);
    }
    if (_containsAnyText(text, const [
      'london',
      'new york',
      'usa',
      'united states',
    ])) {
      return (lean: 160, mid: 320, premium: 620);
    }
    return (lean: 100, mid: 210, premium: 390);
  }

  ({int lean, int mid, int premium}) _destinationTransportUsdBuffer(
    String text,
    int days,
  ) {
    if (days <= 2) return (lean: 40, mid: 80, premium: 160);
    if (_containsAnyText(text, const [
      'bali',
      'japan',
      'paris',
      'france',
      'singapore',
      'korea',
      'london',
      'new york',
    ])) {
      return (lean: 250, mid: 500, premium: 900);
    }
    return (lean: 100, mid: 220, premium: 420);
  }

  int _roundUsdBudget(int amount) {
    final roundTo = amount < 1000 ? 50 : 100;
    return (amount / roundTo).round() * roundTo;
  }

  int _usdBudgetTierToCurrency(int usdAmount, String currency) {
    final rate = switch (currency) {
      'TWD' => 32.0,
      'IDR' => 16250.0,
      'JPY' => 155.0,
      'EUR' => .92,
      _ => 1.0,
    };
    final raw = usdAmount * rate;
    final roundTo = switch (currency) {
      'IDR' => 100000,
      'JPY' => 1000,
      'TWD' => 1000,
      'EUR' => 50,
      _ => 100,
    };
    return (raw / roundTo).round() * roundTo;
  }

  int _budgetPresetAmount(int index) {
    final options = _budgetOptionsForCurrency(_currency);
    final safeIndex = index.clamp(0, options.length - 1);
    return options[safeIndex].amount;
  }

  String _timingIdeaText(String prefix, int budgetIndex) {
    final amount = _formatWholeNumber(_budgetPresetAmount(budgetIndex));
    return '$prefix, $_currency $amount';
  }

  String _timingIdeaBudget(int budgetIndex) =>
      _budgetPresetAmount(budgetIndex).toString();

  List<
    ({
      IconData icon,
      String title,
      String text,
      DateTime startDate,
      int days,
      String budget,
    })
  >
  _timingPresets() {
    final today = _today();
    final destination = _selectedPlace;
    final start = _tripStartLocation;
    final distanceKm = _distanceKm(
      start?.latitude,
      start?.longitude,
      destination?.latitude,
      destination?.longitude,
    );
    final international = _isInternationalTiming(destination);
    final profile = international
        ? _TimingPresetProfile.international
        : distanceKm != null && distanceKm <= 150
        ? _TimingPresetProfile.nearby
        : _TimingPresetProfile.farDomestic;

    final leanBudget = _timingIdeaBudget(0);
    final midBudget = _timingIdeaBudget(1);

    return switch (profile) {
      _TimingPresetProfile.nearby => [
        (
          icon: Icons.flash_on_rounded,
          title: 'Nearest weekend',
          text: _timingIdeaText('2 days, nearby city break', 0),
          startDate: _nextWeekday(today, DateTime.saturday),
          days: 2,
          budget: leanBudget,
        ),
        (
          icon: Icons.route_rounded,
          title: 'Easy 3-day loop',
          text: _timingIdeaText('3 days, relaxed nearby route', 1),
          startDate: _nextWeekday(today, DateTime.friday),
          days: 3,
          budget: midBudget,
        ),
        (
          icon: Icons.savings_rounded,
          title: 'Budget weekend',
          text: _timingIdeaText('2 days, low-cost local picks', 0),
          startDate: _nextWeekday(today, DateTime.saturday),
          days: 2,
          budget: leanBudget,
        ),
      ],
      _TimingPresetProfile.farDomestic => [
        (
          icon: Icons.flash_on_rounded,
          title: 'Next long weekend',
          text: _timingIdeaText('4 days, compact domestic route', 0),
          startDate: _nextLongWeekendStart(today),
          days: 4,
          budget: leanBudget,
        ),
        (
          icon: Icons.route_rounded,
          title: 'Balanced week',
          text: _timingIdeaText('6 days with buffer time', 1),
          startDate: _nextLongWeekendStart(today.add(const Duration(days: 7))),
          days: 6,
          budget: midBudget,
        ),
        (
          icon: Icons.savings_rounded,
          title: 'Budget aware',
          text: _timingIdeaText('4 days, efficient transport', 0),
          startDate: _nextLongWeekendStart(today),
          days: 4,
          budget: leanBudget,
        ),
      ],
      _TimingPresetProfile.international => [
        (
          icon: Icons.flight_takeoff_rounded,
          title: 'Seasonal holiday',
          text: _timingIdeaText('8 days, flight-friendly window', 1),
          startDate: _nextSeasonalHolidayStart(today),
          days: 8,
          budget: midBudget,
        ),
        (
          icon: Icons.route_rounded,
          title: 'Long vacation',
          text: _timingIdeaText('10 days with recovery time', 2),
          startDate: _nextSeasonalHolidayStart(today),
          days: 10,
          budget: _timingIdeaBudget(2),
        ),
        (
          icon: Icons.savings_rounded,
          title: 'Budget holiday',
          text: _timingIdeaText('7 days, slower low-cost picks', 0),
          startDate: _nextSeasonalHolidayStart(today),
          days: 7,
          budget: leanBudget,
        ),
      ],
    };
  }

  String _formatWholeNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  String _formatNumberText(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return _formatWholeNumber(int.parse(digits));
  }

  void _setBudgetText(String value) {
    final formatted = _formatNumberText(value);
    _budget.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _budgetHintText(BuildContext context) {
    final options = _budgetOptionsForCurrency(_currency);
    final example = options.length >= 2
        ? options[1].amount
        : options.first.amount;
    return '${_formatWholeNumber(example)} ${appText(context, _currencyDisplayName(_currency))}';
  }

  String _currencyDisplayName(String currency) {
    return switch (currency) {
      'TWD' => 'New Taiwan dollars',
      'IDR' => 'Indonesian rupiah',
      'JPY' => 'Japanese yen',
      'EUR' => 'euros',
      _ => 'US dollars',
    };
  }

  bool _isInternationalTiming(PlaceSuggestion? destination) {
    final destinationCountry = destination?.country?.trim().toLowerCase();
    final originCountry = _selectedOriginPlace?.country?.trim().toLowerCase();
    if (destinationCountry != null &&
        destinationCountry.isNotEmpty &&
        originCountry != null &&
        originCountry.isNotEmpty) {
      return destinationCountry != originCountry;
    }

    final destinationText = _destination.text.toLowerCase();
    final originText = _startLocation.text.toLowerCase();
    for (final country in const [
      'taiwan',
      'japan',
      'indonesia',
      'united states',
      'usa',
      'france',
      'germany',
      'italy',
      'spain',
    ]) {
      if (destinationText.contains(country) &&
          originText.isNotEmpty &&
          !originText.contains(country)) {
        return true;
      }
    }

    return false;
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    final today = DateTime(from.year, from.month, from.day);
    var offset = (weekday - today.weekday) % DateTime.daysPerWeek;
    if (offset == 0) offset = DateTime.daysPerWeek;
    return today.add(Duration(days: offset));
  }

  DateTime _nextLongWeekendStart(DateTime from) {
    final candidate = _nextWeekday(from, DateTime.friday);
    final minimum = DateTime(
      from.year,
      from.month,
      from.day,
    ).add(const Duration(days: 10));
    return candidate.isBefore(minimum)
        ? _nextWeekday(minimum, DateTime.friday)
        : candidate;
  }

  DateTime _nextSeasonalHolidayStart(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final summer = DateTime(today.year, 7);
    final winter = DateTime(today.year, 12, 20);
    if (today.isBefore(summer)) return summer;
    if (today.isBefore(winter)) return winter;
    return DateTime(today.year + 1, 7);
  }

  double? _distanceKm(
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
  ) {
    if (originLat == null ||
        originLng == null ||
        destinationLat == null ||
        destinationLng == null ||
        destinationLat == 0 ||
        destinationLng == 0) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    final originPhi = originLat * math.pi / 180;
    final destinationPhi = destinationLat * math.pi / 180;
    final deltaPhi = (destinationLat - originLat) * math.pi / 180;
    final deltaLambda = (destinationLng - originLng) * math.pi / 180;
    final a =
        math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(originPhi) *
            math.cos(destinationPhi) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _applyDraftToForm(CreateTripDraft draft) {
    final destination = draft.destination?.trim();
    if (destination != null && destination.isNotEmpty) {
      _destination.text = destination;
      _selectedPlace = null;
    }
    final startDate = draft.startDate;
    final endDate = draft.endDate;
    if (startDate != null) _startDate = startDate;
    if (endDate != null) _endDate = endDate;
    final currency = draft.currency;
    if (currency != null && _currencyOptions.contains(currency)) {
      _currency = currency;
    }
    final budget = draft.budget?.trim();
    if (budget != null && budget.isNotEmpty) {
      _setBudgetText(_normalizedBudgetInput(budget, _currency));
    }
    final groupType = draft.groupType;
    if (groupType != null && _groupOptions.contains(groupType)) {
      _group = groupType;
    }
    _preferences
      ..clear()
      ..addAll(
        draft.preferences.isEmpty ? ['Culture', 'Food'] : draft.preferences,
      );
  }

  Future<void> _usePendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) return;
    final missing = _missingDraftFields(draft);
    if (missing.isNotEmpty) {
      setState(() {
        _chatMessages.add(
          CreateTripChatMessage(
            fromUser: false,
            text: _questionForMissingField(missing.first),
          ),
        );
      });
      return;
    }

    setState(() {
      _applyDraftToForm(draft);
    });
    await _prepareAiTripPreviewFromDraft();
  }

  Future<void> _createManualTrip() async {
    final budget = _parsedBudget();
    if (budget <= 0) {
      setState(() => _formError = 'Enter a budget greater than zero.');
      return;
    }

    final place = _manualPlaceFromInput(_destination.text.trim());
    if (place == null) {
      setState(() => _formError = 'Enter a destination.');
      return;
    }

    final generationContext = await _deviceContextService.load(
      requestLocation: _startLocation.text.trim().isEmpty,
    );
    if (!mounted) return;
    final startLocation = await _startLocationWithResolvedAddress(
      _startLocationForGeneration(generationContext),
    );
    if (!mounted) return;
    final plan = _manualStarterPlan(
      place: place,
      startLocation: startLocation,
      currency: _currency,
    );

    setState(() {
      _deviceContext = generationContext;
      _tripStartLocation = startLocation;
      if (startLocation != null && _canReplaceStartLocationText()) {
        _startLocation.text = startLocation.displayLabel;
      }
      _formError = null;
    });
    await _createTripFromPlan(
      place: place,
      budget: budget,
      plan: plan,
      startLocation: startLocation,
    );
  }

  Future<void> _editPendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) return;

    final destination = TextEditingController(text: draft.destination ?? '');
    final budget = TextEditingController(text: draft.budget ?? '');
    final customTag = TextEditingController();
    var startDate = draft.startDate ?? _startDate;
    var endDate = draft.endDate ?? _endDate;
    var groupType = draft.groupType ?? _group;
    final preferences = <String>{...draft.preferences};

    try {
      final edited = await showModalBottomSheet<CreateTripDraft>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> pickStart() async {
                final today = _today();
                final firstDate = DateTime(today.year, today.month, today.day);
                final date = await showDatePicker(
                  context: context,
                  initialDate: startDate.isBefore(firstDate)
                      ? firstDate
                      : startDate,
                  firstDate: firstDate,
                  lastDate: DateTime(2028, 12, 31),
                );
                if (date == null) return;
                setSheetState(() {
                  startDate = date;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate.add(const Duration(days: 4));
                  }
                });
              }

              Future<void> pickEnd() async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: endDate.isBefore(startDate)
                      ? startDate
                      : endDate,
                  firstDate: startDate,
                  lastDate: DateTime(2028, 12, 31),
                );
                if (date == null) return;
                setSheetState(() => endDate = date);
              }

              void addTag() {
                final tag = customTag.text.trim();
                if (tag.isEmpty) return;
                setSheetState(() {
                  preferences.add(tag);
                  customTag.clear();
                });
              }

              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: _responsiveHorizontalPadding(context),
                        right: _responsiveHorizontalPadding(context),
                        top: 16,
                        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const IconBadge(
                                    icon: Icons.tune_rounded,
                                    size: 42,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      appText(context, 'Customize AI Draft'),
                                      style: const TextStyle(
                                        color: _primary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: destination,
                                decoration: InputDecoration(
                                  labelText: appText(context, 'Destination'),
                                  prefixIcon: const Icon(Icons.place_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ResponsiveSplit(
                                children: [
                                  DraftEditButton(
                                    label: 'Start',
                                    value: _dateKey(startDate),
                                    onTap: pickStart,
                                  ),
                                  DraftEditButton(
                                    label: 'End',
                                    value: _dateKey(endDate),
                                    onTap: pickEnd,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: budget,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: appText(context, 'Total budget'),
                                  prefixText: '\$ ',
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: groupType,
                                decoration: InputDecoration(
                                  labelText: appText(context, 'Who is coming'),
                                ),
                                items:
                                    const ['Solo', 'Family', 'Friends', 'Tour']
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(appText(context, item)),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) => setSheetState(
                                  () => groupType = value ?? groupType,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const LabelText('Trip tags'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final option in _preferenceOptions)
                                    FilterChip(
                                      selected: preferences.contains(option),
                                      label: Text(appText(context, option)),
                                      onSelected: (_) => setSheetState(() {
                                        preferences.contains(option)
                                            ? preferences.remove(option)
                                            : preferences.add(option);
                                      }),
                                    ),
                                  for (final tag in preferences.where(
                                    (tag) => !_preferenceOptions.contains(tag),
                                  ))
                                    InputChip(
                                      label: Text(appText(context, tag)),
                                      onDeleted: () => setSheetState(
                                        () => preferences.remove(tag),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: customTag,
                                      decoration: InputDecoration(
                                        labelText: appText(
                                          context,
                                          'Add custom tag',
                                        ),
                                      ),
                                      onSubmitted: (_) => addTag(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      fixedSize: const Size(54, 54),
                                    ),
                                    onPressed: addTag,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              PrimaryButton(
                                label: 'Save draft edits',
                                icon: Icons.check_rounded,
                                onPressed: () => Navigator.of(context).pop(
                                  CreateTripDraft(
                                    destination: destination.text.trim(),
                                    startDate: startDate,
                                    endDate: endDate,
                                    budget: budget.text
                                        .replaceAll(RegExp(r'\D'), '')
                                        .trim(),
                                    currency: draft.currency ?? _currency,
                                    groupType: groupType,
                                    preferences: preferences.toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (edited == null || !mounted) return;
      setState(() {
        _pendingDraft = edited;
        _pendingDraftConfirmed = false;
        _pendingAiTripPreview = null;
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text:
                'Draft updated. Review the custom version, then confirm it when it looks right.',
          ),
        );
      });
      _schedulePlannerSessionSave();
    } finally {
      destination.dispose();
      budget.dispose();
      customTag.dispose();
    }
  }

  Future<PlaceSuggestion?> _resolvePlaceForGeneration(String typed) async {
    if (_selectedPlace != null) return _selectedPlace;
    if (typed.length < 2) return null;

    try {
      final suggestions = await _places.searchDestinations(typed);
      if (suggestions.isNotEmpty) {
        return suggestions.first;
      }
    } catch (_) {}

    return PlaceSuggestion(
      name: typed,
      formatted: typed,
      latitude: 0,
      longitude: 0,
      placeId: typed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
    );
  }

  int _parsedBudget() {
    final numeric = int.tryParse(_budget.text.replaceAll(RegExp(r'\D'), ''));
    if (numeric != null && numeric > 0) return numeric;
    return _budgetTierAmount(_budget.text, _currency) ?? 0;
  }

  String _normalizedBudgetInput(String value, String currency) {
    final numeric = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    if (numeric != null && numeric > 0) return numeric.toString();
    final tierAmount = _budgetTierAmount(value, currency);
    return tierAmount == null || tierAmount <= 0
        ? value
        : tierAmount.toString();
  }

  int? _budgetTierAmount(String value, String currency) {
    final lower = value.toLowerCase();
    if (lower.trim().isEmpty) return null;
    final options = _budgetOptionsForCurrency(currency);
    if (lower.contains('lean') ||
        lower.contains('cheap') ||
        lower.contains('budget') ||
        lower.contains('low')) {
      return options.first.amount;
    }
    if (lower.contains('mid') ||
        lower.contains('medium') ||
        lower.contains('moderate') ||
        lower.contains('standard') ||
        lower.contains('comfortable')) {
      return options[1].amount;
    }
    if (lower.contains('flex') ||
        lower.contains('premium') ||
        lower.contains('lux') ||
        lower.contains('high')) {
      return options.last.amount;
    }
    return null;
  }

  PlaceSuggestion? _manualPlaceFromInput(String typed) {
    if (_selectedPlace != null) return _selectedPlace;
    if (typed.length < 2) return null;
    return PlaceSuggestion(
      name: typed,
      formatted: typed,
      latitude: 0,
      longitude: 0,
      placeId: typed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
    );
  }

  Future<void> _prepareAiTripPreviewFromDraft() async {
    if (_isPreparingPreview || _activePreviewJobId != null) return;
    final preview = _pendingAiTripPreview;
    if (preview != null) {
      await _showAiTripPreview(preview);
      return;
    }

    await _startAiTripPreviewJob(addChatStatusMessage: true);
  }

  Future<void> _startAiTripPreviewJob({
    required bool addChatStatusMessage,
  }) async {
    final budget = _parsedBudget();
    if (budget <= 0) {
      setState(() => _formError = 'Enter a budget greater than zero.');
      return;
    }

    final typedDestination = _destination.text.trim();
    PlaceSuggestion? place;
    try {
      place = await _resolvePlaceForGeneration(typedDestination);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = 'Could not verify that destination right now: $error';
      });
      return;
    }
    if (place == null) {
      setState(() => _formError = 'Enter a destination.');
      return;
    }

    final fallbackImages = _mergedPreviewImages(
      destination: place.name,
      searchedImages: const [],
    );
    final generationContext = await _deviceContextService.load(
      requestLocation: true,
    );
    if (!mounted) return;
    final startLocation = await _startLocationWithResolvedAddress(
      _startLocationForGeneration(generationContext),
    );
    if (!mounted) return;
    setState(() {
      _deviceContext = generationContext;
      _tripStartLocation = startLocation;
      if (startLocation != null && _canReplaceStartLocationText()) {
        _startLocation.text = startLocation.displayLabel;
      }
    });
    try {
      final jobId = await _previewJobs.createJob(
        accountId: widget.accountId,
        place: place,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        groupType: _group,
        preferences: _aiGenerationPreferences,
        currency: _currency,
        profileLanguage: widget.profileLanguage,
        appContext: generationContext,
        startLocation: startLocation,
        fallbackImages: fallbackImages,
        airline: _airline.text.trim(),
        flightCode: _flightCode.text.trim(),
        flightDepartureTime: _flightDepartTime.text.trim(),
        flightDeparturePlace: _flightDepartPlace.text.trim(),
        flightLandingTime: _flightLandingTime.text.trim(),
        flightLandingPlace: _flightLandingPlace.text.trim(),
      );
      if (jobId.trim().isEmpty) {
        throw Exception('Preview job was not created.');
      }
      if (!mounted) return;
      setState(() {
        _activePreviewJobId = jobId;
        _isPreparingPreview = true;
        _isGenerating = true;
        _pendingAiTripPreview = null;
        _formError = null;
        if (addChatStatusMessage &&
            (_chatMessages.isEmpty ||
                _chatMessages.last.text != _previewJobStartedMessage)) {
          _chatMessages.add(
            const CreateTripChatMessage(
              fromUser: false,
              text: _previewJobStartedMessage,
            ),
          );
        }
      });
      _schedulePlannerSessionSave();
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyAiError(error);
      setState(() {
        _isPreparingPreview = false;
        _isGenerating = false;
        _pendingAiTripPreview = null;
        _formError = message;
        if (addChatStatusMessage) {
          _chatMessages.add(
            CreateTripChatMessage(
              fromUser: false,
              text: 'I could not generate the live itinerary. $message',
            ),
          );
        }
      });
      return;
    }
  }

  Future<List<String>> _searchedImagesForTripPreview({
    required PlaceSuggestion place,
  }) async {
    final fallbackImages = _mergedPreviewImages(
      destination: place.name,
      searchedImages: const [],
    );
    try {
      final query = '${place.name} travel landmark';
      final url = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrnamespace': '6',
        'gsrlimit': '8',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '900',
        'format': 'json',
        'origin': '*',
      });
      final response = await http
          .get(
            url,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'TravellingWithFlutter/1.0 trip-preview-images',
            },
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallbackImages;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = body['query'] is Map
          ? (body['query'] as Map)['pages']
          : null;
      final searchedImages = <String>[];
      if (pages is Map) {
        for (final page in pages.values.whereType<Map>()) {
          final imageInfoList = (page['imageinfo'] as List<dynamic>?)
              ?.whereType<Map>()
              .toList();
          final imageInfo = imageInfoList == null || imageInfoList.isEmpty
              ? null
              : imageInfoList.first;
          final imageUrl =
              (imageInfo?['thumburl'] as String?) ??
              (imageInfo?['url'] as String?);
          if (_isPreviewImageUrl(imageUrl)) searchedImages.add(imageUrl!);
        }
      }
      return _mergedPreviewImages(
        destination: place.name,
        searchedImages: searchedImages,
      );
    } catch (_) {
      return fallbackImages;
    }
  }

  bool _isPreviewImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.startsWith('https://') &&
        (lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.png') ||
            lower.contains('.webp'));
  }

  List<String> _mergedPreviewImages({
    required String destination,
    required List<String> searchedImages,
  }) {
    final seen = <String>{};
    return [
      if (_selectedImage != null) _selectedImage!,
      ...searchedImages,
      ..._imagesForDestination(destination),
      ..._galleryOptions,
    ].where((image) => seen.add(image)).take(8).toList();
  }

  Future<void> _showAiTripPreview(_PendingAiTripPreview preview) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiTripPreviewSheet(
        preview: preview,
        selectedImage: _selectedImage,
        onConfirm: (image, plan) => _confirmAiTripPreview(
          sheetContext: context,
          preview: preview,
          selectedImage: image,
          plan: plan,
        ),
      ),
    );
  }

  Future<void> _confirmAiTripPreview({
    required BuildContext sheetContext,
    required _PendingAiTripPreview preview,
    required String? selectedImage,
    required GeneratedTripPlan plan,
  }) async {
    Navigator.of(sheetContext).pop();
    if (selectedImage != null) _selectedImage = selectedImage;
    final images = selectedImage == null
        ? preview.images
        : [
            selectedImage,
            ...preview.images.where((image) => image != selectedImage),
          ];
    await _createTripFromPlan(
      place: preview.place,
      budget: preview.budget,
      plan: plan,
      startLocation: preview.startLocation,
      images: images,
    );
    final jobId = preview.jobId;
    if (jobId != null) {
      unawaited(_previewJobs.deleteJob(widget.accountId, jobId));
    }
  }

  Future<void> _generateTrip() async {
    if (_isPreparingPreview || _activePreviewJobId != null) return;
    final preview = _pendingAiTripPreview;
    if (preview != null) {
      await _showAiTripPreview(preview);
      return;
    }
    await _startAiTripPreviewJob(addChatStatusMessage: false);
  }

  Future<void> _createTripFromPlan({
    required PlaceSuggestion place,
    required int budget,
    required GeneratedTripPlan plan,
    required TripStartLocation? startLocation,
    List<String>? images,
  }) async {
    if (_isCreatingTrip) return;
    setState(() {
      _isCreatingTrip = true;
      _formError = null;
    });
    final bookings = _bookingsWithManualDetails(plan.bookings);
    final budgetCategories = _defaultBudgetCategories(
      budget: budget,
      actual: 0,
      items: plan.items,
      bookings: bookings,
      transportActual: _purchasedTransportCost,
    );
    final budgetLimit = _budgetLimitForCategories(
      budget: budget,
      categories: budgetCategories,
    );
    final tripImages =
        images ??
        [
          if (_selectedImage != null) _selectedImage!,
          ..._imagesForDestination(place.name),
        ];
    try {
      await widget.onGenerate(
        Trip(
          id: 't-${DateTime.now().millisecondsSinceEpoch}',
          destination: place.name,
          placeId: place.placeId,
          formattedAddress: place.formatted,
          latitude: place.latitude,
          longitude: place.longitude,
          originLabel: startLocation?.displayLabel,
          originLatitude: startLocation?.latitude,
          originLongitude: startLocation?.longitude,
          startDate: _dateKey(_startDate),
          endDate: _dateKey(_endDate),
          budget: budgetLimit,
          spent: _purchasedTransportCost,
          groupType: _group,
          currency: _currency,
          status: TripStatus.upcoming,
          images: tripImages,
          items: plan.items,
          bookings: bookings,
          checklist: plan.checklist,
          preferences: _savedTripPreferences,
          budgetCategories: budgetCategories,
        ),
      );
      await _clearPlannerSession();
    } finally {
      if (mounted) setState(() => _isCreatingTrip = false);
    }
  }

  GeneratedTripPlan _manualStarterPlan({
    required PlaceSuggestion place,
    required TripStartLocation? startLocation,
    required String currency,
  }) {
    final dayCount = _tripDayCount(_startDate, _endDate);
    return _planWithTripTransport(
      GeneratedTripPlan(
        items: [],
        bookings: [],
        checklist: [
          const ChecklistCategory('Essentials', [
            'Passport or ID',
            'Wallet and payment cards',
            'Phone charger',
          ]),
          ChecklistCategory('To decide', [
            if (dayCount > 1) 'Accommodation',
            'Transportation',
            'Reservations',
          ]),
        ],
      ),
      place: place,
      startDate: _startDate,
      endDate: _endDate,
      startLocation: startLocation,
      currency: currency,
      preferences: _savedTripPreferences,
    );
  }

  List<Booking> _bookingsWithManualDetails(List<Booking> generated) {
    final airline = _airline.text.trim();
    final flightCode = _flightCode.text.trim();
    final passengerName = _ticketPassengerName.text.trim();
    final departTime = _flightDepartTime.text.trim();
    final departPlace = _flightDepartPlace.text.trim();
    final landingTime = _flightLandingTime.text.trim();
    final landingPlace = _flightLandingPlace.text.trim();
    final paidAmount = _purchasedTransportCost;
    if (airline.isEmpty &&
        flightCode.isEmpty &&
        passengerName.isEmpty &&
        departTime.isEmpty &&
        departPlace.isEmpty &&
        landingTime.isEmpty &&
        landingPlace.isEmpty &&
        paidAmount <= 0) {
      return generated;
    }
    final referenceParts = [
      if (passengerName.isNotEmpty) 'Passenger: $passengerName',
      if (departTime.isNotEmpty || departPlace.isNotEmpty)
        'Depart: ${[if (departTime.isNotEmpty) departTime, if (departPlace.isNotEmpty) departPlace].join(' at ')}',
      if (landingTime.isNotEmpty || landingPlace.isNotEmpty)
        'Land: ${[if (landingTime.isNotEmpty) landingTime, if (landingPlace.isNotEmpty) landingPlace].join(' at ')}',
    ];
    final manualFlight = Booking(
      [
        if (airline.isNotEmpty) airline else 'Flight booking',
        if (flightCode.isNotEmpty) flightCode,
      ].join(' / '),
      _dateKey(_startDate),
      departTime.isEmpty ? 'TBD' : departTime,
      referenceParts.isEmpty
          ? 'Manual flight details'
          : referenceParts.join(' | '),
      paidAmount,
      Icons.flight_takeoff_rounded,
    );
    return [manualFlight, ...generated];
  }

  List<_TripTemplate> get _pastTripTemplates => widget.savedTrips
      .where((trip) => trip.status == TripStatus.past)
      .map(
        (trip) => _TripTemplate(
          trip: trip,
          source: 'Past trip',
          description:
              'Reuse your saved route, budget categories, checklist, and schedule stops.',
          badge: 'Saved',
        ),
      )
      .toList();

  List<Trip> get _recentChatTrips {
    final trips = [...widget.savedTrips];
    trips.sort((a, b) {
      final aDate = _parseTripDate(a.endDate) ?? _parseTripDate(a.startDate);
      final bDate = _parseTripDate(b.endDate) ?? _parseTripDate(b.startDate);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return trips.take(10).toList(growable: false);
  }

  String _recentTripPrompt(Trip trip) {
    final days = _templateLengthDays(trip);
    final start = _today().add(const Duration(days: 30));
    final end = start.add(Duration(days: math.max(1, days) - 1));
    final preferences = trip.preferences.take(4).join(', ');
    return [
      'Plan a $days day trip to ${trip.destination} for ${trip.groupType},',
      '${_dateKey(start)} to ${_dateKey(end)},',
      'budget ${trip.currency} ${trip.budget}.',
      if (preferences.isNotEmpty) 'Focus on $preferences.',
      'Use a similar pace to my recent ${trip.destination} trip.',
    ].join(' ');
  }

  void _openTemplatePicker() {
    setState(() {
      _mode = 4;
      _formError = null;
    });
  }

  int _templateLengthDays(Trip trip) {
    final start = _parseTripDate(trip.startDate);
    final end = _parseTripDate(trip.endDate);
    if (start == null || end == null || end.isBefore(start)) {
      return _tripRuntimePlan(trip).totalDays;
    }
    return math.max(1, end.difference(start).inDays + 1);
  }

  Trip _tripFromTemplate(Trip template) {
    final start = _today().add(const Duration(days: 30));
    final end = start.add(Duration(days: _templateLengthDays(template) - 1));
    final budgetCategories = template.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: template.budget,
            actual: 0,
            items: template.items,
            bookings: template.bookings,
          )
        : template.budgetCategories
              .map((category) => category.copyWith(actual: 0))
              .toList();
    final budgetLimit = _budgetLimitForCategories(
      budget: template.budget,
      categories: budgetCategories,
    );

    return Trip(
      id: 't-${DateTime.now().millisecondsSinceEpoch}',
      title: template.title.trim().isEmpty
          ? template.destination
          : template.title,
      destination: template.destination,
      placeId: template.placeId,
      formattedAddress: template.formattedAddress,
      latitude: template.latitude,
      longitude: template.longitude,
      originLabel: template.originLabel,
      originLatitude: template.originLatitude,
      originLongitude: template.originLongitude,
      startDate: _dateKey(start),
      endDate: _dateKey(end),
      budget: budgetLimit,
      spent: 0,
      groupType: template.groupType,
      currency: template.currency,
      status: TripStatus.upcoming,
      images: template.images.isEmpty
          ? _imagesForDestination(template.destination)
          : template.images,
      items: template.items,
      bookings: template.bookings,
      checklist: template.checklist,
      preferences: template.preferences,
      budgetCategories: budgetCategories,
    );
  }

  Future<void> _confirmTemplateFromPreview(
    BuildContext sheetContext,
    _TripTemplate template,
  ) async {
    final sheetNavigator = Navigator.of(sheetContext);
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Use this template?')),
        content: Text(
          appText(
            context,
            'A new itinerary will be created from this preview. You can edit dates, bookings, and activities after it is created.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_rounded),
            label: Text(appText(context, 'Use template')),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    sheetNavigator.pop();
    widget.onGenerate(_tripFromTemplate(template.trip));
  }

  Future<void> _showTemplatePreview(_TripTemplate template) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TemplatePreviewSheet(
        template: template,
        lengthDays: _templateLengthDays(template.trip),
        onConfirm: () => _confirmTemplateFromPreview(context, template),
      ),
    );
  }

  bool _isManualStepValid(int index) {
    return switch (index) {
      0 => _destination.text.trim().isNotEmpty,
      1 => _parsedBudget() > 0,
      2 => _group.trim().isNotEmpty && _preferences.isNotEmpty,
      3 => true,
      _ => false,
    };
  }

  bool _isManualStepComplete(int index) {
    if (!_manualCompletedSteps.contains(index)) return false;
    return _isManualStepValid(index);
  }

  String _manualStepError(int index) {
    return switch (index) {
      0 => 'Enter a destination before continuing.',
      1 => 'Enter a budget greater than zero before continuing.',
      2 => 'Choose at least one travel style before continuing.',
      _ => '',
    };
  }

  void _toggleManualStep(int index) {
    setState(() {
      _manualExpandedStep = _manualExpandedStep == index ? null : index;
      _formError = null;
    });
  }

  void _completeManualStep(int index) {
    if (!_isManualStepValid(index)) {
      setState(() => _formError = _manualStepError(index));
      return;
    }

    setState(() {
      _manualCompletedSteps.add(index);
      _manualExpandedStep = index < 3 ? index + 1 : null;
      _formError = null;
    });
  }

  void _applyAiRouteIdea({
    required String destination,
    String? origin,
    List<String> preferences = const [],
  }) {
    setState(() {
      _destination.text = destination;
      if (origin != null) _startLocation.text = origin;
      _selectedPlace = null;
      _selectedOriginPlace = null;
      _placeSuggestions = const [];
      _originSuggestions = const [];
      _preferences.addAll(preferences);
      _formError = null;
    });
  }

  void _applyAiTimingIdea({
    required DateTime startDate,
    required int days,
    required String budget,
  }) {
    setState(() {
      _startDate = startDate;
      _endDate = startDate.add(Duration(days: math.max(1, days) - 1));
      _setBudgetText(budget);
      _hasBudgetText = budget.trim().isNotEmpty;
      _formError = null;
    });
  }

  void _applyAiStyleIdea({
    required String group,
    required List<String> preferences,
  }) {
    setState(() {
      _group = group;
      _preferences.addAll(preferences);
      _formError = null;
    });
  }

  bool get _hasTransportRecommendationRoute {
    final hasDestination =
        _selectedPlace != null || _destination.text.trim().isNotEmpty;
    final hasOrigin =
        _selectedOriginPlace != null ||
        _tripStartLocation != null ||
        _startLocation.text.trim().isNotEmpty;
    return hasDestination && hasOrigin;
  }

  String get _transportOriginLabel {
    return _selectedOriginPlace?.formatted ??
        _tripStartLocation?.displayLabel ??
        _startLocation.text.trim();
  }

  String get _transportDestinationLabel {
    return _selectedPlace?.formatted ?? _destination.text.trim();
  }

  int get _purchasedTransportCost =>
      int.tryParse(_ticketPaidAmount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  List<TransportRecommendation> get _purchasedTransportRecommendations {
    final airline = _airline.text.trim();
    final code = _flightCode.text.trim();
    final passenger = _ticketPassengerName.text.trim();
    final departTime = _flightDepartTime.text.trim();
    final departPlace = _flightDepartPlace.text.trim();
    final landingTime = _flightLandingTime.text.trim();
    final landingPlace = _flightLandingPlace.text.trim();
    final paid = _purchasedTransportCost;
    if (airline.isEmpty &&
        code.isEmpty &&
        departTime.isEmpty &&
        departPlace.isEmpty &&
        landingTime.isEmpty &&
        landingPlace.isEmpty &&
        paid <= 0) {
      return const [];
    }
    final route = departPlace.isNotEmpty || landingPlace.isNotEmpty
        ? [
            if (departPlace.isNotEmpty) departPlace else _transportOriginLabel,
            if (landingPlace.isNotEmpty)
              landingPlace
            else
              _transportDestinationLabel,
          ].join(' to ')
        : _hasTransportRecommendationRoute
        ? 'Booked route from $_transportOriginLabel to $_transportDestinationLabel'
        : 'Booked flight details';
    final detailParts = [
      if (code.isNotEmpty) code,
      if (passenger.isNotEmpty) 'Passenger: $passenger',
      if (departTime.isNotEmpty) 'Depart: $departTime',
      if (landingTime.isNotEmpty) 'Land: $landingTime',
    ];
    return [
      TransportRecommendation(
        mode: 'Flight',
        provider: airline.isEmpty ? 'Booked flight' : airline,
        route: route,
        duration: '',
        price: paid,
        currency: _currency,
        bookingHint: detailParts.isEmpty
            ? 'Already bought. This will be saved as spent transport budget.'
            : '${detailParts.join(' | ')}. Already bought and saved as spent transport budget.',
        sourceName: 'Your ticket',
        sourceUrl: '',
      ),
    ];
  }

  Future<void> _loadTransportRecommendations() async {
    if (!_hasTransportRecommendationRoute || _isLoadingTransport) return;
    setState(() {
      _isLoadingTransport = true;
      _transportRecommendationError = null;
    });
    try {
      final result = await _assistant
          .generateTransportRecommendations(
            origin: _transportOriginLabel,
            destination: _transportDestinationLabel,
            startDate: _startDate,
            endDate: _endDate,
            currency: _currency,
            groupType: _group,
          )
          .timeout(const Duration(seconds: 40));
      if (!mounted) return;
      setState(() {
        _transportRecommendations = result.options;
        _transportRecommendationSummary = result.summary;
        _isLoadingTransport = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _transportRecommendationError =
            'Transport search is unavailable right now. Try again after confirming the route, or add bought ticket details below.';
        _isLoadingTransport = false;
      });
    }
  }

  bool _isAiStepValid(int index) {
    return switch (index) {
      0 => true,
      1 => _destination.text.trim().isNotEmpty,
      2 => _parsedBudget() > 0,
      3 => _group.trim().isNotEmpty && _preferences.isNotEmpty,
      4 => true,
      _ => false,
    };
  }

  bool _isAiStepComplete(int index) {
    if (!_aiCompletedSteps.contains(index)) return false;
    return _isAiStepValid(index);
  }

  String _aiStepError(int index) {
    return switch (index) {
      1 => 'Pick or enter a destination before finishing this section.',
      2 =>
        'Pick or enter a budget greater than zero before finishing this section.',
      3 => 'Choose at least one travel style before finishing this section.',
      _ => '',
    };
  }

  void _toggleAiStep(int index) {
    setState(() {
      _aiExpandedStep = _aiExpandedStep == index ? null : index;
      _formError = null;
    });
  }

  void _completeAiStep(int index) {
    if (!_isAiStepValid(index)) {
      setState(() => _formError = _aiStepError(index));
      return;
    }

    setState(() {
      _aiCompletedSteps.add(index);
      _aiExpandedStep = index < 4 ? index + 1 : null;
      _formError = null;
    });
  }

  Widget _buildAiTripBuilderPage(BuildContext context) {
    final tripLength = math.max(1, _endDate.difference(_startDate).inDays + 1);
    final budgetLabel = _hasBudgetText
        ? '$_currency ${_budget.text}'
        : _budgetHintText(context);
    final horizontalPadding = _responsiveHorizontalPadding(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final aiStepComplete = List.generate(5, _isAiStepComplete);
    final nextAiStep = aiStepComplete.indexWhere((complete) => !complete);
    final aiFocusStep = nextAiStep == -1 ? null : nextAiStep;
    final timingPresets = _timingPresets();

    return ScreenScaffold(
      child: Column(
        children: [
          _ManualTopBar(
            title: 'AI Trip Builder',
            onBack: () => setState(() => _mode = 0),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                22,
                horizontalPadding,
                34 + bottomInset,
              ),
              children: [
                _AiBuilderHero(
                  destination: _destination.text.trim(),
                  tripLength: tripLength,
                  budgetLabel: _hasBudgetText ? budgetLabel : '',
                  selectedSuggestionCount: _planningGoalIds.length,
                  expanded: _aiPreviewExpanded,
                  onToggle: () =>
                      setState(() => _aiPreviewExpanded = !_aiPreviewExpanded),
                ),
                const SizedBox(height: 14),
                _AiAccordionSection(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI setup',
                  suggestion:
                      'Pick the trip style and planning focuses AI should emphasize.',
                  expanded: _aiExpandedStep == 0,
                  complete: aiStepComplete[0],
                  attention: aiFocusStep == 0,
                  onToggle: () => _toggleAiStep(0),
                  onDone: () => _completeAiStep(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiSuggestionDeck(
                        goals: _planningGoals,
                        selectedGoalIds: _planningGoalIds,
                        onToggle: _togglePlanningGoal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AiAccordionSection(
                  icon: Icons.route_rounded,
                  title: 'Route brief',
                  suggestion:
                      'AI will use the destination and starting point to cluster nearby stops and reduce backtracking.',
                  expanded: _aiExpandedStep == 1,
                  complete: aiStepComplete[1],
                  attention: aiFocusStep == 1,
                  onToggle: () => _toggleAiStep(1),
                  onDone: () => _completeAiStep(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiChoiceGrid(
                        choices: [
                          _AiChoice(
                            icon: Icons.temple_buddhist_rounded,
                            title: 'Culture route',
                            text: 'Kyoto temples, food lanes, low backtrack',
                            onTap: () => _applyAiRouteIdea(
                              destination: 'Kyoto, Japan',
                              origin: 'Kyoto Station',
                              preferences: ['Culture', 'Food', 'Walking'],
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.restaurant_rounded,
                            title: 'Food-first city',
                            text: 'Tokyo neighborhoods and market meals',
                            onTap: () => _applyAiRouteIdea(
                              destination: 'Tokyo, Japan',
                              origin: 'Shinjuku Station',
                              preferences: ['Food', 'Shopping', 'Nightlife'],
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.beach_access_rounded,
                            title: 'Slow reset',
                            text: 'Bali nature, beaches, and relaxed pacing',
                            onTap: () => _applyAiRouteIdea(
                              destination: 'Bali, Indonesia',
                              origin: 'Ngurah Rai Airport',
                              preferences: ['Nature', 'Relax', 'Culture'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AiInputGrid(
                        children: [
                          _AiInputCard(
                            label: 'Destination',
                            icon: Icons.travel_explore_rounded,
                            controller: _destination,
                            hint: 'Tokyo, Japan',
                            onChanged: _schedulePlaceSearch,
                            loading: _isSearching,
                          ),
                          _AiInputCard(
                            label: 'Start from',
                            icon: Icons.trip_origin_rounded,
                            controller: _startLocation,
                            hint: 'Current location or Hsinchu',
                            onChanged: _scheduleOriginSearch,
                            loading: _isOriginSearching,
                            action: IconButton(
                              tooltip: appText(context, 'Use current location'),
                              onPressed: _isOriginSearching
                                  ? null
                                  : _useCurrentStartLocation,
                              icon: const Icon(Icons.my_location_rounded),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPlace != null) ...[
                        const SizedBox(height: 10),
                        SelectedPlaceCard(place: _selectedPlace!),
                      ] else if (_placeSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PlaceSuggestionList(
                          suggestions: _placeSuggestions,
                          onSelect: _selectPlace,
                        ),
                      ],
                      if (_selectedOriginPlace != null) ...[
                        const SizedBox(height: 10),
                        SelectedPlaceCard(place: _selectedOriginPlace!),
                      ] else if (_originSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PlaceSuggestionList(
                          suggestions: _originSuggestions,
                          onSelect: _selectOriginPlace,
                        ),
                      ] else if (_tripStartLocation?.isCurrentLocation ==
                          true) ...[
                        const SizedBox(height: 10),
                        const _AiContextNote(
                          icon: Icons.my_location_rounded,
                          title: 'Current location',
                          text:
                              'AI uses this address to find nearby stations, bus stops, airports, and return routes.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AiAccordionSection(
                  icon: Icons.auto_graph_rounded,
                  title: 'Timing and budget',
                  suggestion:
                      'AI will balance the daily pace against your budget, dates, and travel party.',
                  expanded: _aiExpandedStep == 2,
                  complete: aiStepComplete[2],
                  attention: aiFocusStep == 2,
                  onToggle: () => _toggleAiStep(2),
                  onDone: () => _completeAiStep(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiChoiceGrid(
                        choices: timingPresets
                            .map(
                              (preset) => _AiChoice(
                                icon: preset.icon,
                                title: preset.title,
                                text: preset.text,
                                onTap: () => _applyAiTimingIdea(
                                  startDate: preset.startDate,
                                  days: preset.days,
                                  budget: preset.budget,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _AiDateRangeCard(
                        startDate: _startDate,
                        endDate: _endDate,
                        tripLength: tripLength,
                        onTap: _pickDateRange,
                      ),
                      const SizedBox(height: 12),
                      _AiInputGrid(
                        children: [
                          _AiInputCard(
                            label: 'Total budget',
                            icon: Icons.payments_rounded,
                            controller: _budget,
                            hint: _budgetHintText(context),
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              _GroupedNumberInputFormatter(),
                            ],
                          ),
                          _AiPickerCard(
                            label: 'Currency',
                            icon: Icons.payments_outlined,
                            value: _currency,
                            options: _currencyOptions,
                            onChanged: (value) => setState(() {
                              _currency = value;
                              _formError = null;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AiAccordionSection(
                  icon: Icons.psychology_rounded,
                  title: 'AI taste profile',
                  suggestion:
                      'AI will prioritize the selected tags when choosing neighborhoods, meals, and activity types.',
                  expanded: _aiExpandedStep == 3,
                  complete: aiStepComplete[3],
                  attention: aiFocusStep == 3,
                  onToggle: () => _toggleAiStep(3),
                  onDone: () => _completeAiStep(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiChoiceGrid(
                        choices: [
                          _AiChoice(
                            icon: Icons.group_rounded,
                            title: 'Friends energy',
                            text: 'Food, shopping, nightlife, flexible pace',
                            onTap: () => _applyAiStyleIdea(
                              group: 'Friends',
                              preferences: ['Food', 'Shopping', 'Nightlife'],
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.family_restroom_rounded,
                            title: 'Family comfort',
                            text: 'Easy pace, culture, rain-ready stops',
                            onTap: () => _applyAiStyleIdea(
                              group: 'Family',
                              preferences: ['Culture', 'Relax', 'Museums'],
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.hiking_rounded,
                            title: 'Active explorer',
                            text: 'Nature, walking routes, adventure',
                            onTap: () => _applyAiStyleIdea(
                              group: 'Tour',
                              preferences: ['Nature', 'Adventure', 'Walking'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AiInputGrid(
                        children: [
                          _AiPickerCard(
                            label: 'Who is coming',
                            icon: Icons.group_rounded,
                            value: _group,
                            options: _groupOptions,
                            onChanged: (value) =>
                                setState(() => _group = value),
                          ),
                          _AiCustomTagCard(
                            controller: _customPreference,
                            onAdd: _addCustomPreference,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AiTagCloudCard(
                        title: 'Trip Type',
                        preferences: _visiblePreferenceOptions,
                        selectedPreferences: _preferences,
                        onToggle: _togglePreference,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AiAccordionSection(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Booking clues',
                  suggestion:
                      'Optional booking details help AI anchor arrival and departure timing more accurately.',
                  expanded: _aiExpandedStep == 4,
                  complete: aiStepComplete[4],
                  attention: aiFocusStep == 4,
                  onToggle: () => _toggleAiStep(4),
                  onDone: () => _completeAiStep(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TransportRecommendationCard(
                        available: _hasTransportRecommendationRoute,
                        loading: _isLoadingTransport,
                        summary: _transportRecommendationSummary,
                        error: _transportRecommendationError,
                        options: _visibleTransportRecommendations,
                        currency: _currency,
                        onRefresh: _loadTransportRecommendations,
                      ),
                      const SizedBox(height: 12),
                      _PurchasedFlightCard(
                        airline: _airline,
                        flightCode: _flightCode,
                        passengerName: _ticketPassengerName,
                        departTime: _flightDepartTime,
                        departPlace: _flightDepartPlace,
                        landingTime: _flightLandingTime,
                        landingPlace: _flightLandingPlace,
                        paidAmount: _ticketPaidAmount,
                        currency: _currency,
                        onChanged: () => setState(() => _formError = null),
                      ),
                    ],
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 16),
                  FormNotice(message: _formError!),
                ],
                const SizedBox(height: 22),
                if (_isGenerating)
                  const GeneratingTripPanel()
                else
                  _AiGenerateFooter(
                    label: _pendingAiTripPreview == null
                        ? 'Generate with AI'
                        : 'Preview itinerary',
                    onGenerate: _generateTrip,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTripPage(BuildContext context) {
    final tripLength = math.max(1, _endDate.difference(_startDate).inDays + 1);
    final budgetLabel = _hasBudgetText
        ? '$_currency ${_budget.text}'
        : _budgetHintText(context);
    final horizontalPadding = _responsiveHorizontalPadding(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final manualStepComplete = List.generate(4, _isManualStepComplete);
    final completedStepCount = manualStepComplete.where((step) => step).length;
    final nextManualStep = manualStepComplete.indexWhere(
      (complete) => !complete,
    );
    final manualFocusStep = nextManualStep == -1 ? null : nextManualStep;

    return ScreenScaffold(
      child: Column(
        children: [
          _ManualTopBar(
            title: 'Create Manually',
            onBack: () => setState(() => _mode = 0),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                22,
                horizontalPadding,
                34 + bottomInset,
              ),
              children: [
                Text(
                  appText(context, 'Trip Basics'),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appText(context, "Let's start with the basics"),
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _ManualPreviewCard(
                  completedSections: completedStepCount,
                  totalSections: manualStepComplete.length,
                  destination: _destination.text.trim(),
                  startDate: _dateKey(_startDate),
                  endDate: _dateKey(_endDate),
                  tripLength: tripLength,
                  budget: _hasBudgetText ? budgetLabel : '',
                  group: _group,
                  preferences: _preferences.toList(),
                  expanded: _manualPreviewExpanded,
                  onToggle: () => setState(
                    () => _manualPreviewExpanded = !_manualPreviewExpanded,
                  ),
                ),
                const SizedBox(height: 14),
                const _ManualInfoBanner(),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showRail = constraints.maxWidth >= 880;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showRail) ...[
                          SizedBox(
                            width: 260,
                            child: _ManualStepRail(
                              expandedStep: _manualExpandedStep,
                              completedSteps: manualStepComplete,
                            ),
                          ),
                          const SizedBox(width: 30),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ManualAccordionSection(
                                icon: Icons.route_rounded,
                                title: 'Route',
                                subtitle:
                                    'Set where the trip goes and where the first travel leg starts.',
                                expanded: _manualExpandedStep == 0,
                                complete: manualStepComplete[0],
                                attention: manualFocusStep == 0,
                                onToggle: () => _toggleManualStep(0),
                                onContinue: () => _completeManualStep(0),
                                children: [
                                  _ManualGrid(
                                    minTileWidth: 250,
                                    children: [
                                      _ManualFieldCard(
                                        label: 'Destination',
                                        trailing: _isSearching
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.location_on_rounded,
                                              ),
                                        child: _ManualTextField(
                                          controller: _destination,
                                          hint: 'Where do you want to go?',
                                          onChanged: _schedulePlaceSearch,
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Start from',
                                        icon: Icons.trip_origin_rounded,
                                        trailing: IconButton(
                                          tooltip: appText(
                                            context,
                                            'Use current location',
                                          ),
                                          onPressed: _isOriginSearching
                                              ? null
                                              : _useCurrentStartLocation,
                                          icon: const Icon(
                                            Icons.my_location_rounded,
                                          ),
                                        ),
                                        child: _ManualTextField(
                                          controller: _startLocation,
                                          hint: 'Current location or Hsinchu',
                                          onChanged: _scheduleOriginSearch,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_selectedPlace != null) ...[
                                    const SizedBox(height: 10),
                                    SelectedPlaceCard(place: _selectedPlace!),
                                  ] else if (_placeSuggestions.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    PlaceSuggestionList(
                                      suggestions: _placeSuggestions,
                                      onSelect: _selectPlace,
                                    ),
                                  ],
                                  if (_selectedOriginPlace != null) ...[
                                    const SizedBox(height: 10),
                                    SelectedPlaceCard(
                                      place: _selectedOriginPlace!,
                                    ),
                                  ] else if (_originSuggestions.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    PlaceSuggestionList(
                                      suggestions: _originSuggestions,
                                      onSelect: _selectOriginPlace,
                                    ),
                                  ] else if (_tripStartLocation
                                          ?.isCurrentLocation ==
                                      true) ...[
                                    const SizedBox(height: 10),
                                    const _ManualNoticeCard(
                                      icon: Icons.my_location_rounded,
                                      title: 'Current location',
                                      text:
                                          'AI uses this address to find nearby stations, bus stops, airports, and return routes.',
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ManualAccordionSection(
                                icon: Icons.calendar_month_rounded,
                                title: 'Dates and budget',
                                subtitle:
                                    'One range picker controls the start date, end date, and duration.',
                                expanded: _manualExpandedStep == 1,
                                complete: manualStepComplete[1],
                                attention: manualFocusStep == 1,
                                onToggle: () => _toggleManualStep(1),
                                onContinue: () => _completeManualStep(1),
                                children: [
                                  _ManualDateRangeCard(
                                    startDate: _startDate,
                                    endDate: _endDate,
                                    tripLength: tripLength,
                                    onTap: _pickDateRange,
                                  ),
                                  const SizedBox(height: 12),
                                  _ManualGrid(
                                    minTileWidth: 220,
                                    children: [
                                      _ManualFieldCard(
                                        label: 'Total budget',
                                        icon: Icons.payments_rounded,
                                        child: _ManualTextField(
                                          controller: _budget,
                                          hint: budgetLabel,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: const [
                                            _GroupedNumberInputFormatter(),
                                          ],
                                        ),
                                      ),
                                      _ManualDropdownCard(
                                        label: 'Currency',
                                        value: _currency,
                                        icon: Icons.expand_more_rounded,
                                        options: _currencyOptions,
                                        onChanged: (value) => setState(() {
                                          _currency = value;
                                          _formError = null;
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ManualAccordionSection(
                                icon: Icons.tune_rounded,
                                title: 'Travel style',
                                subtitle:
                                    'Choose the travel party and the tags that should shape the starter trip.',
                                expanded: _manualExpandedStep == 2,
                                complete: manualStepComplete[2],
                                attention: manualFocusStep == 2,
                                onToggle: () => _toggleManualStep(2),
                                onContinue: () => _completeManualStep(2),
                                children: [
                                  _ManualGrid(
                                    minTileWidth: 220,
                                    children: [
                                      _ManualDropdownCard(
                                        label: 'Who is coming',
                                        value: _group,
                                        icon: Icons.group_rounded,
                                        options: _groupOptions,
                                        onChanged: (value) =>
                                            setState(() => _group = value),
                                      ),
                                      _ManualCustomTagCard(
                                        controller: _customPreference,
                                        onAdd: _addCustomPreference,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _ManualChipCard(
                                    title: 'Trip Type',
                                    preferences: _visiblePreferenceOptions,
                                    selectedPreferences: _preferences,
                                    onToggle: _togglePreference,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ManualAccordionSection(
                                icon: Icons.flight_takeoff_rounded,
                                title: 'Optional booking details',
                                subtitle:
                                    'Add flight details now, or leave them blank and fill bookings later.',
                                expanded: _manualExpandedStep == 3,
                                complete: manualStepComplete[3],
                                attention: manualFocusStep == 3,
                                onToggle: () => _toggleManualStep(3),
                                onContinue: () => _completeManualStep(3),
                                continueLabel: 'Done',
                                children: [
                                  _ManualGrid(
                                    minTileWidth: 250,
                                    children: [
                                      _ManualFieldCard(
                                        label: 'Airline optional',
                                        icon: Icons.flight_takeoff_rounded,
                                        child: _ManualTextField(
                                          controller: _airline,
                                          hint: 'Flight booking',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Flight number',
                                        icon: Icons.confirmation_number_rounded,
                                        child: _ManualTextField(
                                          controller: _flightCode,
                                          hint: 'BR123 / CI751',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Passenger name',
                                        icon: Icons.badge_rounded,
                                        child: _ManualTextField(
                                          controller: _ticketPassengerName,
                                          hint: 'Name under ticket',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Depart time',
                                        icon: Icons.schedule_rounded,
                                        child: _ManualTextField(
                                          controller: _flightDepartTime,
                                          hint: '23:30',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Depart place',
                                        icon: Icons.flight_takeoff_rounded,
                                        child: _ManualTextField(
                                          controller: _flightDepartPlace,
                                          hint: 'Taipei Taoyuan TPE',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Landing time',
                                        icon: Icons.schedule_rounded,
                                        child: _ManualTextField(
                                          controller: _flightLandingTime,
                                          hint: '19:15',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Landing place',
                                        icon: Icons.flight_land_rounded,
                                        child: _ManualTextField(
                                          controller: _flightLandingPlace,
                                          hint: 'Paris CDG',
                                        ),
                                      ),
                                      _ManualFieldCard(
                                        label: 'Already paid',
                                        icon: Icons.payments_rounded,
                                        child: _ManualTextField(
                                          controller: _ticketPaidAmount,
                                          hint: 'Amount in $_currency',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: const [
                                            _GroupedNumberInputFormatter(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_formError != null) ...[
                                const SizedBox(height: 16),
                                FormNotice(message: _formError!),
                              ],
                              const SizedBox(height: 22),
                              _ManualFooterActions(
                                onCancel: () => setState(() => _mode = 0),
                                onCreate: _createManualTrip,
                                isCreating: _isGenerating,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingTrip) {
      return const _TripCreationLoadingScreen();
    }

    if (_mode == 0) {
      return ScreenScaffold(
        child: ListView(
          padding: _responsivePagePadding(context, top: 18),
          children: [
            TopBar(title: 'How do you want to start?', onBack: widget.onBack),
            const SizedBox(height: 18),
            const AnimatedGlobe(),
            const SizedBox(height: 22),
            CreateOptionCard(
              icon: Icons.explore_rounded,
              title: 'AI Trip Builder',
              text: 'Fill the essentials, then let AI create the route.',
              onTap: () => setState(() => _mode = 1),
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Chat Planner',
              text: 'Describe the trip in chat and let AI shape the draft.',
              onTap: _startAiChat,
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.edit_note_rounded,
              title: 'Create Manually',
              text: 'Enter destination, dates, budget, people, and tags.',
              onTap: () => setState(() => _mode = 2),
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.work_rounded,
              title: 'Use Saved Trip Template',
              text: 'Pick from past trips or UI-only online recommendations.',
              onTap: _openTemplatePicker,
            ),
          ],
        ),
      );
    }

    if (_mode == 4) {
      final pastTemplates = _pastTripTemplates;
      return ScreenScaffold(
        child: ListView(
          padding: _responsivePagePadding(context, top: 18),
          children: [
            TopBar(
              title: 'Trip templates',
              onBack: () => setState(() => _mode = 0),
            ),
            const SizedBox(height: 16),
            _TemplatePickerHero(
              pastCount: pastTemplates.length,
              recommendationCount: _recommendedTemplates.length,
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Past trip templates'),
            const SizedBox(height: 10),
            if (pastTemplates.isEmpty)
              const _EmptyTemplateState()
            else
              _TemplateCardGrid(
                templates: pastTemplates,
                onPreview: _showTemplatePreview,
              ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Online recommendations'),
            const SizedBox(height: 10),
            _TemplateCardGrid(
              templates: _recommendedTemplates,
              onPreview: _showTemplatePreview,
            ),
          ],
        ),
      );
    }

    if (_mode == 3) {
      final pendingDraft = _pendingDraft;
      final canUsePlan =
          pendingDraft != null && _missingDraftFields(pendingDraft).isEmpty;
      final isChatFresh = _chatMessages.isEmpty;
      return ScreenScaffold(
        child: Column(
          children: [
            Padding(
              padding: _responsivePagePadding(context, top: 18, bottom: 8),
              child: TopBar(
                title: 'Plan with AI',
                onBack: _closeAiChatPlanner,
                action: Icons.refresh_rounded,
                onAction: _resetCreateTripChat,
              ),
            ),
            Expanded(
              child: ListView(
                padding: _responsivePagePadding(context, top: 10, bottom: 18),
                children: [
                  if (isChatFresh) ...[
                    const AnimatedGlobe(),
                    const SizedBox(height: 16),
                    Text(
                      appText(context, 'Hello, where would you like to go?'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appText(
                        context,
                        'Choose guided suggestions or describe the full trip.',
                      ),
                      style: const TextStyle(
                        color: _secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'Kyoto, Japan',
                                'Tokyo, Japan',
                                'Bali, Indonesia',
                                'Paris, France',
                              ]
                              .map(
                                (prompt) => ActionChip(
                                  label: Text(prompt),
                                  onPressed: () => _sendCreateTripChat(prompt),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  side: const BorderSide(
                                    color: Color(0xFFEFF3F6),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 18),
                  ],
                  for (final message in _chatMessages)
                    CreateTripChatTurn(
                      message: message,
                      onSelect: _sendCreateTripChat,
                      selectedCurrency: _currency,
                      currencyOptions: _currencyOptions,
                      onCurrencyChanged: _setCreateChatCurrency,
                      budgetOptions: _budgetChoiceOptionsForCurrentDraft(),
                    ),
                  if (_isThinking) const CreateTripThinkingBubble(),
                  if (_isPreparingPreview) ...[
                    const SizedBox(height: 12),
                    const GeneratingTripPanel(),
                  ],
                  if (pendingDraft != null && canUsePlan) ...[
                    const SizedBox(height: 12),
                    CreateTripDraftCard(
                      draft: pendingDraft,
                      confirmed: _pendingDraftConfirmed,
                      onConfirm: () => _sendCreateTripChat('confirm'),
                      onEdit: _editPendingDraft,
                      onUse: _isPreparingPreview ? null : _usePendingDraft,
                      onChange: _sendCreateTripChat,
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: _responsivePagePadding(context, top: 8, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChatFresh && _recentChatTrips.isNotEmpty)
                      _RecentChatTripsStrip(
                        trips: _recentChatTrips,
                        promptForTrip: _recentTripPrompt,
                        onTap: _sendCreateTripChat,
                      ),
                    if (isChatFresh) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInput,
                            enabled: !_isThinking && !_isGenerating,
                            decoration: InputDecoration(
                              hintText: appText(
                                context,
                                pendingDraft == null
                                    ? 'Describe the trip...'
                                    : 'Type changes or confirm...',
                              ),
                            ),
                            onSubmitted: _sendCreateTripChat,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(54, 54),
                          ),
                          onPressed: _isThinking || _isGenerating
                              ? null
                              : () => _sendCreateTripChat(),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_mode == 2) {
      return _buildManualTripPage(context);
    }

    return _buildAiTripBuilderPage(context);
  }
}

class _TripCreationLoadingScreen extends StatelessWidget {
  const _TripCreationLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: _responsivePagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5FC),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox.square(
                          dimension: 58,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: _primary,
                          ),
                        ),
                        Icon(
                          Icons.map_rounded,
                          color: _primary.withValues(alpha: 0.9),
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    appText(context, 'Creating your trip'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appText(
                      context,
                      'Saving the itinerary, checklist, budget, and daily route.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const LinearProgressIndicator(
                    minHeight: 6,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    backgroundColor: Color(0xFFEAF0F5),
                    color: _primary,
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

class _AiTripPreviewSheet extends StatefulWidget {
  const _AiTripPreviewSheet({
    required this.preview,
    required this.selectedImage,
    required this.onConfirm,
  });

  final _PendingAiTripPreview preview;
  final String? selectedImage;
  final Future<void> Function(String? selectedImage, GeneratedTripPlan plan)
  onConfirm;

  @override
  State<_AiTripPreviewSheet> createState() => _AiTripPreviewSheetState();
}

class _AiTripPreviewSheetState extends State<_AiTripPreviewSheet> {
  late String? _selectedImage =
      widget.selectedImage ??
      (widget.preview.images.isEmpty ? null : widget.preview.images.first);
  late List<ScheduleItem> _items = [...widget.preview.plan.items];
  var _isCreating = false;

  GeneratedTripPlan get _editedPlan => GeneratedTripPlan(
    items: [..._items]..sort(_compareRuntimeScheduleItems),
    bookings: widget.preview.plan.bookings,
    checklist: widget.preview.plan.checklist,
  );

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final dayGroups = _groupPreviewItemsByDay(_items);
    final tripLength = math.max(
      1,
      preview.endDate.difference(preview.startDate).inDays + 1,
    );
    final maxPreviewDay = dayGroups.keys.fold<int>(
      tripLength,
      (maxDay, day) => math.max(maxDay, day),
    );
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(context),
              12,
              _responsiveHorizontalPadding(context),
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEE4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(icon: Icons.travel_explore_rounded, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LabelText('Trip preview'),
                        Text(
                          appText(context, preview.place.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appText(
                            context,
                            'Review searched images and daily stops before creating the trip.',
                          ),
                          style: const TextStyle(
                            color: _secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: appText(context, 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AiPreviewImageGrid(
                images: preview.images,
                selectedImage: _selectedImage,
                filterQuality: filterQuality,
                onSelect: (image) => setState(() => _selectedImage = image),
              ),
              const SizedBox(height: 16),
              ResponsiveSplit(
                children: [
                  DraftStat(
                    label: 'Dates',
                    value:
                        '${_dateKey(preview.startDate)} / ${_dateKey(preview.endDate)}',
                  ),
                  DraftStat(
                    label: 'Length',
                    value: tripLength == 1 ? '1 day' : '$tripLength days',
                  ),
                  DraftStat(
                    label: 'Budget',
                    value:
                        '${preview.currency} ${_formatAmountText(preview.budget.toString())}',
                  ),
                  DraftStat(label: 'Party', value: preview.groupType),
                ],
              ),
              if (preview.preferences.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: preview.preferences
                      .map((item) => SmallPill(label: item))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              const SectionHeader(title: 'Daily plan'),
              const SizedBox(height: 10),
              for (var day = 1; day <= maxPreviewDay; day++)
                _AiPreviewDayCard(
                  day: day,
                  date: preview.startDate.add(Duration(days: day - 1)),
                  items: dayGroups[day] ?? const [],
                  onEdit: () => _openDayEditor(
                    day: day,
                    date: preview.startDate.add(Duration(days: day - 1)),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isCreating
                    ? null
                    : () async {
                        setState(() => _isCreating = true);
                        await widget.onConfirm(_selectedImage, _editedPlan);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isCreating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  appText(
                    context,
                    _isCreating ? 'CREATING TRIP' : 'CREATE THIS TRIP',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDayEditor({
    required int day,
    required DateTime date,
  }) async {
    final place = TextEditingController();
    var isWorking = false;
    String? warning;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final dayItems = _items.where((item) => item.day == day).toList()
                ..sort(_compareRuntimeScheduleItems);

              Future<void> addPlaceWithAi() async {
                final request = place.text.trim();
                if (request.isEmpty || isWorking) return;
                setSheetState(() {
                  isWorking = true;
                  warning = null;
                });

                try {
                  final result = await TravelAssistantService()
                      .generateDayPlanEdit(
                        trip: _previewTrip(),
                        day: day,
                        placeRequest: request,
                      )
                      .timeout(const Duration(seconds: 32));
                  if (!mounted || !context.mounted) return;

                  if (!result.feasible) {
                    setSheetState(() {
                      warning = result.warning.isEmpty
                          ? 'This day looks too tight for that place. Try a closer stop or move it to another day.'
                          : result.warning;
                      isWorking = false;
                    });
                    return;
                  }

                  final nextDayItems = result.items.isEmpty
                      ? dayItems
                      : result.items;
                  setState(() {
                    _items = [
                      ..._items.where((item) => item.day != day),
                      ...nextDayItems,
                    ]..sort(_compareRuntimeScheduleItems);
                  });
                  place.clear();
                  setSheetState(() {
                    warning = result.warning.isEmpty ? null : result.warning;
                    isWorking = false;
                  });
                } catch (_) {
                  if (!context.mounted) return;
                  final fallback = _localDayEditFallback(
                    day: day,
                    request: request,
                    currentDayItems: dayItems,
                  );
                  if (fallback.feasible) {
                    setState(() {
                      _items = [
                        ..._items.where((item) => item.day != day),
                        ...fallback.items,
                      ]..sort(_compareRuntimeScheduleItems);
                    });
                    place.clear();
                  }
                  setSheetState(() {
                    warning = fallback.warning;
                    isWorking = false;
                  });
                }
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: _responsiveHorizontalPadding(context),
                    right: _responsiveHorizontalPadding(context),
                    bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
                    top: 8,
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBadge(
                                icon: Icons.edit_calendar_rounded,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LabelText('Day $day'),
                                    Text(
                                      _dateKey(date),
                                      style: const TextStyle(
                                        color: _primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: appText(context, 'Close'),
                                onPressed: isWorking
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (dayItems.isEmpty)
                            Text(
                              appText(
                                context,
                                'No stops yet. Add a place and AI will build this day.',
                              ),
                              style: const TextStyle(
                                color: _secondary,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: dayItems.length,
                                itemBuilder: (context, index) {
                                  final item = dayItems[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          item.type,
                                          color: _primary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 72,
                                          child: Text(
                                            item.time,
                                            style: const TextStyle(
                                              color: _secondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.activity,
                                            style: const TextStyle(
                                              color: _primary,
                                              fontWeight: FontWeight.w800,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: place,
                            enabled: !isWorking,
                            decoration: InputDecoration(
                              labelText: appText(context, 'Place to add'),
                              hintText: appText(
                                context,
                                'Example: Senso-ji Temple or Hokkaido day trip',
                              ),
                            ),
                            onSubmitted: (_) => unawaited(addPlaceWithAi()),
                          ),
                          if (warning != null) ...[
                            const SizedBox(height: 12),
                            FormNotice(message: warning!),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: isWorking
                                ? null
                                : () => unawaited(addPlaceWithAi()),
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: isWorking
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              appText(
                                context,
                                isWorking
                                    ? 'Checking route...'
                                    : 'ADD PLACE WITH AI',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      place.dispose();
    }
  }

  DayPlanEditResult _localDayEditFallback({
    required int day,
    required String request,
    required List<ScheduleItem> currentDayItems,
  }) {
    final unavailableWarning = _localFallbackUnavailableWarning(request);
    if (unavailableWarning != null) {
      return DayPlanEditResult(
        feasible: false,
        warning: unavailableWarning,
        items: [],
      );
    }

    final nextItems = [...currentDayItems];
    final replacementIndex = nextItems.indexWhere(_isFlexiblePlaceholderStop);
    final time = replacementIndex >= 0
        ? nextItems[replacementIndex].time
        : _localFallbackTime(nextItems);
    final item = ScheduleItem(
      day,
      time,
      _localFallbackActivity(request, widget.preview.place.name),
      _localFallbackIcon(request),
      0,
    );

    if (replacementIndex >= 0) {
      nextItems[replacementIndex] = item;
    } else {
      nextItems.add(item);
    }

    nextItems.sort(_compareRuntimeScheduleItems);
    return DayPlanEditResult(
      feasible: true,
      warning:
          'AI search is unavailable right now, so I added a provisional stop. Please confirm the exact venue, date, tickets, and opening time before relying on it.',
      items: nextItems,
    );
  }

  String? _localFallbackUnavailableWarning(String request) {
    final lower = request.toLowerCase();
    if (_requiresVerifiedEventSearch(lower)) {
      return 'I need AI search to verify event dates and venues before adding that. Try an exact event or venue name, or try again when AI is available.';
    }
    if (_containsAnyText(lower, const [
      'hokkaido',
      'sapporo',
      'okinawa',
      'osaka',
      'kyoto',
      'fukuoka',
      'seoul',
      'taipei',
      'bangkok',
      'singapore',
    ])) {
      final destination = widget.preview.place.name.toLowerCase();
      if (!_containsAnyText(destination, lower.split(RegExp(r'\s+')))) {
        return 'That looks too far from this destination for a local fallback. Try again with AI search or add it to another day.';
      }
    }
    if (!_containsAnyText(lower, const [
      'market',
      'store',
      'shop',
      'mall',
      'museum',
      'gallery',
      'cafe',
      'restaurant',
      'park',
      'temple',
      'landmark',
      'beach',
      'viewpoint',
    ])) {
      return 'AI search is unavailable right now. Try an exact nearby place name, or add this after creating the trip.';
    }
    return null;
  }

  bool _requiresVerifiedEventSearch(String lower) {
    return _containsAnyText(lower, const [
      'convention',
      'expo',
      'festival',
      'event',
      'concert',
      'show',
    ]);
  }

  bool _isFlexiblePlaceholderStop(ScheduleItem item) {
    final text = item.activity.toLowerCase();
    return _containsAnyText(text, const [
      'signature ',
      'landmark visit',
      'museum, gallery, or indoor culture',
      'local lunch area',
      'easy evening viewpoint',
      'shopping street or neighborhood browse',
      'scenic walk, riverside, or viewpoint',
      'transit-friendly district route',
    ]);
  }

  String _localFallbackTime(List<ScheduleItem> items) {
    final used = items
        .map((item) => _parseActivityTimeMinutes(item.time))
        .whereType<int>()
        .toSet();
    for (final minutes in const [15 * 60, 14 * 60, 16 * 60, 10 * 60 + 30]) {
      if (!used.contains(minutes)) {
        return _clockLabel(
          DateTime(2026, 1, 1).add(Duration(minutes: minutes)),
        );
      }
    }
    return '03:00 PM';
  }

  String _localFallbackActivity(String request, String destination) {
    final clean = request.trim();
    final lower = clean.toLowerCase();
    if (_containsAnyText(lower, const [
      'anime',
      'manga',
      'cosplay',
      'convention',
      'expo',
    ])) {
      return 'Visit $clean in $destination; confirm venue, ticket time, and entry rules.';
    }
    if (_containsAnyText(lower, const ['store', 'shop'])) {
      return 'Visit $clean in $destination; confirm the nearest branch and opening hours.';
    }
    if (_containsAnyText(lower, const ['festival', 'event', 'market'])) {
      return 'Look for $clean in $destination; confirm dates, venue, and tickets before going.';
    }
    return 'Add $clean to this day; confirm travel time and opening hours before going.';
  }

  IconData _localFallbackIcon(String request) {
    final lower = request.toLowerCase();
    if (_containsAnyText(lower, const ['anime', 'manga', 'movie', 'cosplay'])) {
      return Icons.movie_rounded;
    }
    if (_containsAnyText(lower, const ['food', 'restaurant', 'lunch'])) {
      return Icons.restaurant_rounded;
    }
    if (_containsAnyText(lower, const ['store', 'shop', 'market'])) {
      return Icons.shopping_bag_rounded;
    }
    if (_containsAnyText(lower, const ['museum', 'gallery'])) {
      return Icons.museum_rounded;
    }
    return Icons.place_rounded;
  }

  Trip _previewTrip() {
    final preview = widget.preview;
    return Trip(
      id: 'preview-${preview.place.placeId}',
      destination: preview.place.name,
      placeId: preview.place.placeId,
      formattedAddress: preview.place.formatted,
      latitude: preview.place.latitude,
      longitude: preview.place.longitude,
      originLabel: preview.startLocation?.displayLabel,
      originLatitude: preview.startLocation?.latitude,
      originLongitude: preview.startLocation?.longitude,
      startDate: _dateKey(preview.startDate),
      endDate: _dateKey(preview.endDate),
      budget: preview.budget,
      spent: 0,
      groupType: preview.groupType,
      currency: preview.currency,
      status: TripStatus.upcoming,
      images: preview.images,
      items: [..._items],
      bookings: preview.plan.bookings,
      checklist: preview.plan.checklist,
      preferences: preview.preferences,
      budgetCategories: const [],
    );
  }
}

Map<int, List<ScheduleItem>> _groupPreviewItemsByDay(List<ScheduleItem> items) {
  final groups = <int, List<ScheduleItem>>{};
  for (final item in items) {
    groups.putIfAbsent(math.max(1, item.day), () => []).add(item);
  }
  for (final group in groups.values) {
    group.sort(_compareRuntimeScheduleItems);
  }
  return groups;
}

bool _containsAnyText(String value, Iterable<String> keywords) {
  return keywords.any((keyword) {
    final trimmed = keyword.trim();
    return trimmed.isNotEmpty && value.contains(trimmed);
  });
}

class _AiPreviewImageGrid extends StatelessWidget {
  const _AiPreviewImageGrid({
    required this.images,
    required this.selectedImage,
    required this.filterQuality,
    required this.onSelect,
  });

  final List<String> images;
  final String? selectedImage;
  final FilterQuality filterQuality;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText(context, 'Searched images'),
          style: const TextStyle(
            color: _primary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final heroWidth = isWide
                ? (constraints.maxWidth - 10) * .58
                : constraints.maxWidth;
            final tileWidth = isWide
                ? (constraints.maxWidth - heroWidth - 30) / 2
                : (constraints.maxWidth - 10) / 2;
            final heroImage = selectedImage ?? images.first;
            final thumbnailImages = images
                .where((item) => item != heroImage)
                .take(4);
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: heroWidth,
                  height: 210,
                  child: _AiPreviewImageTile(
                    image: heroImage,
                    selected: true,
                    large: true,
                    filterQuality: filterQuality,
                    onTap: () {},
                  ),
                ),
                for (final image in thumbnailImages)
                  SizedBox(
                    width: math.max(120.0, tileWidth),
                    height: isWide ? 100 : 112,
                    child: _AiPreviewImageTile(
                      image: image,
                      selected: false,
                      large: false,
                      filterQuality: filterQuality,
                      onTap: () => onSelect(image),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AiPreviewImageTile extends StatelessWidget {
  const _AiPreviewImageTile({
    required this.image,
    required this.selected,
    required this.large,
    required this.filterQuality,
    required this.onTap,
  });

  final String image;
  final bool selected;
  final bool large;
  final FilterQuality filterQuality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                filterQuality: filterQuality,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF4F8FA),
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: const Color(0xFFACCBE0),
                    size: large ? 48 : 28,
                  ),
                ),
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _accent, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.touch_app_rounded,
                        color: _primary,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        appText(context, selected ? 'Cover' : 'Select'),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiPreviewDayCard extends StatelessWidget {
  const _AiPreviewDayCard({
    required this.day,
    required this.date,
    required this.items,
    required this.onEdit,
  });

  final int day;
  final DateTime date;
  final List<ScheduleItem> items;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF3F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SmallPill(label: 'Day $day'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateKey(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: appText(context, 'Edit day'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: _primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              appText(context, 'Open time to adjust after creating the trip.'),
              style: const TextStyle(
                color: _secondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            for (final item in items.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.type, color: _primary, size: 19),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 72,
                      child: Text(
                        item.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        appText(context, item.activity),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
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

String _templateFormatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _templateBudgetLabel(Trip trip) =>
    '${trip.currency} ${_templateFormatNumber(trip.budget)}';

String _templateImageFor(Trip trip) => trip.images.isNotEmpty
    ? trip.images.first
    : _imagesForDestination(trip.destination).first;

class _TemplatePickerHero extends StatelessWidget {
  const _TemplatePickerHero({
    required this.pastCount,
    required this.recommendationCount,
  });

  final int pastCount;
  final int recommendationCount;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const IconBadge(icon: Icons.view_agenda_rounded, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Choose a starting point'),
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(
                    context,
                    'Preview saved past trips or recommendation cards before creating the itinerary.',
                  ),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallPill(label: '$pastCount past'),
                    SmallPill(label: '$recommendationCount recommended'),
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

class _EmptyTemplateState extends StatelessWidget {
  const _EmptyTemplateState();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const IconBadge(icon: Icons.history_toggle_off_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appText(
                context,
                'No past trips yet. Completed trips will appear here as reusable templates.',
              ),
              style: const TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCardGrid extends StatelessWidget {
  const _TemplateCardGrid({required this.templates, required this.onPreview});

  final List<_TripTemplate> templates;
  final ValueChanged<_TripTemplate> onPreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 640
            ? 2
            : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final template in templates)
              SizedBox(
                width: itemWidth,
                child: _TemplateCard(
                  template: template,
                  onPreview: () => onPreview(template),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onPreview});

  final _TripTemplate template;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final trip = template.trip;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPreview,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEFF3F6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: AspectRatio(
                  aspectRatio: 1.75,
                  child: Image.network(
                    _templateImageFor(trip),
                    fit: BoxFit.cover,
                    filterQuality: PerformanceScope.maybeSettingsOf(
                      context,
                    ).filterQuality,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: _primary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SmallPill(label: template.badge),
                        SmallPill(label: template.source),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appText(
                        context,
                        trip.title.trim().isEmpty
                            ? trip.destination
                            : trip.title,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      appText(context, trip.destination),
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
                      appText(context, template.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TemplateMetaPill(
                          icon: Icons.calendar_month_rounded,
                          label: '${trip.startDate} / ${trip.endDate}',
                        ),
                        _TemplateMetaPill(
                          icon: Icons.payments_rounded,
                          label: _templateBudgetLabel(trip),
                        ),
                        _TemplateMetaPill(
                          icon: Icons.route_rounded,
                          label: '${trip.items.length} stops',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onPreview,
                        icon: const Icon(Icons.visibility_rounded),
                        label: Text(
                          appText(context, 'Preview itinerary'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatePreviewSheet extends StatelessWidget {
  const _TemplatePreviewSheet({
    required this.template,
    required this.lengthDays,
    required this.onConfirm,
  });

  final _TripTemplate template;
  final int lengthDays;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final trip = template.trip;
    final height = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = trip.title.trim().isEmpty ? trip.destination : trip.title;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(context),
              16,
              _responsiveHorizontalPadding(context),
              16 + bottomInset,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: math.min(height * .9, 760),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: template.source == 'Past trip'
                              ? Icons.history_rounded
                              : Icons.public_rounded,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appText(context, title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                appText(context, template.source),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: AspectRatio(
                              aspectRatio: 1.9,
                              child: Image.network(
                                _templateImageFor(trip),
                                fit: BoxFit.cover,
                                filterQuality: PerformanceScope.maybeSettingsOf(
                                  context,
                                ).filterQuality,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: _primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SmallPill(label: '$lengthDays days'),
                              SmallPill(label: _templateBudgetLabel(trip)),
                              SmallPill(label: trip.groupType),
                              for (final tag in trip.preferences.take(3))
                                SmallPill(label: tag),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            appText(context, template.description),
                            style: const TextStyle(
                              color: _secondary,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const LabelText('Itinerary preview'),
                          const SizedBox(height: 10),
                          for (final item in trip.items.take(10)) ...[
                            _PreviewScheduleRow(item: item),
                            const SizedBox(height: 8),
                          ],
                          if (trip.bookings.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const LabelText('Bookings'),
                            const SizedBox(height: 10),
                            for (final booking in trip.bookings.take(3)) ...[
                              _PreviewBookingRow(booking: booking),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: PrimaryButton(
                      label: 'Use this template',
                      icon: Icons.check_rounded,
                      onPressed: onConfirm,
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

class _TemplateMetaPill extends StatelessWidget {
  const _TemplateMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF3F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _secondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              appText(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _secondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScheduleRow extends StatelessWidget {
  const _PreviewScheduleRow({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconBadge(icon: item.type, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Day ${item.day} / ${item.time}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, item.activity),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (item.cost > 0) ...[
            const SizedBox(width: 8),
            Text(
              _templateFormatNumber(item.cost),
              style: const TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewBookingRow extends StatelessWidget {
  const _PreviewBookingRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconBadge(icon: booking.icon, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, booking.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, '${booking.date} / ${booking.time}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _AiChoice {
  const _AiChoice({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
}

class _RecentChatTripsStrip extends StatelessWidget {
  const _RecentChatTripsStrip({
    required this.trips,
    required this.promptForTrip,
    required this.onTap,
  });

  final List<Trip> trips;
  final String Function(Trip trip) promptForTrip;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final trip = trips[index];
          return _RecentChatTripCard(
            trip: trip,
            onTap: () => onTap(promptForTrip(trip)),
          );
        },
      ),
    );
  }
}

class _RecentChatTripCard extends StatelessWidget {
  const _RecentChatTripCard({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateText = trip.startDate == trip.endDate
        ? trip.startDate
        : '${trip.startDate} / ${trip.endDate}';
    return SizedBox(
      width: 238,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE6EDF2)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Image.network(
                        _templateImageFor(trip),
                        fit: BoxFit.cover,
                        filterQuality: PerformanceScope.maybeSettingsOf(
                          context,
                        ).filterQuality,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE7F3FC),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.place_rounded,
                            color: _primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, trip.destination),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appText(context, dateText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appText(context, _templateBudgetLabel(trip)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.north_east_rounded,
                    color: Color(0xFF82B6DA),
                    size: 16,
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

class _AiChoiceGrid extends StatelessWidget {
  const _AiChoiceGrid({required this.choices});

  final List<_AiChoice> choices;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final choice in choices) _AiChoiceCard(choice: choice)],
    );
  }
}

class _AiChoiceCard extends StatelessWidget {
  const _AiChoiceCard({required this.choice});

  final _AiChoice choice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: choice.onTap,
        child: Tooltip(
          message: appText(context, choice.text),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFACCBE0).withValues(alpha: .6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(choice.icon, color: const Color(0xFF355872), size: 17),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    appText(context, choice.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF355872),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF72787C),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiInputGrid extends StatelessWidget {
  const _AiInputGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final tileWidth =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class _AiInputCard extends StatelessWidget {
  const _AiInputCard({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.loading = false,
    this.action,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF355872), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appText(context, label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF42474C),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (loading)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    color: Color(0xFF1B1C19),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: appText(context, hint),
                    hintStyle: TextStyle(
                      color: const Color(0xFF72787C).withValues(alpha: .68),
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

class _AiPickerCard extends StatelessWidget {
  const _AiPickerCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(appText(context, option))),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC2C7CC).withValues(alpha: .24),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF355872), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    appText(context, label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF42474C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appText(context, value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF355872),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Color(0xFF72787C)),
          ],
        ),
      ),
    );
  }
}

class _AiDateRangeCard extends StatelessWidget {
  const _AiDateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.tripLength,
    required this.onTap,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int tripLength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFC2C7CC).withValues(alpha: .24),
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AiDateChip(
                icon: Icons.today_rounded,
                label: 'Start',
                value: _dateKey(startDate),
              ),
              _AiDateChip(
                icon: Icons.event_available_rounded,
                label: 'End',
                value: _dateKey(endDate),
              ),
              _AiDateChip(
                icon: Icons.timelapse_rounded,
                label: 'AI span',
                value: '$tripLength ${tripLength == 1 ? 'day' : 'days'}',
              ),
              const _AiDateEditHint(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiDateChip extends StatelessWidget {
  const _AiDateChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF355872), size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF72787C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 12,
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

class _AiDateEditHint extends StatelessWidget {
  const _AiDateEditHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF355872),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.edit_calendar_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            appText(context, 'Adjust dates'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCustomTagCard extends StatelessWidget {
  const _AiCustomTagCard({required this.controller, required this.onAdd});

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _AiInputCard(
      label: 'Add AI instruction tag',
      icon: Icons.label_rounded,
      controller: controller,
      hint: 'anime, halal food, wheelchair access',
      action: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF355872),
          foregroundColor: Colors.white,
        ),
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _AiTagCloudCard extends StatelessWidget {
  const _AiTagCloudCard({
    required this.title,
    required this.preferences,
    required this.selectedPreferences,
    required this.onToggle,
  });

  final String title;
  final List<String> preferences;
  final Set<String> selectedPreferences;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF355872),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, title),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preference in preferences)
                FilterChip(
                  selected: selectedPreferences.contains(preference),
                  label: Text(appText(context, preference)),
                  onSelected: (_) => onToggle(preference),
                  selectedColor: const Color(0xFF355872),
                  checkmarkColor: Colors.white,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selectedPreferences.contains(preference)
                        ? const Color(0xFF355872)
                        : const Color(0xFFC2C7CC).withValues(alpha: .45),
                  ),
                  labelStyle: TextStyle(
                    color: selectedPreferences.contains(preference)
                        ? Colors.white
                        : const Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiContextNote extends StatelessWidget {
  const _AiContextNote({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF355872), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${appText(context, title)}  ',
                    style: const TextStyle(
                      color: Color(0xFF355872),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: appText(context, text),
                    style: const TextStyle(
                      color: Color(0xFF42474C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _TransportRecommendationCard extends StatelessWidget {
  const _TransportRecommendationCard({
    required this.available,
    required this.loading,
    required this.summary,
    required this.error,
    required this.options,
    required this.currency,
    required this.onRefresh,
  });

  final bool available;
  final bool loading;
  final String? summary;
  final String? error;
  final List<TransportRecommendation> options;
  final String currency;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: Color(0xFF355872)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, 'Recommended transportation'),
                      style: const TextStyle(
                        color: Color(0xFF355872),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      appText(
                        context,
                        'Sorted from cheaper to more expensive using current web results when available.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF72787C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: available && !loading ? onRefresh : null,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore_rounded),
                label: Text(appText(context, loading ? 'Searching' : 'Find')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!available)
            const _AiContextNote(
              icon: Icons.lock_rounded,
              title: 'Route required',
              text:
                  'Choose both destination and start location before searching transport prices.',
            )
          else ...[
            if (summary != null && summary!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  appText(context, summary!),
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            if (error != null) FormNotice(message: error!),
            if (options.isEmpty && error == null && !loading)
              Text(
                appText(
                  context,
                  'Press Find to compare train, bus, flight, and transfer options.',
                ),
                style: const TextStyle(
                  color: Color(0xFF72787C),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            for (final option in options)
              _TransportRecommendationTile(
                option: option,
                fallbackCurrency: currency,
              ),
          ],
        ],
      ),
    );
  }
}

class _TransportRecommendationTile extends StatelessWidget {
  const _TransportRecommendationTile({
    required this.option,
    required this.fallbackCurrency,
  });

  final TransportRecommendation option;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final currency = option.currency.isEmpty
        ? fallbackCurrency
        : option.currency;
    final priceLabel = option.price > 0
        ? '$currency ${_formatAmountText(option.price.toString())}'
        : option.sourceName == 'Your ticket'
        ? appText(context, 'Booked')
        : appText(context, 'Price varies');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFF3F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_transportIcon(option.mode), color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  option.route,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (option.bookingHint.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    option.bookingHint,
                    style: const TextStyle(
                      color: Color(0xFF72787C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceLabel,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (option.duration.isNotEmpty)
                Text(
                  option.duration,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (option.sourceName.isNotEmpty)
                Text(
                  option.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF79ACD8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _transportIcon(String mode) {
  final lower = mode.toLowerCase();
  if (lower.contains('flight') || lower.contains('plane')) {
    return Icons.flight_takeoff_rounded;
  }
  if (lower.contains('train') || lower.contains('rail')) {
    return Icons.train_rounded;
  }
  if (lower.contains('bus')) return Icons.directions_bus_rounded;
  if (lower.contains('taxi') || lower.contains('car')) {
    return Icons.local_taxi_rounded;
  }
  return Icons.route_rounded;
}

class _PurchasedFlightCard extends StatelessWidget {
  const _PurchasedFlightCard({
    required this.airline,
    required this.flightCode,
    required this.passengerName,
    required this.departTime,
    required this.departPlace,
    required this.landingTime,
    required this.landingPlace,
    required this.paidAmount,
    required this.currency,
    required this.onChanged,
  });

  final TextEditingController airline;
  final TextEditingController flightCode;
  final TextEditingController passengerName;
  final TextEditingController departTime;
  final TextEditingController departPlace;
  final TextEditingController landingTime;
  final TextEditingController landingPlace;
  final TextEditingController paidAmount;
  final String currency;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_takeoff_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, 'Already bought a flight'),
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            appText(
              context,
              'Optional flight timing. Paid amount is saved as spent transport budget.',
            ),
            style: const TextStyle(
              color: Color(0xFF72787C),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _AiInputGrid(
            children: [
              _AiInputCard(
                label: 'Airline',
                icon: Icons.flight_takeoff_rounded,
                controller: airline,
                hint: 'China Airlines',
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Flight number',
                icon: Icons.confirmation_number_rounded,
                controller: flightCode,
                hint: 'CI751 / BR123',
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Name under ticket',
                icon: Icons.badge_rounded,
                controller: passengerName,
                hint: 'Passenger name',
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Depart time',
                icon: Icons.schedule_rounded,
                controller: departTime,
                hint: '23:30',
                keyboardType: TextInputType.datetime,
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Depart place',
                icon: Icons.flight_takeoff_rounded,
                controller: departPlace,
                hint: 'Taipei Taoyuan TPE',
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Landing time',
                icon: Icons.schedule_rounded,
                controller: landingTime,
                hint: '19:15',
                keyboardType: TextInputType.datetime,
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Landing place',
                icon: Icons.flight_land_rounded,
                controller: landingPlace,
                hint: 'Paris CDG',
                onChanged: (_) => onChanged(),
              ),
              _AiInputCard(
                label: 'Already paid',
                icon: Icons.payments_rounded,
                controller: paidAmount,
                hint: '$currency amount',
                keyboardType: TextInputType.number,
                inputFormatters: const [_GroupedNumberInputFormatter()],
                onChanged: (_) => onChanged(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiBuilderHero extends StatelessWidget {
  const _AiBuilderHero({
    required this.destination,
    required this.tripLength,
    required this.budgetLabel,
    required this.selectedSuggestionCount,
    required this.expanded,
    required this.onToggle,
  });

  final String destination;
  final int tripLength;
  final String budgetLabel;
  final int selectedSuggestionCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.maybeSettingsOf(context);
    final duration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;
    final hasDestination = destination.isNotEmpty;
    final dayLabel = tripLength == 1
        ? appText(context, 'day')
        : appText(context, 'days');
    final suggestionLabel = selectedSuggestionCount == 1
        ? appText(context, 'AI focus')
        : appText(context, 'AI focuses');
    final destinationLabel = hasDestination
        ? destination
        : appText(context, 'Waiting for destination');
    final budgetText = budgetLabel.isEmpty
        ? appText(context, 'Waiting for budget')
        : budgetLabel;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: expanded
                  ? const Color(0xFF355872).withValues(alpha: .28)
                  : const Color(0xFFC2C7CC).withValues(alpha: .24),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF355872,
                ).withValues(alpha: expanded ? .1 : .06),
                blurRadius: expanded ? 32 : 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF355872),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, 'AI planning workspace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appText(
                            context,
                            '$destinationLabel / $tripLength $dayLabel / $selectedSuggestionCount $suggestionLabel',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF42474C),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appText(context, expanded ? 'Hide' : 'Details'),
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: expanded ? .5 : 0,
                          duration: duration,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF355872),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeInOutCubic,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F8FA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.tips_and_updates_rounded,
                                    color: Color(0xFF355872),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      appText(
                                        context,
                                        'AI will use your picks as signals, then build a starter itinerary you can still edit.',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF42474C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _AiHeroMetric(
                                  icon: Icons.place_rounded,
                                  label: 'Destination',
                                  value: destinationLabel,
                                ),
                                _AiHeroMetric(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'Duration',
                                  value: '$tripLength $dayLabel',
                                ),
                                _AiHeroMetric(
                                  icon: Icons.payments_rounded,
                                  label: 'Budget',
                                  value: budgetText,
                                ),
                                _AiHeroMetric(
                                  icon: Icons.psychology_alt_rounded,
                                  label: 'Suggestions',
                                  value:
                                      '$selectedSuggestionCount $suggestionLabel',
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiHeroMetric extends StatelessWidget {
  const _AiHeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFC2C7CC).withValues(alpha: .22),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF355872)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF72787C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF355872),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

class _AiSuggestionDeck extends StatelessWidget {
  const _AiSuggestionDeck({
    required this.goals,
    required this.selectedGoalIds,
    required this.onToggle,
  });

  final List<PlanningGoal> goals;
  final Set<String> selectedGoalIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                color: Color(0xFF355872),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, 'Trip style'),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appText(
              context,
              'Choose the planning priorities AI should use when building the itinerary.',
            ),
            style: const TextStyle(
              color: Color(0xFF42474C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (10 * (columns - 1))) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final goal in goals)
                    SizedBox(
                      width: constraints.maxWidth < 430
                          ? constraints.maxWidth
                          : width,
                      child: _AiSuggestionCard(
                        goal: goal,
                        selected: selectedGoalIds.contains(goal.id),
                        onTap: () => onToggle(goal.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiSuggestionCard extends StatelessWidget {
  const _AiSuggestionCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final PlanningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF355872) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF355872)
                  : const Color(0xFFC2C7CC).withValues(alpha: .28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                goal.icon,
                color: selected ? Colors.white : const Color(0xFF355872),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: appText(context, goal.text),
                  child: Text(
                    appText(context, goal.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF355872),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                color: selected ? Colors.white : const Color(0xFF72787C),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiAccordionSection extends StatelessWidget {
  const _AiAccordionSection({
    required this.icon,
    required this.title,
    required this.suggestion,
    required this.expanded,
    required this.complete,
    required this.attention,
    required this.onToggle,
    required this.onDone,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String suggestion;
  final bool expanded;
  final bool complete;
  final bool attention;
  final VoidCallback onToggle;
  final VoidCallback onDone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.maybeSettingsOf(context);
    final duration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;
    final showAttention = attention && !complete;
    final borderColor = complete
        ? const Color(0xFF16A34A).withValues(alpha: .5)
        : showAttention
        ? const Color(0xFF355872).withValues(alpha: .65)
        : const Color(0xFFC2C7CC).withValues(alpha: .24);
    final headerColor = expanded
        ? const Color(0xFFF7F8F0)
        : showAttention
        ? const Color(0xFFF4F8FA)
        : Colors.white;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: showAttention
                ? const Color(0xFF355872).withValues(alpha: .16)
                : const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: showAttention ? 30 : 24,
            offset: Offset(0, showAttention ? 10 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: headerColor,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: complete
                              ? const Color(0xFF16A34A)
                              : showAttention
                              ? const Color(0xFF355872)
                              : const Color(0xFFC8E7FC).withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : icon,
                          color: complete
                              ? Colors.white
                              : showAttention
                              ? Colors.white
                              : const Color(0xFF355872),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appText(context, title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF355872),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF72787C),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      appText(context, suggestion),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF72787C),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: duration,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF72787C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves.easeInOutCubic,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF355872),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: onDone,
                              icon: const Icon(Icons.check_rounded, size: 17),
                              label: Text(appText(context, 'Done')),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiGenerateFooter extends StatelessWidget {
  const _AiGenerateFooter({required this.label, required this.onGenerate});

  final String label;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFC2C7CC).withValues(alpha: .3)),
        ),
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF355872),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        onPressed: onGenerate,
        icon: const Icon(Icons.auto_awesome_rounded, size: 19),
        label: Text(
          appText(context, label),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ManualTopBar extends StatelessWidget {
  const _ManualTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F0).withValues(alpha: .9),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFC2C7CC).withValues(alpha: .32),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _responsiveHorizontalPadding(context),
          10,
          _responsiveHorizontalPadding(context),
          10,
        ),
        child: Row(
          children: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF42474C),
              ),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appText(context, title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF355872),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualStepRail extends StatelessWidget {
  const _ManualStepRail({
    required this.expandedStep,
    required this.completedSteps,
  });

  final int? expandedStep;
  final List<bool> completedSteps;

  static const _steps = [
    ('Trip Basics', 'Where, when, who'),
    ('Destination', 'Where to visit'),
    ('Timing', 'Dates and duration'),
    ('Budget', 'Set your budget'),
    ('Preferences', 'Travel style and needs'),
    ('Review', 'Create and refine'),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 39,
          top: 24,
          bottom: 28,
          child: Container(
            width: 2,
            color: const Color(0xFFC2C7CC).withValues(alpha: .35),
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < _steps.length; index++) ...[
              _ManualStepItem(
                number: index + 1,
                title: _steps[index].$1,
                text: _steps[index].$2,
                active: expandedStep == index,
                complete:
                    index < completedSteps.length && completedSteps[index],
              ),
              if (index != _steps.length - 1) const SizedBox(height: 22),
            ],
          ],
        ),
      ],
    );
  }
}

class _ManualStepItem extends StatelessWidget {
  const _ManualStepItem({
    required this.number,
    required this.title,
    required this.text,
    required this.active,
    required this.complete,
  });

  final int number;
  final String title;
  final String text;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final titleColor = active
        ? const Color(0xFF355872)
        : const Color(0xFF42474C);
    return Opacity(
      opacity: active || complete ? 1 : .54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete
                  ? const Color(0xFF16A34A)
                  : active
                  ? const Color(0xFF355872)
                  : const Color(0xFFE3E3DD),
              shape: BoxShape.circle,
              border: Border.all(
                color: complete
                    ? const Color(0xFF16A34A)
                    : active
                    ? const Color(0xFF355872)
                    : const Color(0xFFC2C7CC),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF355872).withValues(alpha: .18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: complete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF42474C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ManualAccordionSection extends StatelessWidget {
  const _ManualAccordionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.complete,
    required this.attention,
    required this.onToggle,
    required this.onContinue,
    required this.children,
    this.continueLabel = 'Continue',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final bool complete;
  final bool attention;
  final VoidCallback onToggle;
  final VoidCallback onContinue;
  final List<Widget> children;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.maybeSettingsOf(context);
    final duration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;
    final showAttention = attention && !complete;
    final borderColor = complete
        ? const Color(0xFF16A34A).withValues(alpha: .45)
        : showAttention
        ? const Color(0xFF355872).withValues(alpha: .65)
        : const Color(0xFFC2C7CC).withValues(alpha: .24);
    final headerColor = expanded
        ? const Color(0xFFF7F8F0)
        : showAttention
        ? const Color(0xFFF4F8FA)
        : Colors.white;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: showAttention
                ? const Color(0xFF355872).withValues(alpha: .16)
                : const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: showAttention ? 30 : 24,
            offset: Offset(0, showAttention ? 10 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: headerColor,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: complete
                              ? const Color(0xFF16A34A)
                              : showAttention
                              ? const Color(0xFF355872)
                              : const Color(0xFFC8E7FC).withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : icon,
                          color: complete
                              ? Colors.white
                              : showAttention
                              ? Colors.white
                              : const Color(0xFF355872),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appText(context, title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF355872),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 3),
                              Text(
                                appText(context, subtitle),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF42474C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: duration,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF72787C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves.easeInOutCubic,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...children,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF355872),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: onContinue,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(appText(context, continueLabel)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualGrid extends StatelessWidget {
  const _ManualGrid({required this.children, required this.minTileWidth});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        final columns = math.max(
          1,
          ((width + spacing) / (minTileWidth + spacing)).floor(),
        );
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _ManualFieldCard extends StatelessWidget {
  const _ManualFieldCard({
    required this.label,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String label;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .22),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                child,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, color: const Color(0xFF72787C), size: 22),
          ],
        ],
      ),
    );
  }
}

class _ManualTextField extends StatelessWidget {
  const _ManualTextField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        color: Color(0xFF1B1C19),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: appText(context, hint),
        hintStyle: TextStyle(
          color: const Color(0xFF72787C).withValues(alpha: .7),
          fontWeight: FontWeight.w600,
        ),
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _ManualDateRangeCard extends StatelessWidget {
  const _ManualDateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.tripLength,
    required this.onTap,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int tripLength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFC2C7CC).withValues(alpha: .28),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final dateCards = [
                _ManualDateSummary(
                  label: 'Start',
                  value: _dateKey(startDate),
                  icon: Icons.today_rounded,
                ),
                _ManualDateSummary(
                  label: 'End',
                  value: _dateKey(endDate),
                  icon: Icons.event_available_rounded,
                ),
                _ManualDateSummary(
                  label: 'Duration',
                  value: '$tripLength ${tripLength == 1 ? 'day' : 'days'}',
                  icon: Icons.timelapse_rounded,
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF355872),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appText(context, 'Trip dates'),
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar_rounded,
                        color: Color(0xFF72787C),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (compact)
                    Column(
                      children: [
                        for (var index = 0; index < dateCards.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == dateCards.length - 1 ? 0 : 8,
                            ),
                            child: dateCards[index],
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        for (
                          var index = 0;
                          index < dateCards.length;
                          index++
                        ) ...[
                          Expanded(child: dateCards[index]),
                          if (index != dateCards.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ManualDateSummary extends StatelessWidget {
  const _ManualDateSummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF72787C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appText(context, value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1B1C19),
                    fontSize: 13,
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

class _ManualDropdownCard extends StatelessWidget {
  const _ManualDropdownCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(appText(context, option))),
      ],
      child: _ManualFieldCard(
        label: label,
        icon: icon,
        child: Text(
          appText(context, value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1B1C19),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ManualChipCard extends StatelessWidget {
  const _ManualChipCard({
    required this.title,
    required this.preferences,
    required this.selectedPreferences,
    required this.onToggle,
  });

  final String title;
  final List<String> preferences;
  final Set<String> selectedPreferences;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .22),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, title),
            style: const TextStyle(
              color: Color(0xFF42474C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preference in preferences)
                FilterChip(
                  selected: selectedPreferences.contains(preference),
                  label: Text(appText(context, preference)),
                  onSelected: (_) => onToggle(preference),
                  selectedColor: const Color(0xFF355872),
                  checkmarkColor: Colors.white,
                  backgroundColor: const Color(0xFFE3E3DD),
                  side: BorderSide(
                    color: selectedPreferences.contains(preference)
                        ? const Color(0xFF355872)
                        : const Color(0xFFC2C7CC).withValues(alpha: .45),
                  ),
                  labelStyle: TextStyle(
                    color: selectedPreferences.contains(preference)
                        ? Colors.white
                        : const Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualCustomTagCard extends StatelessWidget {
  const _ManualCustomTagCard({required this.controller, required this.onAdd});

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ManualFieldCard(
            label: 'Add custom tag',
            icon: Icons.label_rounded,
            child: _ManualTextField(
              controller: controller,
              hint: 'anime, halal food, wheelchair access',
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF355872),
            foregroundColor: Colors.white,
            fixedSize: const Size(54, 54),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _ManualNoticeCard extends StatelessWidget {
  const _ManualNoticeCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF355872)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, title),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  appText(context, text),
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _ManualPreviewCard extends StatelessWidget {
  const _ManualPreviewCard({
    required this.completedSections,
    required this.totalSections,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.tripLength,
    required this.budget,
    required this.group,
    required this.preferences,
    required this.expanded,
    required this.onToggle,
  });

  final int completedSections;
  final int totalSections;
  final String destination;
  final String startDate;
  final String endDate;
  final int tripLength;
  final String budget;
  final String group;
  final List<String> preferences;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final progress = totalSections == 0
        ? 0.0
        : (completedSections / totalSections).clamp(0.0, 1.0);
    final destinationText = destination.isEmpty
        ? appText(context, 'Choose a destination')
        : destination;
    final budgetText = budget.isEmpty ? appText(context, 'Add budget') : budget;
    final visiblePreferences = preferences.take(3).toList();
    final preferenceText = visiblePreferences.isEmpty
        ? appText(context, 'Pick travel style')
        : [
            group,
            visiblePreferences.join(', '),
            if (preferences.length > visiblePreferences.length)
              '+${preferences.length - visiblePreferences.length} more',
          ].where((value) => value.trim().isNotEmpty).join(' | ');
    final dayLabel = tripLength == 1
        ? appText(context, 'day')
        : appText(context, 'days');
    final imageUrl = _imagesForDestination(destinationText).first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 660;
        final image = _ManualPreviewImage(
          imageUrl: imageUrl,
          destination: destinationText,
        );
        final details = _ManualPreviewDetails(
          destination: destinationText,
          dateRange: '$startDate to $endDate',
          duration: '$tripLength $dayLabel',
          budget: budgetText,
          preferenceText: preferenceText,
          completedSections: completedSections,
          totalSections: totalSections,
          progress: progress.toDouble(),
          expanded: expanded,
          onToggle: onToggle,
        );

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC2C7CC).withValues(alpha: .22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF355872).withValues(alpha: .06),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 250,
                          height: expanded ? 248 : 172,
                          child: image,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 178, child: image),
                        const SizedBox(height: 14),
                        details,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ManualPreviewImage extends StatelessWidget {
  const _ManualPreviewImage({
    required this.imageUrl,
    required this.destination,
  });

  final String imageUrl;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            filterQuality: filterQuality,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF4F8FA),
              child: const Icon(
                Icons.landscape_rounded,
                color: Color(0xFFACCBE0),
                size: 54,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .02),
                  Colors.black.withValues(alpha: .46),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          color: Color(0xFF355872),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          appText(context, 'Preview'),
                          style: const TextStyle(
                            color: Color(0xFF355872),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
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

class _ManualPreviewDetails extends StatelessWidget {
  const _ManualPreviewDetails({
    required this.destination,
    required this.dateRange,
    required this.duration,
    required this.budget,
    required this.preferenceText,
    required this.completedSections,
    required this.totalSections,
    required this.progress,
    required this.expanded,
    required this.onToggle,
  });

  final String destination;
  final String dateRange;
  final String duration;
  final String budget;
  final String preferenceText;
  final int completedSections;
  final int totalSections;
  final double progress;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isComplete = completedSections == totalSections;
    final performance = PerformanceScope.maybeSettingsOf(context);
    final duration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFC8E7FC).withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isComplete ? Icons.check_rounded : Icons.map_rounded,
                  color: isComplete ? Colors.white : const Color(0xFF355872),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, 'Trip preview'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF355872),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appText(
                        context,
                        '$completedSections of $totalSections sections filled',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF42474C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: appText(
                  context,
                  expanded ? 'Hide details' : 'Show details',
                ),
                onPressed: onToggle,
                icon: AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: duration,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF72787C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: const Color(0xFFE3E3DD)),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    color: isComplete
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF355872),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            appText(context, expanded ? 'Hide details' : 'View all details'),
            style: const TextStyle(
              color: Color(0xFF355872),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeInOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        _ManualPreviewInfoRow(
                          icon: Icons.place_rounded,
                          label: 'Destination',
                          value: destination,
                        ),
                        _ManualPreviewInfoRow(
                          icon: Icons.event_rounded,
                          label: 'Dates',
                          value: dateRange,
                          helper: this.duration,
                        ),
                        _ManualPreviewInfoRow(
                          icon: Icons.payments_rounded,
                          label: 'Budget',
                          value: budget,
                        ),
                        _ManualPreviewInfoRow(
                          icon: Icons.tune_rounded,
                          label: 'Style',
                          value: preferenceText,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ManualPreviewInfoRow extends StatelessWidget {
  const _ManualPreviewInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF355872), size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF72787C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (helper != null) ...[
                  Text(
                    helper!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF42474C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class _ManualInfoBanner extends StatelessWidget {
  const _ManualInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appText(context, 'Not sure where to start?'),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(
                    context,
                    'Add the basics now, then build the day-by-day schedule after creation.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF42474C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.landscape_rounded,
            size: 68,
            color: Color(0xFFACCBE0),
          ),
        ],
      ),
    );
  }
}

class _ManualFooterActions extends StatelessWidget {
  const _ManualFooterActions({
    required this.onCancel,
    required this.onCreate,
    required this.isCreating,
  });

  final VoidCallback onCancel;
  final VoidCallback onCreate;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFC2C7CC).withValues(alpha: .3)),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text(
              appText(context, 'Cancel'),
              style: const TextStyle(
                color: Color(0xFF42474C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF355872),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: isCreating ? null : onCreate,
            icon: isCreating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              appText(context, isCreating ? 'Creating' : 'Create manually'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedNumberInputFormatter extends TextInputFormatter {
  const _GroupedNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatDigits(String digits) {
    final normalized = int.parse(digits).toString();
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      final remaining = normalized.length - i;
      buffer.write(normalized[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}
