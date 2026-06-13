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
  final _routerRefresh = _TravelRouteRefresh();
  late final GoRouter _router;
  StreamSubscription<UserProfile?>? _userSubscription;
  StreamSubscription<List<Trip>>? _tripsSubscription;
  StreamSubscription<List<TripMemory>>? _memoriesSubscription;
  var _isLoading = true;
  var _isChatRoomOpen = false;
  var _screen = _Screen.dashboard;
  var _tab = _NavTab.home;
  var _tripDetailInitialTab = 0;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  final List<TripMemory> _tripMemories = [];
  final Map<String, Timer> _pendingTripDeleteTimers = {};
  final Set<String> _pendingTripDeleteIds = {};
  final Set<String> _archivedNotificationIds = {};
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String? _pendingTripAiPrompt;
  String? _accountId;
  String? _loadError;

  int get _cachedTabIndex => switch (_tab) {
    _NavTab.home => 0,
    _NavTab.trips || _NavTab.add => 1,
    _NavTab.chat => 2,
    _NavTab.profile => 3,
  };

  @override
  void initState() {
    super.initState();
    _router = AppRouter._createTravelAgentRouter(
      appState: this,
      refreshListenable: _routerRefresh,
    );
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

    await _archiveExpiredTripsQuietly(accountId);

    try {
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
      unawaited(_syncTripReminders());
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load online trip data: $error');
    }

    _watchAccountData(accountId);
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
      await _repository.saveUser(
        accountId,
        profile.copyWith(onboardingRequired: false, onboardingCompleted: true),
      );
      await _repository.completeOnboarding(accountId);
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
    await _refreshTripsFromBackend();
    if (!mounted || !context.mounted) return;
    context.replace(_tripLocation(trip.id));
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
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();
    _memoriesSubscription?.cancel();
    for (final timer in _pendingTripDeleteTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    Router.withConfig(config: _router),
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

  Widget _performanceBoundary(
    Widget child,
    AppPerformanceSettings performance,
  ) {
    if (!performance.isolateRepaints) return child;
    return RepaintBoundary(child: child);
  }

  Widget _buildOnboardingScreen() {
    return OnboardingScreen(
      account: widget.account,
      onComplete: (profile) {
        unawaited(_saveProfile(profile));
        if (mounted && context.mounted) context.go('/');
      },
    );
  }

  Widget _buildDashboardScreen(BuildContext context) {
    return DashboardScreen(
      user: _user,
      trips: _visibleTrips,
      activeTrip: _visibleActiveTrip,
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
      onOpenNotifications: () => context.go('/notifications'),
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
      onBack: () => context.go('/'),
      onCreate: () => context.go('/trips/new'),
      onOpenTrip: (trip) => context.go(_tripLocation(trip.id)),
      onStartTrip: _startTrip,
      onDeleteTrip: _deleteTrip,
    );
  }

  Widget _buildCreateTripScreen(BuildContext context) {
    return CreateTripScreen(
      profileLanguage: _user.language,
      savedTrips: _trips,
      onBack: () => context.go('/trips'),
      onGenerate: _createTrip,
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
      onOpenMap: () => context.go('/trips/${trip.id}/map'),
      onUpdateTrip: _updateTrip,
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
      account: widget.account,
      user: _user,
      onRoomOpenChanged: _setChatRoomOpen,
      onOpenChat: (chatId) => context.go('/chat/$chatId'),
    );
  }

  Widget _buildGroupChatRoomScreen(BuildContext context, String chatId) {
    return RoutedGroupChatRoomScreen(
      chatId: chatId,
      account: widget.account,
      user: _user,
      onBack: () => context.go('/chat'),
      onRoomOpenChanged: _setChatRoomOpen,
    );
  }

  Widget _buildProfileScreen(BuildContext context) {
    return ProfileScreen(
      account: widget.account,
      user: _user,
      onSave: _saveProfile,
      onSignOut: _authService.signOut,
      onDeleteAccount: _deleteAccount,
      onOpenPerformance: () => context.go('/profile/performance'),
      archivedItemCount: _tripMemories.length + _archivedNotificationIds.length,
      onOpenArchived: () => context.go('/profile/archived'),
    );
  }

  Widget _buildArchivedItemsScreen(BuildContext context) {
    return ArchivedItemsScreen(
      tripMemories: _tripMemories,
      archivedNotificationIds: _archivedNotificationIds,
      onRestoreNotification: (id) =>
          setState(() => _archivedNotificationIds.remove(id)),
      onBack: () => context.go('/profile'),
    );
  }

  Widget _buildPerformanceSettingsScreen(BuildContext context) {
    return PerformanceSettingsScreen(
      onBack: () => context.go('/profile'),
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
              onOpenNotifications: () =>
                  setState(() => _screen = _Screen.notifications),
            ),
            performance,
          ),
          _performanceBoundary(
            TripsScreen(
              key: const PageStorageKey('trips-tab'),
              trips: _visibleTrips,
              memories: _tripMemories,
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
              archivedItemCount:
                  _tripMemories.length + _archivedNotificationIds.length,
              onOpenArchived: () => setState(() => _screen = _Screen.archived),
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
          onOpenNotifications: () =>
              setState(() => _screen = _Screen.notifications),
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
          onOpenMap: () => setState(() => _screen = _Screen.map),
          onUpdateTrip: _updateTrip,
          initialTabIndex: _tripDetailInitialTab,
          initialAiPrompt: _pendingTripAiPrompt,
        );
      case _Screen.trips:
        return TripsScreen(
          key: const ValueKey('trips'),
          trips: _visibleTrips,
          memories: _tripMemories,
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
          archivedItemCount:
              _tripMemories.length + _archivedNotificationIds.length,
          onOpenArchived: () => setState(() => _screen = _Screen.archived),
        );
      case _Screen.archived:
        return ArchivedItemsScreen(
          key: const ValueKey('archived'),
          tripMemories: _tripMemories,
          archivedNotificationIds: _archivedNotificationIds,
          onRestoreNotification: (id) =>
              setState(() => _archivedNotificationIds.remove(id)),
          onBack: () => setState(() => _screen = _Screen.profile),
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
