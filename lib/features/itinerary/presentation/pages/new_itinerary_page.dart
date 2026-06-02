part of travel_agent_app;

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({
    required this.onBack,
    required this.onGenerate,
    required this.profileLanguage,
    super.key,
  });
  final VoidCallback onBack;
  final ValueChanged<Trip> onGenerate;
  final String profileLanguage;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
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
    if (hasText == _hasBudgetText) return;
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

  Future<void> _pickStartDate() async {
    final today = _today();
    final firstDate = DateTime(today.year, today.month, today.day);
    final initialDate = _startDate.isBefore(firstDate) ? firstDate : _startDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
    );
    if (date == null) return;
    setState(() {
      _startDate = date;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 4));
      }
      _formError = null;
    });
  }

  Future<void> _pickEndDate() async {
    final today = _today();
    final firstDate = _startDate.isBefore(today)
        ? DateTime(today.year, today.month, today.day)
        : _startDate;
    final initialDate = _endDate.isBefore(firstDate) ? firstDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
    );
    if (date == null) return;
    setState(() {
      _endDate = date;
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
    );
    if (range == null) return null;
    return '${_dateKey(range.start)} to ${_dateKey(range.end)}';
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

    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18),
        children: [
          TopBar(
            title: _mode == 1 ? 'AI Trip Builder' : 'Create Manually',
            onBack: () => setState(() => _mode = 0),
          ),
          const SizedBox(height: 18),
          if (_mode == 1) const AnimatedGlobe(),
          if (_mode == 1) ...[
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showImagePicker,
              child: SizedBox(
                height: 128,
                child: _selectedImage == null
                    ? GlassPanel(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: _accent,
                              size: 30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              appText(context, 'ADD PRIMARY PHOTO'),
                              style: const TextStyle(
                                color: _secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              filterQuality: PerformanceScope.maybeSettingsOf(
                                context,
                              ).filterQuality,
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: .18),
                            ),
                            const Center(
                              child: Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            GlassPanel(
              child: Row(
                children: [
                  const IconBadge(icon: Icons.edit_note_rounded, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, 'Manual starter trip'),
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appText(
                            context,
                            'No AI call. This starts with an empty schedule you can build yourself.',
                          ),
                          style: const TextStyle(
                            color: _secondary,
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
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _destination,
            onChanged: _schedulePlaceSearch,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: appText(context, 'Destination'),
              hintText: appText(context, 'Tokyo, Japan'),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded),
            ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startLocation,
                  onChanged: _scheduleOriginSearch,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Start from'),
                    hintText: appText(context, 'Current location or Hsinchu'),
                    prefixIcon: const Icon(Icons.trip_origin_rounded),
                    suffixIcon: _isOriginSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: appText(context, 'Use current location'),
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(54, 54),
                ),
                onPressed: _isOriginSearching ? null : _useCurrentStartLocation,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
          if (_selectedOriginPlace != null) ...[
            const SizedBox(height: 10),
            SelectedPlaceCard(place: _selectedOriginPlace!),
          ] else if (_originSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            PlaceSuggestionList(
              suggestions: _originSuggestions,
              onSelect: _selectOriginPlace,
            ),
          ] else if (_tripStartLocation?.isCurrentLocation == true) ...[
            const SizedBox(height: 10),
            GlassPanel(
              child: Row(
                children: [
                  const IconBadge(icon: Icons.my_location_rounded, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, 'Current location'),
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appText(
                            context,
                            'Used for Day 1 transport and the return-home leg.',
                          ),
                          style: const TextStyle(
                            color: _secondary,
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
            ),
          ],
          const SizedBox(height: 12),
          DateRangeCard(
            startDate: _startDate,
            endDate: _endDate,
            onPickRange: _pickDateRange,
            onPickStart: _pickStartDate,
            onPickEnd: _pickEndDate,
          ),
          const SizedBox(height: 12),
          ResponsiveSplit(
            children: [
              TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: const [_GroupedNumberInputFormatter()],
                decoration: InputDecoration(
                  labelText: appText(context, 'Total budget'),
                  hintText: _budgetHintText(context),
                  suffixText: _hasBudgetText ? _currency : null,
                ),
              ),
              FullTapDropdownField(
                label: 'Currency',
                value: _currency,
                options: _currencyOptions,
                onChanged: (value) => setState(() {
                  _currency = value;
                  _formError = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FullTapDropdownField(
            label: 'Who is coming',
            value: _group,
            options: _groupOptions,
            onChanged: (value) => setState(() => _group = value),
          ),
          const SizedBox(height: 12),
          ResponsiveSplit(
            children: [
              TextField(
                controller: _airline,
                decoration: InputDecoration(
                  labelText: appText(context, 'Airline optional'),
                  prefixIcon: const Icon(Icons.flight_takeoff_rounded),
                ),
              ),
              TextField(
                controller: _flightConfirmation,
                decoration: InputDecoration(
                  labelText: appText(context, 'Confirmation'),
                  prefixIcon: const Icon(Icons.confirmation_number_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _visiblePreferenceOptions.map((preference) {
              final selected = _preferences.contains(preference);
              return FilterChip(
                selected: selected,
                label: Text(appText(context, preference)),
                onSelected: (_) => _togglePreference(preference),
                selectedColor: _accent.withValues(alpha: .35),
                checkmarkColor: _primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customPreference,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Add custom tag'),
                    hintText: appText(
                      context,
                      'e.g. anime, halal food, wheelchair access',
                    ),
                  ),
                  onSubmitted: (_) => _addCustomPreference(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(54, 54),
                ),
                onPressed: _addCustomPreference,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_mode == 1) ...[
            const SizedBox(height: 22),
            PlanningIdeaStrip(
              goals: _planningGoals,
              selectedGoalIds: _planningGoalIds,
              onToggle: _togglePlanningGoal,
            ),
          ],
          if (_mode == 1 && _usedFallbackPlan) ...[
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
          const SizedBox(height: 24),
          if (_isGenerating)
            const GeneratingTripPanel()
          else
            PrimaryButton(
              label: _mode == 1 ? 'Generate with AI' : 'Create manually',
              icon: _mode == 1
                  ? Icons.auto_awesome_rounded
                  : Icons.edit_note_rounded,
              onPressed: _mode == 1 ? _generateTrip : _createManualTrip,
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
