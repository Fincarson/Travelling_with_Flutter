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
  final _notificationService = TripNotificationService();
  static const _localProfilePrefix = 'travel_agent.profile.';
  static const _tripDeleteUndoWindow = Duration(seconds: 5);
  StreamSubscription<UserProfile?>? _userSubscription;
  StreamSubscription<List<Trip>>? _tripsSubscription;
  var _isLoading = true;
  var _tab = _NavTab.home;
  var _screen = _Screen.dashboard;
  var _isChatRoomOpen = false;
  var _tripDetailInitialTab = 0;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  final Map<String, Timer> _pendingTripDeleteTimers = {};
  final Set<String> _pendingTripDeleteIds = {};
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String? _pendingTripAiPrompt;
  String? _accountId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final accountId = widget.account.uid;

    var loadError = <String>[];
    final localProfile = await _loadLocalProfile(accountId);
    UserProfile? remoteProfile;
    try {
      remoteProfile = await _repository.loadUser(accountId);
    } catch (error) {
      loadError.add('Could not sync profile data: $error');
    }

    final loadedProfile = remoteProfile ?? localProfile;
    final user =
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

    if (!mounted) return;
    setState(() {
      _accountId = accountId;
      _user = user;
      _isLoading = false;
      _loadError = loadError.isEmpty ? null : loadError.join('\n');
    });
    AppLocaleController.setProfileLanguage(user.language);
    await PerformanceScope.of(context).update(user.performanceSettings);
    if (loadedProfile != null) {
      await _saveLocalProfile(accountId, user);
    }

    try {
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      final visibleTrips = _withoutPendingDeletes(trips);
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(visibleTrips);
        _loadError = loadError.isEmpty ? null : loadError.join('\n');
      });
      unawaited(_syncTripReminders());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load online trip data: $error');
    }

    _watchAccountData(accountId);
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
              _loadError = null;
            });
            unawaited(_syncTripReminders());
            AppLocaleController.setProfileLanguage(profile.language);
            unawaited(
              PerformanceScope.of(context).update(profile.performanceSettings),
            );
            unawaited(_saveLocalProfile(accountId, profile));
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
            unawaited(_syncTripReminders());
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync trip data: $error');
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
      _tripDetailInitialTab = 6;
      _pendingTripAiPrompt = prompt;
    });
  }

  Future<void> _saveProfile(UserProfile profile) async {
    setState(() {
      _user = profile;
      _loadError = null;
    });
    unawaited(_syncTripReminders());
    AppLocaleController.setProfileLanguage(profile.language);

    final accountId = _accountId ?? widget.account.uid;
    await _saveLocalProfile(accountId, profile);
    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
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
    if (trip.status == TripStatus.ongoing) return;

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
    if (_pendingTripDeleteIds.contains(trip.id)) return;
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
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      final visibleTrips = _withoutPendingDeletes(trips);
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(visibleTrips);
        _selectedTrip =
            _tripById(visibleTrips, selectTripId) ??
            _matchingTrip(visibleTrips, _selectedTrip);
        _loadError = null;
      });
      unawaited(_syncTripReminders());
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
    for (final timer in _pendingTripDeleteTimers.values) {
      timer.cancel();
    }
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
    if (_screen == _Screen.chatList && _isChatRoomOpen) return false;
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
            ),
            performance,
          ),
          _performanceBoundary(
            TripsScreen(
              key: const PageStorageKey('trips-tab'),
              trips: _visibleTrips,
              onBack: () => setState(() => _screen = _Screen.dashboard),
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
          onOpenMap: () => setState(() => _screen = _Screen.map),
          onUpdateTrip: _updateTrip,
          initialTabIndex: _tripDetailInitialTab,
          initialAiPrompt: _pendingTripAiPrompt,
        );
      case _Screen.trips:
        return TripsScreen(
          key: const ValueKey('trips'),
          trips: _visibleTrips,
          onBack: () => setState(() => _screen = _Screen.dashboard),
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
          onSettingsChanged: _savePerformanceSettings,
        );
      case _Screen.map:
        final trip = _selectedTrip;
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
      enabled: _user.notificationsEnabled,
    );
  }

  void _setChatRoomOpen(bool isOpen) {
    if (_isChatRoomOpen == isOpen) return;
    setState(() => _isChatRoomOpen = isOpen);
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
  profile,
  performance,
  map,
  info,
  translate,
  budget,
  packing,
}

enum _NavTab { home, trips, add, chat, profile }
