part of travel_agent_app;

class TravelAgentApp extends StatefulWidget {
  const TravelAgentApp({required this.account, super.key});

  final AuthenticatedAccount account;

  @override
  State<TravelAgentApp> createState() => _TravelAgentAppState();
}

class _TravelAgentAppState extends State<TravelAgentApp>
    with WidgetsBindingObserver {
  final _repository = TravelDataRepository(FirebaseFirestore.instance);
  final _authService = AccountAuthService();
  final _appNotificationService = AppNotificationService();
  late final _notificationService = TripNotificationService(
    notifications: _appNotificationService.notifications,
    initializeNotifications: _appNotificationService.ensureLocalInitialized,
  );
  final _automationService = const TripAutomationService();
  final _deviceContextService = AppDeviceContextService();
  final _placesService = GeoapifyPlacesService();
  final _currencyExchangeService = CurrencyExchangeService();
  final _profilePhotoService = ProfilePhotoService();
  final _chatListKey = GlobalKey<_ChatListScreenState>();
  late final _pushTokenService = PushTokenService(FirebaseFirestore.instance);
  static const _localProfilePrefix = 'travel_agent.profile.';
  static const _lastCurrencyCountryPrefix =
      'travel_agent.currency.last_country.';
  static const _tripDeleteUndoWindow = Duration(seconds: 5);
  final _routerRefresh = _TravelRouteRefresh();
  late final GoRouter _router;
  StreamSubscription<UserProfile?>? _userSubscription;
  StreamSubscription<List<Trip>>? _tripsSubscription;
  StreamSubscription<List<TripMemory>>? _memoriesSubscription;
  var _isLoading = true;
  var _loadingMessage = 'Checking account updates...';
  var _exchangeData = CurrencyExchangeData.fallback;
  var _currencyLocationCheckInFlight = false;
  var _isChatRoomOpen = false;
  var _isAppForeground = true;
  var _screen = _Screen.dashboard;
  var _tab = _NavTab.home;
  var _tripDetailInitialTab = 0;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  final List<TripMemory> _tripMemories = [];
  final Map<String, Timer> _pendingTripDeleteTimers = {};
  final Set<String> _pendingTripDeleteIds = {};
  final Set<String> _archivedNotificationIds = {};
  final Set<String> _automationInFlight = {};
  final Set<String> _automationCheckedKeys = {};
  ChatListAppBarActions? _chatListAppBarActions;
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String? _pendingTripAiPrompt;
  String? _suggestedDestination;
  String? _accountId;
  String? _activeChatId;
  String? _pendingNotificationPath;
  String? _loadError;
  var _helpOpen = false;
  var _tutorialDismissedForSession = false;

  int get _cachedTabIndex => switch (_tab) {
    _NavTab.home => 0,
    _NavTab.trips || _NavTab.add => 1,
    _NavTab.chat => 2,
    _NavTab.profile => 3,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = AppRouter._createTravelAgentRouter(
      appState: this,
      refreshListenable: _routerRefresh,
    );
    unawaited(
      _appNotificationService.initialize(
        notificationsEnabled: () => _user.notificationsEnabled,
        activeChatId: () => _activeChatId,
        onOpen: _openNotificationTarget,
      ),
    );
    unawaited(
      _pushTokenService.updatePresence(
        isForeground: true,
        activeChatId: _activeChatId,
      ),
    );
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final accountId = widget.account.uid;

    var loadError = <String>[];
    _updateLoadingMessage('Checking account updates...');
    final localProfile = await _loadLocalProfile(accountId);
    UserProfile? remoteProfile;
    try {
      remoteProfile = await _repository.loadUser(accountId);
    } catch (error) {
      loadError.add('Could not sync profile data: $error');
    }

    final loadedProfile = remoteProfile ?? localProfile;
    var user =
        loadedProfile ??
        UserProfile(
          name: widget.account.name,
          email: widget.account.email ?? '',
          photoUrl: widget.account.photoUrl,
          interests: const [],
          language: 'en',
          notificationsEnabled: true,
          themeMode: 'Light',
        );
    if (user.currencySettingsVersion < 1) {
      _updateLoadingMessage('Updating currency settings...');
      user = user.copyWith(
        displayCurrencyCode: AppCurrency.fallbackCurrencyCode,
        currencyUpdateMode: CurrencyUpdateMode.automatic,
        currencySettingsVersion: 1,
      );
      try {
        await _repository.saveUser(accountId, user);
      } catch (error) {
        loadError.add('Could not update currency settings: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _accountId = accountId;
      _user = user;
      _loadError = loadError.isEmpty ? null : loadError.join('\n');
    });
    AppLocaleController.setProfileLanguage(user.language);
    await PerformanceScope.of(context).update(user.performanceSettings);
    _updateLoadingMessage('Refreshing daily exchange rates...');
    final exchangeData = await _currencyExchangeService.loadDailyRates();
    if (!mounted) return;
    setState(() => _exchangeData = exchangeData);
    unawaited(_syncPushTokenRegistration());
    await _saveLocalProfile(accountId, user);

    _updateLoadingMessage('Checking saved plans...');
    await _archiveExpiredTripsQuietly(accountId);

    try {
      _updateLoadingMessage('Loading your trips...');
      final trips = await _repository.loadTrips(accountId);
      final memories = await _repository.loadTripMemories(accountId);
      if (!mounted) return;
      final visibleTrips = _withoutPendingDeletes(trips);
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _tripMemories
          ..clear()
          ..addAll(memories);
        _activeTrip = _firstOngoingTrip(visibleTrips);
        _loadError = loadError.isEmpty ? null : loadError.join('\n');
      });
      _queueTripAutomation(visibleTrips);
      unawaited(_syncTripReminders());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load online trip data: $error');
    }

    _updateLoadingMessage('Preparing chats and notifications...');
    _watchAccountData(accountId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    final pendingNotificationPath = _pendingNotificationPath;
    _pendingNotificationPath = null;
    if (pendingNotificationPath != null) {
      await _openNotificationTarget(pendingNotificationPath);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForCurrencyLocationChange());
    });
  }

  void _updateLoadingMessage(String message) {
    if (!mounted || _loadingMessage == message) return;
    setState(() => _loadingMessage = message);
  }

  void _watchAccountData(String accountId, {bool watchTrips = true}) {
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();
    _memoriesSubscription?.cancel();

    _userSubscription = _repository
        .watchUser(accountId)
        .listen(
          (profile) {
            if (!mounted || profile == null) return;
            final normalizedRemote = profile.currencySettingsVersion < 1
                ? profile.copyWith(
                    displayCurrencyCode: AppCurrency.fallbackCurrencyCode,
                    currencyUpdateMode: CurrencyUpdateMode.automatic,
                    currencySettingsVersion: 1,
                  )
                : profile;
            setState(() {
              _user = normalizedRemote;
              _loadError = null;
            });
            unawaited(_syncTripReminders());
            unawaited(_syncPushTokenRegistration());
            unawaited(
              PerformanceScope.of(
                context,
              ).update(normalizedRemote.performanceSettings),
            );
            unawaited(_saveLocalProfile(accountId, normalizedRemote));
            if (profile.currencySettingsVersion < 1) {
              unawaited(_repository.saveUser(accountId, normalizedRemote));
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync profile data: $error');
            _notifyRoutes();
          },
        );

    if (watchTrips) _watchTrips(accountId);
  }

  void _watchTrips(String accountId) {
    _tripsSubscription?.cancel();
    _tripsSubscription = _repository
        .watchTrips(accountId)
        .listen(
          (trips) {
            if (!mounted) return;
            final visibleTrips = _withoutPendingDeletes(trips);
            setState(() {
              _trips
                ..clear()
                ..addAll(trips);
              _activeTrip = _firstOngoingTrip(visibleTrips);
              _selectedTrip = _matchingTrip(visibleTrips, _selectedTrip);
              if (_screen == _Screen.tripDetail && _selectedTrip == null) {
                _screen = _Screen.dashboard;
                _tab = _NavTab.home;
              }
              _loadError = null;
            });
            _queueTripAutomation(visibleTrips);
            unawaited(_syncTripReminders());
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync trip data: $error');
            _notifyRoutes();
          },
        );

    _memoriesSubscription = _repository
        .watchTripMemories(accountId)
        .listen(
          (memories) {
            if (!mounted) return;
            setState(() {
              _tripMemories
                ..clear()
                ..addAll(memories);
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              return;
            }
            setState(() => _loadError = 'Could not sync trip memories: $error');
          },
        );
  }

  void _openTrip(Trip trip) {
    if (_pendingTripDeleteIds.contains(trip.id)) return;
    setState(() {
      _selectedTrip = trip;
      _screen = _Screen.tripDetail;
      _tab = _NavTab.trips;
      _tripDetailInitialTab = 0;
      _pendingTripAiPrompt = null;
    });
  }

  void _openTripAssistant(String prompt) {
    final visibleTrips = _visibleTrips;
    final trip =
        _visibleActiveTrip ??
        _selectedTrip ??
        (visibleTrips.isEmpty ? null : visibleTrips.first);
    if (trip == null) {
      setState(() {
        _screen = _Screen.chatList;
        _tab = _NavTab.chat;
      });
      return;
    }
    setState(() {
      _selectedTrip = trip;
      _screen = _Screen.tripDetail;
      _tab = _NavTab.trips;
      _tripDetailInitialTab = 7;
      _pendingTripAiPrompt = prompt;
    });
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final previous = _user;
    final displayCurrencyChanged =
        profile.displayCurrencyCode != _user.displayCurrencyCode;
    final normalized = profile.copyWith(currencySettingsVersion: 1);
    final languageChanged = normalized.language != previous.language;
    setState(() {
      _user = normalized;
      _loadError = null;
    });
    unawaited(_syncTripReminders());
    unawaited(_syncPushTokenRegistration());
    if (!languageChanged) {
      AppLocaleController.setProfileLanguage(normalized.language);
    }

    final accountId = _accountId ?? widget.account.uid;
    await _saveLocalProfile(accountId, normalized);
    try {
      await _repository.saveUser(
        accountId,
        normalized.copyWith(
          onboardingRequired: false,
          onboardingCompleted: true,
        ),
      );
      await _repository.completeOnboarding(accountId);
      if (displayCurrencyChanged) {
        unawaited(_rememberCurrentCurrencyCountry());
      } else if (normalized.currencyUpdateMode ==
          CurrencyUpdateMode.automatic) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_checkForCurrencyLocationChange());
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _user = previous;
        _loadError = 'Could not save profile online: $error';
      });
      if (!languageChanged) {
        AppLocaleController.setProfileLanguage(previous.language);
      }
      await _saveLocalProfile(accountId, previous);
      rethrow;
    }
  }

  Future<void> _savePerformanceSettings(AppPerformanceSettings settings) async {
    final profile = _user.copyWith(performanceSettings: settings);
    setState(() {
      _user = profile;
      _loadError = null;
    });

    final accountId = _accountId ?? widget.account.uid;
    await _saveLocalProfile(accountId, profile);
    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = 'Could not save performance settings online: $error',
      );
      rethrow;
    }
  }

  Future<void> _toggleFavoritePlace(Destination destination) async {
    final id = _favoritePlaceId(destination.name);
    final places = [..._user.favoritePlaces];
    final existing = places.indexWhere((place) => place.id == id);
    if (existing == -1) {
      places.add(FavoritePlace.fromDestination(destination));
    } else {
      places.removeAt(existing);
    }
    await _saveProfile(_user.copyWith(favoritePlaces: places));
  }

  Future<void> _toggleFavoriteTrip(Trip trip) async {
    final ids = {..._user.favoriteTripIds};
    if (!ids.add(trip.id)) ids.remove(trip.id);
    await _saveProfile(_user.copyWith(favoriteTripIds: ids.toList()..sort()));
  }

  Future<void> _rateTripMemory(
    TripMemory memory,
    int rating,
    String feedback,
  ) async {
    final accountId = _accountId ?? widget.account.uid;
    await _repository.saveTripMemoryFeedback(
      accountId,
      tripId: memory.id,
      rating: rating,
      feedback: feedback,
    );
    if (!mounted) return;
    setState(() {
      final index = _tripMemories.indexWhere((item) => item.id == memory.id);
      if (index != -1) {
        _tripMemories[index] = memory.copyWith(
          rating: rating,
          feedback: feedback.trim(),
        );
      }
    });
  }

  Future<void> _closeTutorial() async {
    final shouldPersist = !_user.tutorialCompleted;
    setState(() {
      _helpOpen = false;
      _tutorialDismissedForSession = true;
    });
    if (shouldPersist) {
      await _saveProfile(_user.copyWith(tutorialCompleted: true));
    }
  }

  void _createTripFromDestination(Destination destination) {
    _suggestedDestination = destination.name;
    _router.go('/trips/new');
  }

  Future<UserProfile?> _loadLocalProfile(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_localProfilePrefix$accountId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromMap(decoded);
    } catch (_) {
      await prefs.remove('$_localProfilePrefix$accountId');
      return null;
    }
  }

  Future<void> _saveLocalProfile(String accountId, UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_localProfilePrefix$accountId',
      jsonEncode(profile.toLocalMap()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    unawaited(
      _pushTokenService.updatePresence(
        isForeground: _isAppForeground,
        activeChatId: _activeChatId,
      ),
    );
    if (_isAppForeground) {
      unawaited(_checkForCurrencyLocationChange());
    }
  }

  Future<void> _checkForCurrencyLocationChange() async {
    if (_isLoading ||
        _currencyLocationCheckInFlight ||
        _user.currencyUpdateMode != CurrencyUpdateMode.automatic) {
      return;
    }

    _currencyLocationCheckInFlight = true;
    try {
      if (!await _deviceContextService.isLocationAccessEnabled()) return;
      final deviceContext = await _deviceContextService.load(
        requestLocation: false,
      );
      if (!deviceContext.hasLocation) return;

      final place = await _placesService.reverseLocation(
        latitude: deviceContext.latitude!,
        longitude: deviceContext.longitude!,
      );
      final countryCode = place?.countryCode?.trim().toUpperCase();
      if (countryCode == null || countryCode.length != 2) return;

      final accountId = _accountId ?? widget.account.uid;
      final prefs = await SharedPreferences.getInstance();
      final countryKey = '$_lastCurrencyCountryPrefix$accountId';
      if (prefs.getString(countryKey) == countryCode) return;

      final suggestedCurrency = _currencyForCountryCode(countryCode);
      if (suggestedCurrency == null ||
          !_exchangeData.rates.containsKey(suggestedCurrency)) {
        await prefs.setString(countryKey, countryCode);
        return;
      }

      final currentCurrency = _user.displayCurrencyCode.toUpperCase();
      if (suggestedCurrency == currentCurrency) {
        await prefs.setString(countryKey, countryCode);
        return;
      }
      if (!mounted || !context.mounted) return;

      final countryName = place?.country?.trim();
      final changeCurrency = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change display currency?'),
          content: Text(
            'You appear to be in '
            '${countryName == null || countryName.isEmpty ? countryCode : countryName}. '
            'Would you like to change your display currency from '
            '$currentCurrency to $suggestedCurrency?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Keep $currentCurrency'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Change to $suggestedCurrency'),
            ),
          ],
        ),
      );
      await prefs.setString(countryKey, countryCode);
      if (changeCurrency == true && mounted) {
        await _saveProfile(
          _user.copyWith(displayCurrencyCode: suggestedCurrency),
        );
      }
    } catch (_) {
      // Location-based currency suggestions are best effort.
    } finally {
      _currencyLocationCheckInFlight = false;
    }
  }

  Future<void> _rememberCurrentCurrencyCountry() async {
    try {
      if (!await _deviceContextService.isLocationAccessEnabled()) return;
      final deviceContext = await _deviceContextService.load(
        requestLocation: false,
      );
      if (!deviceContext.hasLocation) return;
      final place = await _placesService.reverseLocation(
        latitude: deviceContext.latitude!,
        longitude: deviceContext.longitude!,
      );
      final countryCode = place?.countryCode?.trim().toUpperCase();
      if (countryCode == null || countryCode.length != 2) return;
      final prefs = await SharedPreferences.getInstance();
      final accountId = _accountId ?? widget.account.uid;
      await prefs.setString(
        '$_lastCurrencyCountryPrefix$accountId',
        countryCode,
      );
    } catch (_) {
      // Manual currency selection still succeeds if location is unavailable.
    }
  }

  Future<void> _createTrip(Trip trip) async {
    // Use the shell's own router: this State sits above Router.withConfig, so
    // GoRouter.of(context) here throws "No GoRouter found in context".
    final saved = await _saveTripOnline(trip);
    if (!saved || !mounted) return;
    setState(() => _selectedTrip = trip);
    await _refreshTripsFromBackend(selectTripId: trip.id);
    if (!mounted) return;
    _router.go(_tripLocation(trip.id));
  }

  Future<void> _startTrip(Trip trip) async {
    if (!trip.canEdit || trip.status == TripStatus.ongoing) return;

    final previousActive = _activeTrip ?? _firstOngoingTrip(_trips);
    if (previousActive != null && previousActive.id != trip.id) {
      final confirmed = await _confirmReplaceActiveTrip(
        currentTrip: previousActive,
        nextTrip: trip,
      );
      if (!confirmed || !mounted) return;
    }

    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.startTrip(
        accountId,
        trip: trip,
        previousActive: previousActive,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not start trip: $error');
      return;
    }
    if (!mounted) return;
    await _refreshTripsFromBackend(selectTripId: trip.id);
    if (!mounted) return;
    setState(() {
      _screen = _Screen.dashboard;
      _tab = _NavTab.home;
    });
    unawaited(_syncTripReminders());
  }

  void _deleteTrip(Trip trip) {
    if (!trip.isOwner || _pendingTripDeleteIds.contains(trip.id)) return;
    setState(() {
      _pendingTripDeleteIds.add(trip.id);
      if (_selectedTrip?.id == trip.id) {
        _selectedTrip = null;
        if (_screen == _Screen.tripDetail) {
          _screen = _Screen.trips;
        }
      }
      if (_activeTrip?.id == trip.id) {
        _activeTrip = _firstOngoingTrip(_visibleTrips);
      }
      _loadError = null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: _tripDeleteUndoWindow,
          content: Text(
            appText(
              context,
              '${trip.destination} will be deleted in 5 seconds.',
            ),
          ),
          action: SnackBarAction(
            label: appText(context, 'Undo'),
            onPressed: () => _undoTripDelete(trip.id),
          ),
        ),
      );

    _pendingTripDeleteTimers[trip.id]?.cancel();
    _pendingTripDeleteTimers[trip.id] = Timer(
      _tripDeleteUndoWindow,
      () => unawaited(_finishPendingTripDelete(trip)),
    );
  }

  void _undoTripDelete(String tripId) {
    final timer = _pendingTripDeleteTimers.remove(tripId);
    timer?.cancel();
    if (!_pendingTripDeleteIds.remove(tripId) || !mounted) return;
    setState(() => _activeTrip = _firstOngoingTrip(_visibleTrips));
  }

  Future<void> _finishPendingTripDelete(Trip trip) async {
    _pendingTripDeleteTimers.remove(trip.id);
    if (!_pendingTripDeleteIds.contains(trip.id)) return;

    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.deleteTrip(accountId, trip.id);
      if (!mounted) return;
      setState(() {
        _pendingTripDeleteIds.remove(trip.id);
        _trips.removeWhere((item) => item.id == trip.id);
        if (_selectedTrip?.id == trip.id) _selectedTrip = null;
        if (_activeTrip?.id == trip.id) {
          _activeTrip = _firstOngoingTrip(_visibleTrips);
        }
        _loadError = null;
      });
      await _refreshTripsFromBackend();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingTripDeleteIds.remove(trip.id);
        _activeTrip = _firstOngoingTrip(_visibleTrips);
        _loadError = 'Could not remove trip: $error';
      });
    }
  }

  Future<void> _updateTrip(Trip trip) async {
    if (!trip.canEdit) return;
    final saved = await _saveTripOnline(trip);
    if (!saved || !mounted) return;
    await _refreshTripsFromBackend();
  }

  Future<bool> _saveTripOnline(Trip trip) async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.saveTrip(accountId, trip);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _loadError = 'Could not save trip online: $error');
      _notifyRoutes();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              appText(context, 'Could not save trip: $error'),
            ),
          ),
        );
      return false;
    }
  }

  Future<bool> _confirmReplaceActiveTrip({
    required Trip currentTrip,
    required Trip nextTrip,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Start a different trip?')),
        content: Text(
          appText(
            context,
            'Starting ${nextTrip.destination} will stop ${currentTrip.destination} and reset it back to upcoming.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Start trip')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _refreshTripsFromBackend({String? selectTripId}) async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      await _archiveExpiredTripsQuietly(accountId);
      final trips = await _repository.loadTrips(accountId);
      final memories = await _repository.loadTripMemories(accountId);
      if (!mounted) return;
      final visibleTrips = _withoutPendingDeletes(trips);
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _tripMemories
          ..clear()
          ..addAll(memories);
        _activeTrip = _firstOngoingTrip(visibleTrips);
        _selectedTrip =
            _tripById(visibleTrips, selectTripId) ??
            _matchingTrip(visibleTrips, _selectedTrip);
        _loadError = null;
      });
      _queueTripAutomation(visibleTrips);
      unawaited(_syncTripReminders());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not refresh trip data: $error');
      _notifyRoutes();
    }
  }

  Future<void> _archiveExpiredTripsQuietly(String accountId) async {
    try {
      await _repository.archiveExpiredTrips(accountId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return;
      rethrow;
    }
  }

  Future<void> _deleteAccount() async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      _authService.ensureCanDeleteCurrentAccount();
      await _profilePhotoService.deleteForUser(accountId);
      await _repository.deleteUserData(accountId);
      await _authService.deleteCurrentAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not delete account: $error');
      _notifyRoutes();
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();
    _memoriesSubscription?.cancel();
    unawaited(_pushTokenService.dispose());
    unawaited(_appNotificationService.dispose());
    for (final timer in _pendingTripDeleteTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CurrencyScope(
      displayCurrencyCode: _user.displayCurrencyCode,
      exchangeData: _exchangeData,
      child: Theme(
        data: _user.themeMode == 'Dark'
            ? TravelAgentTheme.dark()
            : TravelAgentTheme.light(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: false,
            child: _isLoading
                ? LoadingScreen(message: _loadingMessage)
                : Stack(
                    children: [
                      Router.withConfig(config: _router),
                      if (_loadError != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 12,
                          child: SyncBanner(message: _loadError!),
                        ),
                      Positioned(
                        right: 14,
                        bottom: 94,
                        child: FloatingActionButton.small(
                          heroTag: 'global-help',
                          tooltip: 'App help',
                          onPressed: () => setState(() => _helpOpen = true),
                          child: const Icon(Icons.help_outline_rounded),
                        ),
                      ),
                      if (_helpOpen ||
                          (_user.onboardingCompleted &&
                              !_user.tutorialCompleted &&
                              !_tutorialDismissedForSession))
                        Positioned.fill(
                          child: _AppTutorialOverlay(
                            onClose: () => unawaited(_closeTutorial()),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _performanceBoundary(
    Widget child,
    AppPerformanceSettings performance,
  ) {
    if (!performance.isolateRepaints) return child;
    return RepaintBoundary(child: child);
  }

  Widget _buildDashboardScreen(BuildContext context) {
    return DashboardScreen(
      user: _user,
      trips: _visibleTrips,
      activeTrip: _visibleActiveTrip,
      memories: _tripMemories,
      onCreate: () => context.go('/trips/new'),
      onOpenTrip: (trip) => context.go(_tripLocation(trip.id)),
      onStartTrip: _startTrip,
      onAskAi: (prompt) {
        _openTripAssistant(prompt);
        final trip = _selectedTrip;
        if (trip != null) context.go(_tripLocation(trip.id));
      },
      onOpenInfo: () => context.go('/tools/info'),
      onOpenTranslate: () => context.go('/tools/translate'),
      onOpenMap: () => context.go('/tools/map'),
      onOpenNotifications: _openNotificationCenter,
      onToggleFavoritePlace: _toggleFavoritePlace,
      onAddPlaceToTrip: _createTripFromDestination,
    );
  }

  Widget _buildNotificationsScreen(BuildContext context) {
    return NotificationsScreen(
      archivedNotificationIds: _archivedNotificationIds,
      onArchive: (id) => setState(() => _archivedNotificationIds.add(id)),
      onRestore: (id) => setState(() => _archivedNotificationIds.remove(id)),
      onBack: () => context.go('/'),
    );
  }

  Widget _buildInfoScreen(BuildContext context) {
    return InfoScreen(onBack: () => context.go('/'));
  }

  Widget _buildTranslateScreen(BuildContext context) {
    return TranslateScreen(onBack: () => context.go('/'));
  }

  Widget _buildGlobalMapScreen(BuildContext context) {
    return MapScreen(
      trip: _visibleActiveTrip ?? _selectedTrip ?? mockKyotoTrip,
      onBack: () => context.go('/'),
    );
  }

  Widget _buildTripsScreen(BuildContext context) {
    return TripsScreen(
      trips: _visibleTrips,
      memories: _tripMemories,
      onCreate: () => context.go('/trips/new'),
      onOpenTrip: (trip) => context.go(_tripLocation(trip.id)),
      onStartTrip: _startTrip,
      onDeleteTrip: _deleteTrip,
      favoriteTripIds: _user.favoriteTripIds,
      onToggleFavoriteTrip: (trip) {
        unawaited(_toggleFavoriteTrip(trip));
      },
      onRateMemory: _rateTripMemory,
    );
  }

  Widget _buildCreateTripScreen(BuildContext context) {
    return CreateTripScreen(
      profileLanguage: _user.language,
      savedTrips: _trips,
      initialDestination: _suggestedDestination,
      onBack: () {
        _suggestedDestination = null;
        context.go('/trips');
      },
      onGenerate: (trip) {
        _suggestedDestination = null;
        return _createTrip(trip);
      },
    );
  }

  Widget _buildTripDetailScreen(BuildContext context, String tripId) {
    final trip = _tripById(_visibleTrips, tripId) ?? _selectedTrip;
    if (trip == null) {
      return _NoTripSelectedScreen(
        title: 'Trip',
        onBack: () => context.go('/trips'),
        onCreate: () => context.go('/trips/new'),
      );
    }
    return TripDetailScreen(
      key: ValueKey('trip-detail-${trip.id}'),
      trip: trip,
      onBack: () => context.go('/trips'),
      onOpenChat: () => context.go('/chat'),
      onOpenBudget: () => context.go('/trips/${trip.id}/budget'),
      onOpenPacking: () => context.go('/trips/${trip.id}/packing'),
      onUpdateTrip: _updateTrip,
      accountId: _accountId ?? widget.account.uid,
      repository: _repository,
      onLeftTrip: () => context.go('/trips'),
      initialTabIndex: _tripDetailInitialTab,
      initialAiPrompt: _pendingTripAiPrompt,
    );
  }

  Widget _buildTripMapScreen(BuildContext context, String tripId) {
    final trip = _tripById(_visibleTrips, tripId) ?? _selectedTrip;
    if (trip == null) {
      return _NoTripSelectedScreen(
        title: 'Map',
        onBack: () => context.go('/trips'),
        onCreate: () => context.go('/trips/new'),
      );
    }
    return MapScreen(
      trip: trip,
      onBack: () => context.go(_tripLocation(trip.id)),
    );
  }

  Widget _buildBudgetScreen(BuildContext context, String tripId) {
    final trip = _tripById(_visibleTrips, tripId) ?? _selectedTrip;
    if (trip == null) {
      return _NoTripSelectedScreen(
        title: 'Budget',
        onBack: () => context.go('/trips'),
        onCreate: () => context.go('/trips/new'),
      );
    }
    return BudgetScreen(
      trip: trip,
      onBack: () => context.go(_tripLocation(trip.id)),
    );
  }

  Widget _buildPackingScreen(BuildContext context, String tripId) {
    final trip = _tripById(_visibleTrips, tripId) ?? _selectedTrip;
    if (trip == null) {
      return _NoTripSelectedScreen(
        title: 'Packing',
        onBack: () => context.go('/trips'),
        onCreate: () => context.go('/trips/new'),
      );
    }
    return PackingScreen(
      trip: trip,
      onBack: () => context.go(_tripLocation(trip.id)),
    );
  }

  Widget _buildChatListScreen(BuildContext context) {
    return ChatListScreen(
      key: _chatListKey,
      account: widget.account,
      user: _user,
      onRoomOpenChanged: _setChatRoomOpen,
      onOpenChat: (chatId) => context.go('/chat/$chatId'),
      onAppBarActionsChanged: _setChatListAppBarActions,
    );
  }

  Widget _buildGroupChatRoomScreen(BuildContext context, String chatId) {
    return RoutedGroupChatRoomScreen(
      chatId: chatId,
      account: widget.account,
      user: _user,
      onBack: () => context.go('/chat'),
      onOpenTrip: (tripId) => context.go(_tripLocation(tripId)),
      onVisibilityChanged: _setActiveChatId,
    );
  }

  Widget _buildProfileScreen(BuildContext context) {
    return ProfileScreen(
      account: widget.account,
      user: _user,
      trips: _visibleTrips,
      memories: _tripMemories,
      onOpenTrip: (trip) => context.go(_tripLocation(trip.id)),
      onToggleFavoriteTrip: (trip) {
        unawaited(_toggleFavoriteTrip(trip));
      },
    );
  }

  void _setChatListAppBarActions(ChatListAppBarActions? actions) {
    if (!mounted) return;
    if (_chatListAppBarActions == actions) return;
    setState(() => _chatListAppBarActions = actions);
  }

  void _reviewChatInviteFromHeader() {
    final action = _chatListAppBarActions?.onReviewInvite;
    if (action != null) {
      action();
      return;
    }
    final state = _chatListKey.currentState;
    if (state != null) unawaited(state._reviewInviteCode());
  }

  void _createChatFromHeader() {
    final action = _chatListAppBarActions?.onCreateChat;
    if (action != null) {
      action();
      return;
    }
    final state = _chatListKey.currentState;
    if (state != null) unawaited(state._showCreateChatSheet());
  }

  Widget _buildSettingsScreen(BuildContext context) {
    return SettingsScreen(
      account: widget.account,
      user: _user,
      authService: _authService,
      onSave: _saveProfile,
      onSignOut: _authService.signOut,
      onDeleteAccount: _deleteAccount,
      onBack: () => context.go('/profile'),
      onOpenLinkedAccounts: () =>
          context.go('/profile/settings/linked-accounts'),
      onOpenPerformance: () => context.go('/profile/performance'),
      archivedItemCount: _tripMemories.length + _archivedNotificationIds.length,
      onOpenArchived: () => context.go('/profile/archived'),
    );
  }

  Widget _buildLinkedAccountsScreen(BuildContext context) {
    return LinkedAccountsScreen(
      authService: _authService,
      onBack: () => context.go('/profile/settings'),
    );
  }

  Widget _buildArchivedItemsScreen(BuildContext context) {
    return ArchivedItemsScreen(
      tripMemories: _tripMemories,
      archivedNotificationIds: _archivedNotificationIds,
      onRestoreNotification: (id) =>
          setState(() => _archivedNotificationIds.remove(id)),
      onBack: () => context.go('/profile/settings'),
    );
  }

  Widget _buildPerformanceSettingsScreen(BuildContext context) {
    return PerformanceSettingsScreen(
      onBack: () => context.go('/profile/settings'),
      onSettingsChanged: _savePerformanceSettings,
    );
  }

  List<Trip> get _visibleTrips => _withoutPendingDeletes(_trips);

  Trip? get _visibleActiveTrip {
    final activeTrip = _activeTrip;
    if (activeTrip == null || _pendingTripDeleteIds.contains(activeTrip.id)) {
      return _firstOngoingTrip(_visibleTrips);
    }
    return activeTrip;
  }

  List<Trip> _withoutPendingDeletes(List<Trip> trips) {
    return trips
        .where((trip) => !_pendingTripDeleteIds.contains(trip.id))
        .toList(growable: false);
  }

  Trip? _matchingTrip(List<Trip> trips, Trip? current) {
    if (current == null) return null;
    return _tripById(trips, current.id);
  }

  String _tripLocation(String tripId) => '/trips/$tripId';

  Future<void> _openNotificationTarget(String targetPath) async {
    final path = targetPath.trim();
    if (!path.startsWith('/')) return;
    if (_isLoading) {
      _pendingNotificationPath = path;
      return;
    }
    _router.go(path);
  }

  void _notifyRoutes() => _routerRefresh.notify();

  // ignore: unused_element
  Widget _buildCachedTabStack(AppPerformanceSettings performance) {
    return KeyedSubtree(
      key: const ValueKey('cached-tabs'),
      child: IndexedStack(
        index: _cachedTabIndex,
        children: [
          _performanceBoundary(
            DashboardScreen(
              key: const PageStorageKey('dashboard-tab'),
              user: _user,
              trips: _visibleTrips,
              activeTrip: _visibleActiveTrip,
              onCreate: () => setState(() {
                _screen = _Screen.create;
                _tab = _NavTab.add;
              }),
              onOpenTrip: _openTrip,
              onStartTrip: _startTrip,
              onAskAi: _openTripAssistant,
              onOpenInfo: () => setState(() => _screen = _Screen.info),
              onOpenTranslate: () =>
                  setState(() => _screen = _Screen.translate),
              onOpenMap: () => setState(() => _screen = _Screen.map),
              onOpenNotifications: _openNotificationCenter,
            ),
            performance,
          ),
          _performanceBoundary(
            TripsScreen(
              key: const PageStorageKey('trips-tab'),
              trips: _visibleTrips,
              memories: _tripMemories,
              onCreate: () => setState(() {
                _screen = _Screen.create;
                _tab = _NavTab.add;
              }),
              onOpenTrip: _openTrip,
              onStartTrip: _startTrip,
              onDeleteTrip: _deleteTrip,
            ),
            performance,
          ),
          _performanceBoundary(
            ChatListScreen(
              key: const PageStorageKey('chat-list-tab'),
              account: widget.account,
              user: _user,
              onRoomOpenChanged: _setChatRoomOpen,
              onAppBarActionsChanged: _setChatListAppBarActions,
            ),
            performance,
          ),
          _performanceBoundary(
            ProfileScreen(
              key: const PageStorageKey('profile-tab'),
              account: widget.account,
              user: _user,
            ),
            performance,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildScreen() {
    switch (_screen) {
      case _Screen.dashboard:
        return DashboardScreen(
          key: const ValueKey('dashboard'),
          user: _user,
          trips: _visibleTrips,
          activeTrip: _visibleActiveTrip,
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onStartTrip: _startTrip,
          onAskAi: _openTripAssistant,
          onOpenInfo: () => setState(() => _screen = _Screen.info),
          onOpenTranslate: () => setState(() => _screen = _Screen.translate),
          onOpenMap: () => setState(() => _screen = _Screen.map),
          onOpenNotifications: _openNotificationCenter,
        );
      case _Screen.notifications:
        return NotificationsScreen(
          key: const ValueKey('notifications'),
          archivedNotificationIds: _archivedNotificationIds,
          onArchive: (id) => setState(() => _archivedNotificationIds.add(id)),
          onRestore: (id) =>
              setState(() => _archivedNotificationIds.remove(id)),
          onBack: () => setState(() => _screen = _Screen.dashboard),
        );
      case _Screen.create:
        return CreateTripScreen(
          key: const ValueKey('create'),
          profileLanguage: _user.language,
          savedTrips: _trips,
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onGenerate: _createTrip,
        );
      case _Screen.tripDetail:
        final trip = _selectedTrip;
        if (trip == null) {
          return _NoTripSelectedScreen(
            key: const ValueKey('no-trip-detail'),
            title: 'Trip',
            onBack: () => setState(() {
              _screen = _Screen.dashboard;
              _tab = _NavTab.home;
            }),
            onCreate: () => setState(() {
              _screen = _Screen.create;
              _tab = _NavTab.add;
            }),
          );
        }
        return TripDetailScreen(
          key: ValueKey('trip-detail-${trip.id}'),
          trip: trip,
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onOpenChat: () => setState(() {
            _screen = _Screen.chatList;
            _tab = _NavTab.chat;
          }),
          onOpenBudget: () => setState(() => _screen = _Screen.budget),
          onOpenPacking: () => setState(() => _screen = _Screen.packing),
          onUpdateTrip: _updateTrip,
          accountId: _accountId ?? widget.account.uid,
          repository: _repository,
          onLeftTrip: () => setState(() {
            _selectedTrip = null;
            _screen = _Screen.trips;
          }),
          initialTabIndex: _tripDetailInitialTab,
          initialAiPrompt: _pendingTripAiPrompt,
        );
      case _Screen.trips:
        return TripsScreen(
          key: const ValueKey('trips'),
          trips: _visibleTrips,
          memories: _tripMemories,
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onStartTrip: _startTrip,
          onDeleteTrip: _deleteTrip,
        );
      case _Screen.chatList:
        return ChatListScreen(
          key: const ValueKey('chat-list'),
          account: widget.account,
          user: _user,
          onRoomOpenChanged: _setChatRoomOpen,
        );
      case _Screen.profile:
        return ProfileScreen(
          key: const ValueKey('profile'),
          account: widget.account,
          user: _user,
        );
      case _Screen.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          account: widget.account,
          user: _user,
          authService: _authService,
          onSave: _saveProfile,
          onSignOut: _authService.signOut,
          onDeleteAccount: _deleteAccount,
          onBack: () => setState(() => _screen = _Screen.profile),
          onOpenLinkedAccounts: () =>
              setState(() => _screen = _Screen.linkedAccounts),
          onOpenPerformance: () =>
              setState(() => _screen = _Screen.performance),
          archivedItemCount:
              _tripMemories.length + _archivedNotificationIds.length,
          onOpenArchived: () => setState(() => _screen = _Screen.archived),
        );
      case _Screen.linkedAccounts:
        return LinkedAccountsScreen(
          key: const ValueKey('linked-accounts'),
          authService: _authService,
          onBack: () => setState(() => _screen = _Screen.settings),
        );
      case _Screen.archived:
        return ArchivedItemsScreen(
          key: const ValueKey('archived'),
          tripMemories: _tripMemories,
          archivedNotificationIds: _archivedNotificationIds,
          onRestoreNotification: (id) =>
              setState(() => _archivedNotificationIds.remove(id)),
          onBack: () => setState(() => _screen = _Screen.settings),
        );
      case _Screen.performance:
        return PerformanceSettingsScreen(
          key: const ValueKey('performance'),
          onBack: () => setState(() => _screen = _Screen.settings),
          onSettingsChanged: _savePerformanceSettings,
        );
      case _Screen.map:
        final trip = _selectedTrip ?? _visibleActiveTrip;
        if (trip == null) {
          return _NoTripSelectedScreen(
            key: const ValueKey('no-trip-map'),
            title: 'Map',
            onBack: () => setState(() => _screen = _Screen.dashboard),
            onCreate: () => setState(() {
              _screen = _Screen.create;
              _tab = _NavTab.add;
            }),
          );
        }
        return MapScreen(
          key: const ValueKey('map'),
          trip: trip,
          onBack: () => setState(
            () => _screen = _selectedTrip == null
                ? _Screen.dashboard
                : _Screen.tripDetail,
          ),
        );
      case _Screen.info:
        return InfoScreen(
          key: const ValueKey('info'),
          onBack: () => setState(() => _screen = _Screen.dashboard),
        );
      case _Screen.translate:
        return TranslateScreen(
          key: const ValueKey('translate'),
          onBack: () => setState(() => _screen = _Screen.dashboard),
        );
      case _Screen.budget:
        final trip = _selectedTrip;
        if (trip == null) {
          return _NoTripSelectedScreen(
            key: const ValueKey('no-trip-budget'),
            title: 'Budget',
            onBack: () => setState(() => _screen = _Screen.dashboard),
            onCreate: () => setState(() {
              _screen = _Screen.create;
              _tab = _NavTab.add;
            }),
          );
        }
        return BudgetScreen(
          key: const ValueKey('budget'),
          trip: trip,
          onBack: () => setState(() => _screen = _Screen.tripDetail),
        );
      case _Screen.packing:
        final trip = _selectedTrip;
        if (trip == null) {
          return _NoTripSelectedScreen(
            key: const ValueKey('no-trip-packing'),
            title: 'Packing',
            onBack: () => setState(() => _screen = _Screen.dashboard),
            onCreate: () => setState(() {
              _screen = _Screen.create;
              _tab = _NavTab.add;
            }),
          );
        }
        return PackingScreen(
          key: const ValueKey('packing'),
          trip: trip,
          onBack: () => setState(() => _screen = _Screen.tripDetail),
        );
    }
  }

  // ignore: unused_element
  void _selectTab(_NavTab tab) {
    setState(() {
      _tab = tab;
      _screen = switch (tab) {
        _NavTab.home => _Screen.dashboard,
        _NavTab.trips => _Screen.trips,
        _NavTab.add => _Screen.create,
        _NavTab.chat => _Screen.chatList,
        _NavTab.profile => _Screen.profile,
      };
    });
  }

  Future<void> _syncTripReminders() {
    return _notificationService.syncTripReminders(
      activeTrip: _activeTrip,
      trips: _visibleTrips,
      enabled: _user.notificationsEnabled,
    );
  }

  Future<void> _syncPushTokenRegistration() async {
    await _syncPushTokenRegistrationResult();
  }

  Future<PushTokenSyncResult> _syncPushTokenRegistrationResult({
    bool? enabled,
  }) {
    final accountId = _accountId ?? widget.account.uid;
    return _pushTokenService.sync(
      accountId: accountId,
      enabled: enabled ?? _user.notificationsEnabled,
    );
  }

  Future<void> _enableNotificationsFromDashboard() async {
    try {
      PushTokenSyncResult result;
      if (_user.notificationsEnabled) {
        result = await _syncPushTokenRegistrationResult();
        await _syncTripReminders();
      } else {
        result = await _syncPushTokenRegistrationResult(enabled: true);
        if (result.registered) {
          await _saveProfile(_user.copyWith(notificationsEnabled: true));
          await _syncTripReminders();
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(appText(context, result.message))),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(appText(context, 'Could not enable notifications.')),
          ),
        );
    }
  }

  void _openNotificationCenter() {
    final trip =
        _visibleActiveTrip ??
        (_visibleTrips.isEmpty ? null : _visibleTrips.first);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NotificationCenterSheet(
        notificationsEnabled: _user.notificationsEnabled,
        trip: trip,
        upcomingTripCount: _visibleTrips
            .where((trip) => trip.status != TripStatus.past)
            .length,
        onEnableNotifications: () {
          Navigator.of(sheetContext).pop();
          unawaited(_enableNotificationsFromDashboard());
        },
        onOpenTrip: trip == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                _openTrip(trip);
                _router.go(_tripLocation(trip.id));
              },
      ),
    );
  }

  void _queueTripAutomation(List<Trip> trips) {
    for (final trip in trips) {
      if (!trip.canEdit) continue;
      final key = _tripAutomationKey(trip);
      if (_automationCheckedKeys.contains(key)) continue;
      if (!_automationInFlight.add(key)) continue;

      unawaited(() async {
        try {
          final enrichedTrip = await _automationService.enrichTrip(trip);
          if (enrichedTrip == null || !mounted) return;

          final saved = await _saveTripOnline(enrichedTrip);
          if (!saved || !mounted) return;

          setState(() {
            final index = _trips.indexWhere((item) => item.id == trip.id);
            if (index != -1) _trips[index] = enrichedTrip;
            if (_selectedTrip?.id == trip.id) _selectedTrip = enrichedTrip;
            _activeTrip = _firstOngoingTrip(_visibleTrips);
          });
          unawaited(_syncTripReminders());
        } finally {
          _automationInFlight.remove(key);
          _automationCheckedKeys.add(key);
        }
      }());
    }
  }

  String _tripAutomationKey(Trip trip) {
    final latitude = trip.latitude?.toStringAsFixed(3) ?? 'no-lat';
    final longitude = trip.longitude?.toStringAsFixed(3) ?? 'no-lng';
    return [
      trip.id,
      trip.startDate,
      trip.endDate,
      latitude,
      longitude,
      _dateKey(_travelAgentNow()),
    ].join('|');
  }

  void _setChatRoomOpen(bool isOpen) {
    if (_isChatRoomOpen == isOpen) return;
    setState(() => _isChatRoomOpen = isOpen);
  }

  void _setActiveChatId(String? chatId) {
    final normalized = chatId?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (_activeChatId == next) return;
    _activeChatId = next;
    unawaited(
      _pushTokenService.updatePresence(
        isForeground: _isAppForeground,
        activeChatId: _activeChatId,
      ),
    );
  }
}

class _NoTripSelectedScreen extends StatelessWidget {
  const _NoTripSelectedScreen({
    required this.title,
    required this.onBack,
    required this.onCreate,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 18, bottom: 112),
        children: [
          TopBar(title: title, onBack: onBack),
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(icon: Icons.travel_explore_rounded, size: 48),
                const SizedBox(height: 14),
                Text(
                  appText(context, 'No trip yet'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appText(context, 'Create a trip to use this page.'),
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Create trip',
                  icon: Icons.add_rounded,
                  onPressed: onCreate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Trip? _firstOngoingTrip(List<Trip> trips) {
  for (final trip in trips) {
    if (trip.status == TripStatus.ongoing) return trip;
  }
  return null;
}

Trip? _tripById(List<Trip> trips, String? tripId) {
  if (tripId == null) return null;
  for (final trip in trips) {
    if (trip.id == tripId) return trip;
  }
  return null;
}

enum _NavTab { home, trips, add, chat, profile }

enum _Screen {
  dashboard,
  notifications,
  create,
  tripDetail,
  trips,
  chatList,
  profile,
  settings,
  linkedAccounts,
  archived,
  performance,
  map,
  info,
  translate,
  budget,
  packing,
}

class _TravelRouteRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _AppTutorialOverlay extends StatefulWidget {
  const _AppTutorialOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_AppTutorialOverlay> createState() => _AppTutorialOverlayState();
}

class _AppTutorialOverlayState extends State<_AppTutorialOverlay> {
  final _controller = PageController();
  var _page = 0;

  static const _steps = [
    (
      Icons.home_rounded,
      'Your travel dashboard',
      'See your current trip, AI suggestions, saved places, and important alerts.',
    ),
    (
      Icons.luggage_rounded,
      'Trips in one place',
      'Create plans, swipe to manage trips, and rate completed journeys.',
    ),
    (
      Icons.forum_rounded,
      'Plan together',
      'Use group chat and the travel assistant while keeping every trip organized.',
    ),
    (
      Icons.person_rounded,
      'Your travel profile',
      'Find favorite places and trips, settings, archives, and performance controls.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    return Material(
      color: Colors.black.withValues(alpha: .56),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 16,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Close tutorial',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          physics: settings.animationsEnabled
                              ? const PageScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _steps.length,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconBadge(icon: step.$1, size: 72),
                                  const SizedBox(height: 24),
                                  Text(
                                    step.$2,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    step.$3,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_page + 1} of ${_steps.length}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              if (_page == _steps.length - 1) {
                                widget.onClose();
                                return;
                              }
                              _controller.animateToPage(
                                _page + 1,
                                duration: settings.transitionDuration,
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: Text(
                              _page == _steps.length - 1
                                  ? 'Start exploring'
                                  : 'Next',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
