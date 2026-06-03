part of travel_agent_app;

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({
    required this.onBack,
    required this.onGenerate,
    required this.profileLanguage,
    required this.savedTrips,
    super.key,
  });
  final VoidCallback onBack;
  final ValueChanged<Trip> onGenerate;
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

class _CreateTripScreenState extends State<CreateTripScreen> {
  static const _createTripChatTurnTimeout = Duration(seconds: 15);
  static const _tripGenerationTurnTimeout = Duration(seconds: 60);

  final _places = GeoapifyPlacesService();
  final _assistant = TravelAssistantService();
  final _deviceContextService = AppDeviceContextService();
  final _destination = TextEditingController();
  final _budget = TextEditingController();
  final _chatInput = TextEditingController();
  final _customPreference = TextEditingController();
  final _startLocation = TextEditingController();
  final _airline = TextEditingController();
  final _flightConfirmation = TextEditingController();
  Timer? _searchTimer;
  Timer? _originSearchTimer;
  PlaceSuggestion? _selectedPlace;
  PlaceSuggestion? _selectedOriginPlace;
  List<PlaceSuggestion> _placeSuggestions = const [];
  List<PlaceSuggestion> _originSuggestions = const [];
  final List<CreateTripChatMessage> _chatMessages = [];
  CreateTripDraft? _pendingDraft;
  var _group = 'Friends';
  var _currency = AppCurrency.fallbackCurrencyCode;
  var _mode = 0;
  String? _formError;
  var _isSearching = false;
  var _isOriginSearching = false;
  var _isGenerating = false;
  var _isThinking = false;
  var _usedFallbackPlan = false;
  var _pendingDraftConfirmed = false;
  var _appliedDeviceCurrency = false;
  var _hasBudgetText = false;
  String? _lastAiError;
  AppDeviceContext? _deviceContext;
  TripStartLocation? _tripStartLocation;
  int? _manualExpandedStep;
  final Set<int> _manualCompletedSteps = {};
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
    _searchTimer?.cancel();
    _originSearchTimer?.cancel();
    _budget.removeListener(_syncBudgetTextState);
    _destination.dispose();
    _budget.dispose();
    _chatInput.dispose();
    _customPreference.dispose();
    _startLocation.dispose();
    _airline.dispose();
    _flightConfirmation.dispose();
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
        _startLocation.text = _tripStartLocation!.label;
      }
      if (_startDate.difference(oldToday).inDays == 0 &&
          _endDate.difference(oldToday).inDays == 5) {
        _startDate = newToday;
        _endDate = newToday.add(const Duration(days: 5));
      }
    });
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
      _startLocation.text = place.name;
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
        final coordinateLabel = _coordinateLocationLabel(
          start.latitude!,
          start.longitude!,
        );
        _tripStartLocation = TripStartLocation(
          label: coordinateLabel,
          latitude: start.latitude,
          longitude: start.longitude,
          isCurrentLocation: true,
        );
        _startLocation.text = coordinateLabel;
      }
    });
    if (start == null) return;

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
      if (resolvedPlace == null) return;
      _selectedOriginPlace = resolvedPlace;
      _tripStartLocation = TripStartLocation(
        label: resolvedPlace.name,
        latitude: start.latitude,
        longitude: start.longitude,
        isCurrentLocation: true,
      );
      _startLocation.text = resolvedPlace.name;
    });
  }

  String _coordinateLocationLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
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
      return;
    }

    setState(() {
      _isThinking = true;
      _pendingDraftConfirmed = false;
      _chatMessages.add(CreateTripChatMessage(fromUser: true, text: text));
    });

    CreateTripAiResponse aiResponse;
    try {
      aiResponse = await _assistant
          .createTripReply(
            message: text,
            currentDraft: _pendingDraft ?? CreateTripDraft(currency: _currency),
            history: _chatMessages,
            profileLanguage: widget.profileLanguage,
          )
          .timeout(_createTripChatTurnTimeout);
      _lastAiError = null;
    } catch (error) {
      final fallbackDraft = _parseTripDraft(text, _pendingDraft);
      final missing = _missingDraftFields(fallbackDraft);
      final conversionMessage = _conversionMessage(text, fallbackDraft);
      _lastAiError = _friendlyAiError(error);
      aiResponse = CreateTripAiResponse(
        message: missing.isEmpty
            ? conversionMessage ??
                  'I prepared a draft plan. Review it first, then confirm it when you are ready.'
            : _questionForMissingField(missing.first),
        draft: fallbackDraft,
        widget: _fallbackWidgetForMissingField(
          missing.isEmpty ? null : missing.first,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _pendingDraft = aiResponse.draft;
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
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        datePickerTheme: theme.datePickerTheme.copyWith(
          rangePickerShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          rangeSelectionBackgroundColor: const Color(
            0xFFACCBE0,
          ).withValues(alpha: .32),
          rangeSelectionOverlayColor: WidgetStatePropertyAll(
            const Color(0xFF355872).withValues(alpha: .08),
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
    if (text.contains('not-found') ||
        text.contains('NOT_FOUND') ||
        text.contains('failed-precondition') ||
        text.contains('SERVICE_DISABLED') ||
        text.contains('generateTripPlan') ||
        text.contains('createTripReply')) {
      return 'AI is not connected yet. Set the Firebase Function secrets and deploy Functions, or run Flutter with an OPENAI_API_KEY dart define. I used the local draft parser for now.';
    }
    if (text.contains('unauthenticated') ||
        text.contains('permission-denied')) {
      return 'AI could not be reached because the backend rejected the request. I used the local draft parser for now.';
    }
    return 'AI is unavailable right now. I used the local draft parser for now.';
  }

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

    final currency = _currencyFromText(text) ?? draft.currency ?? _currency;
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
      r'\$\s?(\d{2,7})|(?:budget|under|around|about|usd|dollars?)\D{0,12}(\d{2,7})|(\d{2,7})\s?(?:usd|dollars?)',
      caseSensitive: false,
    ).firstMatch(text);
    budget =
        budgetMatch?.group(1) ??
        budgetMatch?.group(2) ??
        budgetMatch?.group(3) ??
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
    if (durationMatch != null && (startDate == null || endDate == null)) {
      final duration = math.max(1, int.parse(durationMatch.group(1)!));
      final today = _today();
      startDate = lower.contains('tomorrow')
          ? today.add(const Duration(days: 1))
          : today;
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
      r'(?:\b(idr|rp|rupiah|twd|ntd|nt\$|nt|usd|dollars?|jpy|yen|eur|euros?)\b\s*([0-9][0-9,._]*))|(?:([0-9][0-9,._]*)\s*\b(idr|rp|rupiah|twd|ntd|nt\$|nt|usd|dollars?|jpy|yen|eur|euros?)\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final currency = _normalCurrencyCode(match.group(1) ?? match.group(4));
    final amountText = match.group(2) ?? match.group(3);
    final amount = int.tryParse(
      (amountText ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (currency == null || amount == null) return null;
    return (amount: amount, currency: currency);
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
        return 'Choose a date range, like 15/06/2026 to 20/06/2026, or say 5 days.';
      case 'total budget':
        return 'What total budget should I plan around in $_currency?';
      case 'who is coming':
        return 'Who is coming with you: Solo, Friends, Family, or Tour?';
      default:
        return 'Tell me one more detail for the trip.';
    }
  }

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
        final base = _today().add(const Duration(days: 21));
        final threeDayEnd = base.add(const Duration(days: 2));
        final fiveDayEnd = base.add(const Duration(days: 4));
        final sevenDayEnd = base.add(const Duration(days: 6));
        return CreateTripChoiceWidget(
          title: 'Trip length',
          options: [
            CreateTripChoiceOption(
              label: '3 days',
              value: '${_dateKey(base)} to ${_dateKey(threeDayEnd)}',
              description: 'Fast weekend plan',
            ),
            CreateTripChoiceOption(
              label: '5 days',
              value: '${_dateKey(base)} to ${_dateKey(fiveDayEnd)}',
              description: 'Balanced pace',
            ),
            CreateTripChoiceOption(
              label: '7 days',
              value: '${_dateKey(base)} to ${_dateKey(sevenDayEnd)}',
              description: 'More room for day trips',
            ),
            const CreateTripChoiceOption(
              label: 'Pick exact dates',
              value: _customDateRangeValue,
              description: 'Open the calendar',
            ),
          ],
        );
      case 'total budget':
        final options = _budgetOptionsForCurrency(_currency);
        return CreateTripChoiceWidget(
          title: 'Total budget',
          options: options
              .map(
                (option) => CreateTripChoiceOption(
                  label:
                      '${option.currency} ${_formatWholeNumber(option.amount)}',
                  value: 'budget ${option.amount} ${option.currency}',
                  description: option.description,
                ),
              )
              .toList(),
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

  List<({String currency, int amount, String description})>
  _budgetOptionsForCurrency(String currency) {
    switch (currency) {
      case 'IDR':
        return const [
          (currency: 'IDR', amount: 8000000, description: 'Lean and efficient'),
          (
            currency: 'IDR',
            amount: 16860000,
            description: 'Comfortable mid-range',
          ),
          (
            currency: 'IDR',
            amount: 25000000,
            description: 'More flexible picks',
          ),
        ];
      case 'TWD':
        return const [
          (currency: 'TWD', amount: 15000, description: 'Lean and efficient'),
          (
            currency: 'TWD',
            amount: 30000,
            description: 'Comfortable mid-range',
          ),
          (currency: 'TWD', amount: 50000, description: 'More flexible picks'),
        ];
      case 'JPY':
        return const [
          (currency: 'JPY', amount: 75000, description: 'Lean and efficient'),
          (
            currency: 'JPY',
            amount: 175000,
            description: 'Comfortable mid-range',
          ),
          (currency: 'JPY', amount: 250000, description: 'More flexible picks'),
        ];
      case 'EUR':
        return const [
          (currency: 'EUR', amount: 1400, description: 'Lean and efficient'),
          (currency: 'EUR', amount: 3200, description: 'Comfortable mid-range'),
          (currency: 'EUR', amount: 4600, description: 'More flexible picks'),
        ];
      default:
        return const [
          (currency: 'USD', amount: 1500, description: 'Lean and efficient'),
          (currency: 'USD', amount: 3500, description: 'Comfortable mid-range'),
          (currency: 'USD', amount: 5000, description: 'More flexible picks'),
        ];
    }
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
    final budget = draft.budget?.trim();
    if (budget != null && budget.isNotEmpty) _setBudgetText(budget);
    final currency = draft.currency;
    if (currency != null && _currencyOptions.contains(currency)) {
      _currency = currency;
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
      _mode = 1;
    });
    await _generateTrip();
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
    final startLocation = _startLocationForGeneration(generationContext);
    final plan = _manualStarterPlan(
      place: place,
      startLocation: startLocation,
      currency: _currency,
    );

    setState(() {
      _deviceContext = generationContext;
      _tripStartLocation = startLocation;
      _usedFallbackPlan = false;
      _formError = null;
    });
    _createTripFromPlan(
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
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text:
                'Draft updated. Review the custom version, then confirm it when it looks right.',
          ),
        );
      });
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

  int _parsedBudget() =>
      int.tryParse(_budget.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

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

  Future<void> _generateTrip() async {
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
      setState(() {
        _formError = _mode == 1
            ? 'Choose a real destination from the search results first.'
            : 'Enter a destination.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _usedFallbackPlan = false;
      _formError = null;
    });

    final generationContext = await _deviceContextService.load(
      requestLocation: true,
    );
    if (!mounted) return;
    final startLocation = _startLocationForGeneration(generationContext);
    setState(() {
      _deviceContext = generationContext;
      _tripStartLocation = startLocation;
    });

    GeneratedTripPlan plan;
    try {
      plan = await _assistant
          .generateTripPlan(
            place: place,
            startDate: _startDate,
            endDate: _endDate,
            budget: budget,
            groupType: _group,
            preferences: _aiGenerationPreferences,
            currency: _currency,
            airline: _airline.text.trim(),
            flightConfirmation: _flightConfirmation.text.trim(),
            profileLanguage: widget.profileLanguage,
            startLocation: startLocation,
          )
          .timeout(_tripGenerationTurnTimeout);
      if (plan.items.isEmpty) {
        throw Exception('AI returned no schedule items.');
      }
    } catch (_) {
      plan = _fallbackTripPlan(
        place: place,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        preferences: _aiGenerationPreferences,
        currency: _currency,
        startLocation: startLocation,
      );
      _usedFallbackPlan = true;
    }

    if (!mounted) return;
    setState(() => _isGenerating = false);
    _createTripFromPlan(
      place: place,
      budget: budget,
      plan: plan,
      startLocation: startLocation,
    );
  }

  void _createTripFromPlan({
    required PlaceSuggestion place,
    required int budget,
    required GeneratedTripPlan plan,
    required TripStartLocation? startLocation,
  }) {
    final bookings = _bookingsWithManualDetails(plan.bookings);
    widget.onGenerate(
      Trip(
        id: 't-${DateTime.now().millisecondsSinceEpoch}',
        destination: place.name,
        placeId: place.placeId,
        formattedAddress: place.formatted,
        latitude: place.latitude,
        longitude: place.longitude,
        originLabel: startLocation?.label,
        originLatitude: startLocation?.latitude,
        originLongitude: startLocation?.longitude,
        startDate: _dateKey(_startDate),
        endDate: _dateKey(_endDate),
        budget: budget,
        spent: 0,
        groupType: _group,
        currency: _currency,
        status: TripStatus.upcoming,
        images: [
          if (_selectedImage != null) _selectedImage!,
          ..._imagesForDestination(place.name),
        ],
        items: plan.items,
        bookings: bookings,
        checklist: plan.checklist,
        preferences: _savedTripPreferences,
        budgetCategories: _defaultBudgetCategories(
          budget: budget,
          actual: 0,
          items: plan.items,
          bookings: bookings,
        ),
      ),
    );
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
    );
  }

  List<Booking> _bookingsWithManualDetails(List<Booking> generated) {
    final airline = _airline.text.trim();
    final confirmation = _flightConfirmation.text.trim();
    if (airline.isEmpty && confirmation.isEmpty) return generated;
    final manualFlight = Booking(
      airline.isEmpty ? 'Flight booking' : airline,
      _dateKey(_startDate),
      'TBD',
      confirmation.isEmpty ? 'CONFIRMATION-TBD' : confirmation,
      0,
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
      budget: template.budget,
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
    required int startOffsetDays,
    required int days,
    required String budget,
    required String currency,
  }) {
    final start = _today().add(Duration(days: startOffsetDays));
    setState(() {
      _startDate = start;
      _endDate = start.add(Duration(days: math.max(1, days) - 1));
      _budget.text = budget;
      _currency = currency;
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

  void _applyAiBookingIdea({
    required String airline,
    required String confirmation,
  }) {
    setState(() {
      _airline.text = airline;
      _flightConfirmation.text = confirmation;
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
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;

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
                ),
                const SizedBox(height: 14),
                _AiPhotoPickerCard(
                  selectedImage: _selectedImage,
                  galleryOptions: _galleryOptions.take(3).toList(),
                  filterQuality: filterQuality,
                  onSelectImage: (image) => setState(() {
                    _selectedImage = image;
                    _formError = null;
                  }),
                  onTap: _showImagePicker,
                ),
                const SizedBox(height: 16),
                _AiSuggestionDeck(
                  goals: _planningGoals,
                  selectedGoalIds: _planningGoalIds,
                  onToggle: _togglePlanningGoal,
                ),
                const SizedBox(height: 16),
                _AiStepCard(
                  icon: Icons.route_rounded,
                  title: 'Route brief',
                  suggestion:
                      'AI will use the destination and starting point to cluster nearby stops and reduce backtracking.',
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
                              'Used for Day 1 transport and the return-home leg.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AiStepCard(
                  icon: Icons.auto_graph_rounded,
                  title: 'Timing and budget',
                  suggestion:
                      'AI will balance the daily pace against your budget, dates, and travel party.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiChoiceGrid(
                        choices: [
                          _AiChoice(
                            icon: Icons.flash_on_rounded,
                            title: 'Long weekend',
                            text: '4 days, compact route, USD 1800',
                            onTap: () => _applyAiTimingIdea(
                              startOffsetDays: 21,
                              days: 4,
                              budget: '1800',
                              currency: 'USD',
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.route_rounded,
                            title: 'Balanced week',
                            text: '6 days with buffer time, USD 3500',
                            onTap: () => _applyAiTimingIdea(
                              startOffsetDays: 30,
                              days: 6,
                              budget: '3500',
                              currency: 'USD',
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.savings_rounded,
                            title: 'Budget aware',
                            text: '5 days, low-cost picks, TWD 28000',
                            onTap: () => _applyAiTimingIdea(
                              startOffsetDays: 14,
                              days: 5,
                              budget: '28000',
                              currency: 'TWD',
                            ),
                          ),
                        ],
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
                const SizedBox(height: 16),
                _AiStepCard(
                  icon: Icons.psychology_rounded,
                  title: 'AI taste profile',
                  suggestion:
                      'AI will prioritize the selected tags when choosing neighborhoods, meals, and activity types.',
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
                const SizedBox(height: 16),
                _AiStepCard(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Booking clues',
                  suggestion:
                      'Optional booking details help AI anchor arrival and departure timing more accurately.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AiChoiceGrid(
                        choices: [
                          _AiChoice(
                            icon: Icons.flight_land_rounded,
                            title: 'No booking yet',
                            text: 'Let AI keep arrival and return flexible',
                            onTap: () => _applyAiBookingIdea(
                              airline: '',
                              confirmation: '',
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.flight_takeoff_rounded,
                            title: 'Flight booked',
                            text: 'Save space for airline and confirmation',
                            onTap: () => _applyAiBookingIdea(
                              airline: 'Flight booked',
                              confirmation: 'Add confirmation',
                            ),
                          ),
                          _AiChoice(
                            icon: Icons.schedule_rounded,
                            title: 'Timing matters',
                            text: 'AI should leave arrival-day buffer time',
                            onTap: () => _applyAiBookingIdea(
                              airline: 'Arrival timing important',
                              confirmation: '',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AiInputGrid(
                        children: [
                          _AiInputCard(
                            label: 'Airline optional',
                            icon: Icons.flight_takeoff_rounded,
                            controller: _airline,
                            hint: 'Flight booking',
                          ),
                          _AiInputCard(
                            label: 'Confirmation',
                            icon: Icons.confirmation_number_rounded,
                            controller: _flightConfirmation,
                            hint: 'Confirmation number',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_usedFallbackPlan) ...[
                  const SizedBox(height: 16),
                  FormNotice(
                    message: appText(
                      context,
                      'AI generation was unavailable, so a local draft plan was created.',
                    ),
                  ),
                ],
                if (_formError != null) ...[
                  const SizedBox(height: 16),
                  FormNotice(message: _formError!),
                ],
                const SizedBox(height: 22),
                if (_isGenerating)
                  const GeneratingTripPanel()
                else
                  _AiGenerateFooter(onGenerate: _generateTrip),
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
                                          'Used for Day 1 transport and the return-home leg.',
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
                                        label: 'Confirmation',
                                        icon: Icons.confirmation_number_rounded,
                                        child: _ManualTextField(
                                          controller: _flightConfirmation,
                                          hint: 'Confirmation number',
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
                onBack: () => setState(() => _mode = 0),
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
                    ),
                  if (_isThinking) const CreateTripThinkingBubble(),
                  if (pendingDraft != null && canUsePlan) ...[
                    const SizedBox(height: 12),
                    CreateTripDraftCard(
                      draft: pendingDraft,
                      confirmed: _pendingDraftConfirmed,
                      onConfirm: () => _sendCreateTripChat('confirm'),
                      onEdit: _editPendingDraft,
                      onUse: _pendingDraftConfirmed ? _usePendingDraft : null,
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
                    if (isChatFresh)
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            CreateTripPromptChip(
                              label: 'Kyoto',
                              prompt:
                                  'Trip to Kyoto with friends, 15/06/2026 to 20/06/2026, budget \$3500',
                              onTap: _sendCreateTripChat,
                            ),
                            CreateTripPromptChip(
                              label: 'Beach',
                              prompt:
                                  'Trip to Bali with family, 10/07/2026 to 16/07/2026, budget \$5000',
                              onTap: _sendCreateTripChat,
                            ),
                            CreateTripPromptChip(
                              label: 'Solo',
                              prompt:
                                  'Solo trip to Tokyo, 01/06/2026 to 05/06/2026, budget \$2500',
                              onTap: _sendCreateTripChat,
                            ),
                          ],
                        ),
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

class _AiChoiceGrid extends StatelessWidget {
  const _AiChoiceGrid({required this.choices});

  final List<_AiChoice> choices;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final tileWidth =
            (constraints.maxWidth - (10 * (columns - 1))) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final choice in choices)
              SizedBox(
                width: tileWidth,
                child: _AiChoiceCard(choice: choice),
              ),
          ],
        );
      },
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
        child: Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFACCBE0).withValues(alpha: .6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      choice.icon,
                      color: const Color(0xFF355872),
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF355872),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appText(context, choice.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF355872),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                appText(context, choice.text),
                maxLines: 2,
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

class _AiBuilderHero extends StatelessWidget {
  const _AiBuilderHero({
    required this.destination,
    required this.tripLength,
    required this.budgetLabel,
    required this.selectedSuggestionCount,
  });

  final String destination;
  final int tripLength;
  final String budgetLabel;
  final int selectedSuggestionCount;

  @override
  Widget build(BuildContext context) {
    final hasDestination = destination.isNotEmpty;
    final dayLabel = tripLength == 1
        ? appText(context, 'day')
        : appText(context, 'days');
    final suggestionLabel = selectedSuggestionCount == 1
        ? appText(context, 'AI focus')
        : appText(context, 'AI focuses');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .06),
            blurRadius: 28,
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
                        'Add a few signals and AI will build a starter itinerary.',
                      ),
                      maxLines: 2,
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
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AiHeroMetric(
                icon: Icons.place_rounded,
                label: 'Destination',
                value: hasDestination
                    ? destination
                    : appText(context, 'Waiting for destination'),
              ),
              _AiHeroMetric(
                icon: Icons.calendar_month_rounded,
                label: 'Duration',
                value: '$tripLength $dayLabel',
              ),
              _AiHeroMetric(
                icon: Icons.payments_rounded,
                label: 'Budget',
                value: budgetLabel.isEmpty
                    ? appText(context, 'Waiting for budget')
                    : budgetLabel,
              ),
              _AiHeroMetric(
                icon: Icons.psychology_alt_rounded,
                label: 'Suggestions',
                value: '$selectedSuggestionCount $suggestionLabel',
              ),
            ],
          ),
        ],
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
          color: const Color(0xFFF7F8F0),
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

class _AiPhotoPickerCard extends StatelessWidget {
  const _AiPhotoPickerCard({
    required this.selectedImage,
    required this.galleryOptions,
    required this.filterQuality,
    required this.onSelectImage,
    required this.onTap,
  });

  final String? selectedImage;
  final List<String> galleryOptions;
  final FilterQuality filterQuality;
  final ValueChanged<String> onSelectImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wallpaper_rounded,
                color: Color(0xFF355872),
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, 'AI cover suggestions'),
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 17),
                label: Text(appText(context, 'More')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final imageWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final image in galleryOptions)
                    SizedBox(
                      width: imageWidth,
                      height: 112,
                      child: _AiCoverSuggestionTile(
                        image: image,
                        selected: selectedImage == image,
                        filterQuality: filterQuality,
                        onTap: () => onSelectImage(image),
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

class _AiCoverSuggestionTile extends StatelessWidget {
  const _AiCoverSuggestionTile({
    required this.image,
    required this.selected,
    required this.filterQuality,
    required this.onTap,
  });

  final String image;
  final bool selected;
  final FilterQuality filterQuality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                filterQuality: filterQuality,
              ),
              Container(color: Colors.black.withValues(alpha: .2)),
              Positioned(
                left: 10,
                bottom: 10,
                right: 10,
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appText(
                          context,
                          selected ? 'Selected' : 'Use this mood',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
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
                  appText(context, 'AI suggestions'),
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
              'Tap the recommendation cards you want AI to emphasize.',
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF355872) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF355872)
                  : const Color(0xFFC2C7CC).withValues(alpha: .28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    goal.icon,
                    color: selected ? Colors.white : const Color(0xFF355872),
                    size: 20,
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: selected ? Colors.white : const Color(0xFF72787C),
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appText(context, goal.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF355872),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                appText(context, goal.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: .82)
                      : const Color(0xFF42474C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                appText(context, goal.tag),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: .72)
                      : const Color(0xFF72787C),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiStepCard extends StatelessWidget {
  const _AiStepCard({
    required this.icon,
    required this.title,
    required this.suggestion,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String suggestion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E7FC).withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF355872), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appText(context, title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF355872),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF355872),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    appText(context, suggestion),
                    style: const TextStyle(
                      color: Color(0xFF42474C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AiGenerateFooter extends StatelessWidget {
  const _AiGenerateFooter({required this.onGenerate});

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
          appText(context, 'Generate with AI'),
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        border: Border.all(
          color: complete
              ? const Color(0xFF16A34A).withValues(alpha: .45)
              : const Color(0xFFC2C7CC).withValues(alpha: .24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF355872).withValues(alpha: .05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(expanded ? 18 : 999),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: expanded ? const Color(0xFFF7F8F0) : Colors.white,
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
                              : const Color(0xFFC8E7FC).withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : icon,
                          color: complete
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
        );

        return Container(
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
                    SizedBox(width: 250, height: 248, child: image),
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
  });

  final String destination;
  final String dateRange;
  final String duration;
  final String budget;
  final String preferenceText;
  final int completedSections;
  final int totalSections;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isComplete = completedSections == totalSections;

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
          const SizedBox(height: 14),
          _ManualPreviewInfoRow(
            icon: Icons.place_rounded,
            label: 'Destination',
            value: destination,
          ),
          _ManualPreviewInfoRow(
            icon: Icons.event_rounded,
            label: 'Dates',
            value: dateRange,
            helper: duration,
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
