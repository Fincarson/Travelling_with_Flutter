part of travel_agent_app;

class TravelAgentApp extends StatefulWidget {
  const TravelAgentApp({required this.account, super.key});

  final AuthenticatedAccount account;

  @override
  State<TravelAgentApp> createState() => _TravelAgentAppState();
}

class _TravelAgentAppState extends State<TravelAgentApp> {
  final _repository = TravelDataRepository(FirebaseFirestore.instance);
  final _authService = AccountAuthService();
  StreamSubscription<UserProfile?>? _userSubscription;
  StreamSubscription<List<Trip>>? _tripsSubscription;
  var _showOnboarding = true;
  var _isLoading = true;
  var _tab = _NavTab.home;
  var _screen = _Screen.dashboard;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String _initialChat = '';
  String? _accountId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final accountId = widget.account.uid;

    try {
      final profile = await _repository.loadUser(accountId);
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      final user =
          profile ??
          UserProfile(
            name: widget.account.name,
            email: widget.account.email ?? '',
            photoUrl: widget.account.photoUrl,
            interests: const [],
            language: 'en',
            notificationsEnabled: true,
            themeMode: 'Light',
          );
      setState(() {
        _accountId = accountId;
        _user = user;
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(trips);
        _showOnboarding = profile == null;
        _isLoading = false;
      });
      AppLocaleController.setProfileLanguage(user.language);
      _watchAccountData(accountId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load online trip data: $error';
        _isLoading = false;
      });
    }
  }

  void _watchAccountData(String accountId) {
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();

    _userSubscription = _repository
        .watchUser(accountId)
        .listen(
          (profile) {
            if (!mounted || profile == null) return;
            setState(() {
              _user = profile;
              _showOnboarding = false;
              _loadError = null;
            });
            AppLocaleController.setProfileLanguage(profile.language);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync profile data: $error');
          },
        );

    _tripsSubscription = _repository
        .watchTrips(accountId)
        .listen(
          (trips) {
            if (!mounted) return;
            setState(() {
              _trips
                ..clear()
                ..addAll(trips);
              _activeTrip = _firstOngoingTrip(trips);
              _selectedTrip = _matchingTrip(trips, _selectedTrip);
              if (_screen == _Screen.tripDetail && _selectedTrip == null) {
                _screen = _Screen.dashboard;
                _tab = _NavTab.home;
              }
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync trip data: $error');
          },
        );
  }

  void _openTrip(Trip trip) {
    setState(() {
      _selectedTrip = trip;
      _screen = _Screen.tripDetail;
      _tab = _NavTab.trips;
    });
  }

  Future<void> _completeOnboarding(UserProfile profile) async {
    final accountId = widget.account.uid;

    setState(() {
      _accountId = accountId;
      _user = profile;
      _showOnboarding = false;
      _loadError = null;
    });
    AppLocaleController.setProfileLanguage(profile.language);

    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    setState(() {
      _user = profile;
      _loadError = null;
    });
    AppLocaleController.setProfileLanguage(profile.language);

    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
    }
  }

  Future<void> _createTrip(Trip trip) async {
    final saved = await _saveTripOnline(trip);
    if (!saved || !mounted) return;
    await _refreshTripsFromBackend(selectTripId: trip.id);
    if (!mounted) return;
    setState(() {
      _screen = _Screen.tripDetail;
      _tab = _NavTab.trips;
    });
  }

  Future<void> _startTrip(Trip trip) async {
    final previousActive = _activeTrip;
    final started = trip.copyWith(status: TripStatus.ongoing);
    final saved = await _saveTripOnline(started);
    if (!saved) return;
    if (previousActive != null && previousActive.id != trip.id) {
      await _saveTripOnline(
        previousActive.copyWith(status: TripStatus.upcoming),
      );
    }
    if (!mounted) return;
    await _refreshTripsFromBackend(selectTripId: trip.id);
    if (!mounted) return;
    setState(() {
      _screen = _Screen.dashboard;
      _tab = _NavTab.home;
    });
  }

  Future<void> _updateTrip(Trip trip) async {
    final saved = await _saveTripOnline(trip);
    if (!saved || !mounted) return;
    await _refreshTripsFromBackend(selectTripId: trip.id);
  }

  Future<bool> _saveTripOnline(Trip trip) async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.saveTrip(accountId, trip);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _loadError = 'Could not save trip online: $error');
      return false;
    }
  }

  Future<void> _refreshTripsFromBackend({String? selectTripId}) async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(trips);
        _selectedTrip =
            _tripById(trips, selectTripId) ??
            _matchingTrip(trips, _selectedTrip);
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not refresh trip data: $error');
    }
  }

  Future<void> _deleteAccount() async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      _authService.ensureCanDeleteCurrentAccount();
      await _repository.deleteUserData(accountId);
      await _authService.deleteCurrentAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not delete account: $error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.settingsOf(context);
    final body = performance.cachePages && _isCachedTabScreen
        ? _buildCachedTabStack(performance)
        : _performanceBoundary(_buildScreen(), performance);

    return Theme(
      data: _user.themeMode == 'Dark'
          ? TravelAgentTheme.dark()
          : TravelAgentTheme.light(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? const LoadingScreen()
              : _showOnboarding
              ? OnboardingScreen(
                  account: widget.account,
                  onComplete: _completeOnboarding,
                )
              : Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: performance.transitionDuration,
                      child: body,
                    ),
                    if (_showsBottomNav)
                      _BottomNav(tab: _tab, onSelect: _selectTab),
                    if (_loadError != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 12,
                        child: SyncBanner(message: _loadError!),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  bool get _isCachedTabScreen {
    return switch (_screen) {
      _Screen.dashboard ||
      _Screen.trips ||
      _Screen.chatList ||
      _Screen.profile => true,
      _ => false,
    };
  }

  bool get _showsBottomNav {
    return switch (_screen) {
      _Screen.create || _Screen.performance => false,
      _ => true,
    };
  }

  int get _cachedTabIndex {
    return switch (_screen) {
      _Screen.dashboard => 0,
      _Screen.trips => 1,
      _Screen.chatList => 2,
      _Screen.profile => 3,
      _ => 0,
    };
  }

  Widget _performanceBoundary(
    Widget child,
    AppPerformanceSettings performance,
  ) {
    if (!performance.isolateRepaints) return child;
    return RepaintBoundary(child: child);
  }

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
              trips: _trips,
              activeTrip: _activeTrip,
              onCreate: () => setState(() {
                _screen = _Screen.create;
                _tab = _NavTab.add;
              }),
              onOpenTrip: _openTrip,
              onAskAi: (query) => setState(() {
                _initialChat = query;
                _screen = _Screen.chatRoom;
                _tab = _NavTab.chat;
              }),
              onOpenInfo: () => setState(() => _screen = _Screen.info),
              onOpenTranslate: () =>
                  setState(() => _screen = _Screen.translate),
              onOpenMap: () => setState(() => _screen = _Screen.map),
            ),
            performance,
          ),
          _performanceBoundary(
            TripsScreen(
              key: const PageStorageKey('trips-tab'),
              trips: _trips,
              onBack: () => setState(() => _screen = _Screen.dashboard),
              onCreate: () => setState(() {
                _screen = _Screen.create;
                _tab = _NavTab.add;
              }),
              onOpenTrip: _openTrip,
              onStartTrip: _startTrip,
            ),
            performance,
          ),
          _performanceBoundary(
            ChatListScreen(
              key: const PageStorageKey('chat-list-tab'),
              trips: _trips,
              onOpen: (query) => setState(() {
                _initialChat = query;
                _screen = _Screen.chatRoom;
              }),
            ),
            performance,
          ),
          _performanceBoundary(
            ProfileScreen(
              key: const PageStorageKey('profile-tab'),
              account: widget.account,
              user: _user,
              onSave: _saveProfile,
              onSignOut: _authService.signOut,
              onDeleteAccount: _deleteAccount,
              onOpenPerformance: () =>
                  setState(() => _screen = _Screen.performance),
            ),
            performance,
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case _Screen.dashboard:
        return DashboardScreen(
          key: const ValueKey('dashboard'),
          user: _user,
          trips: _trips,
          activeTrip: _activeTrip,
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onAskAi: (query) => setState(() {
            _initialChat = query;
            _screen = _Screen.chatRoom;
            _tab = _NavTab.chat;
          }),
          onOpenInfo: () => setState(() => _screen = _Screen.info),
          onOpenTranslate: () => setState(() => _screen = _Screen.translate),
          onOpenMap: () => setState(() => _screen = _Screen.map),
        );
      case _Screen.create:
        return CreateTripScreen(
          key: const ValueKey('create'),
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onGenerate: _createTrip,
        );
      case _Screen.tripDetail:
        return TripDetailScreen(
          key: ValueKey('trip-detail-${_selectedTrip?.id}'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onOpenChat: () => setState(() {
            _initialChat =
                'Help optimize ${(_selectedTrip ?? mockKyotoTrip).destination}.';
            _screen = _Screen.chatRoom;
            _tab = _NavTab.chat;
          }),
          onOpenBudget: () => setState(() => _screen = _Screen.budget),
          onOpenPacking: () => setState(() => _screen = _Screen.packing),
          onOpenMap: () => setState(() => _screen = _Screen.map),
          onUpdateTrip: _updateTrip,
        );
      case _Screen.trips:
        return TripsScreen(
          key: const ValueKey('trips'),
          trips: _trips,
          onBack: () => setState(() => _screen = _Screen.dashboard),
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onStartTrip: _startTrip,
        );
      case _Screen.chatList:
        return ChatListScreen(
          key: const ValueKey('chat-list'),
          trips: _trips,
          onOpen: (query) => setState(() {
            _initialChat = query;
            _screen = _Screen.chatRoom;
          }),
        );
      case _Screen.chatRoom:
        return ChatRoomScreen(
          key: ValueKey('chat-$_initialChat'),
          initialQuery: _initialChat,
          onBack: () => setState(() => _screen = _Screen.chatList),
        );
      case _Screen.profile:
        return ProfileScreen(
          key: const ValueKey('profile'),
          account: widget.account,
          user: _user,
          onSave: _saveProfile,
          onSignOut: _authService.signOut,
          onDeleteAccount: _deleteAccount,
          onOpenPerformance: () =>
              setState(() => _screen = _Screen.performance),
        );
      case _Screen.performance:
        return PerformanceSettingsScreen(
          key: const ValueKey('performance'),
          onBack: () => setState(() => _screen = _Screen.profile),
        );
      case _Screen.map:
        return MapScreen(
          key: const ValueKey('map'),
          trip: _selectedTrip ?? mockKyotoTrip,
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
        return BudgetScreen(
          key: const ValueKey('budget'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() => _screen = _Screen.tripDetail),
        );
      case _Screen.packing:
        return PackingScreen(
          key: const ValueKey('packing'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() => _screen = _Screen.tripDetail),
        );
    }
  }

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
}

Trip? _firstOngoingTrip(List<Trip> trips) {
  for (final trip in trips) {
    if (trip.status == TripStatus.ongoing) return trip;
  }
  return null;
}

Trip? _matchingTrip(List<Trip> trips, Trip? current) {
  if (current == null) return null;
  for (final trip in trips) {
    if (trip.id == current.id) return trip;
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

enum _Screen {
  dashboard,
  create,
  tripDetail,
  trips,
  chatList,
  chatRoom,
  profile,
  performance,
  map,
  info,
  translate,
  budget,
  packing,
}

enum _NavTab { home, trips, add, chat, profile }
