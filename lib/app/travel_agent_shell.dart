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
  final _routerRefresh = _TravelRouteRefresh();
  late final GoRouter _router;
  StreamSubscription<UserProfile?>? _userSubscription;
  StreamSubscription<List<Trip>>? _tripsSubscription;
  var _showOnboarding = true;
  var _isLoading = true;
  var _isChatRoomOpen = false;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  Trip? _activeTrip;
  String? _accountId;
  String? _loadError;

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

    try {
      final profile = await _repository.loadUser(accountId);
      final shouldShowOnboarding = await _repository.shouldShowOnboarding(
        accountId,
      );
      final trips = shouldShowOnboarding
          ? const <Trip>[]
          : await _repository.loadTrips(accountId);
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
        _showOnboarding = shouldShowOnboarding;
        _isLoading = false;
      });
      _notifyRoutes();
      AppLocaleController.setProfileLanguage(user.language);
      _watchAccountData(accountId, watchTrips: !shouldShowOnboarding);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load online trip data: $error';
        _isLoading = false;
      });
      _notifyRoutes();
    }
  }

  void _watchAccountData(String accountId, {required bool watchTrips}) {
    _userSubscription?.cancel();
    _tripsSubscription?.cancel();

    _userSubscription = _repository
        .watchUser(accountId)
        .listen(
          (profile) {
            if (!mounted || profile == null) return;
            final shouldShowOnboarding =
                profile.onboardingRequired && !profile.onboardingCompleted;
            setState(() {
              _user = profile;
              _showOnboarding = shouldShowOnboarding;
              _loadError = null;
            });
            _notifyRoutes();
            AppLocaleController.setProfileLanguage(profile.language);
            if (!shouldShowOnboarding && _tripsSubscription == null) {
              _watchTrips(accountId);
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
            setState(() {
              _trips
                ..clear()
                ..addAll(trips);
              _activeTrip = _firstOngoingTrip(trips);
              _loadError = null;
            });
            _notifyRoutes();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _loadError = 'Could not sync trip data: $error');
            _notifyRoutes();
          },
        );
  }

  Future<void> _completeOnboarding(UserProfile profile) async {
    final accountId = widget.account.uid;

    setState(() {
      _accountId = accountId;
      _user = profile;
      _showOnboarding = false;
      _loadError = null;
    });
    _notifyRoutes();
    _router.go('/');
    AppLocaleController.setProfileLanguage(profile.language);

    try {
      await _repository.saveUser(
        accountId,
        profile.copyWith(onboardingRequired: false, onboardingCompleted: true),
      );
      await _repository.completeOnboarding(accountId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
      _notifyRoutes();
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    setState(() {
      _user = profile;
      _loadError = null;
    });
    _notifyRoutes();
    AppLocaleController.setProfileLanguage(profile.language);

    final accountId = _accountId ?? widget.account.uid;
    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
      _notifyRoutes();
    }
  }

  Future<void> _createTrip(BuildContext context, Trip trip) async {
    final saved = await _saveTripOnline(trip);
    if (!saved || !mounted) return;
    await _refreshTripsFromBackend();
    if (!mounted || !context.mounted) return;
    context.replace(_tripLocation(trip.id));
  }

  Future<bool> _startTrip(Trip trip) async {
    final previousActive = _activeTrip;
    final started = trip.copyWith(status: TripStatus.ongoing);
    final saved = await _saveTripOnline(started);
    if (!saved) return false;
    if (previousActive != null && previousActive.id != trip.id) {
      await _saveTripOnline(
        previousActive.copyWith(status: TripStatus.upcoming),
      );
    }
    if (!mounted) return false;
    await _refreshTripsFromBackend();
    return mounted;
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

  Future<void> _refreshTripsFromBackend() async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      setState(() {
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(trips);
        _loadError = null;
      });
      _notifyRoutes();
      _watchAccountData(accountId, watchTrips: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not refresh trip data: $error');
      _notifyRoutes();
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
    _router.dispose();
    _routerRefresh.dispose();
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

  Widget _buildDashboardScreen(BuildContext context) {
    return DashboardScreen(
      key: const ValueKey('dashboard'),
      user: _user,
      trips: _trips,
      activeTrip: _activeTrip,
      onCreate: () => context.push('/trips/new'),
      onOpenTrip: (trip) => context.push(_tripLocation(trip.id)),
      onAskAi: (_) => context.push('/chat'),
      onOpenInfo: () => context.push('/tools/info'),
      onOpenTranslate: () => context.push('/tools/translate'),
      onOpenMap: () => context.push('/tools/map'),
    );
  }

  Widget _buildCreateTripScreen(BuildContext context) {
    return CreateTripScreen(
      key: const ValueKey('create'),
      onBack: () => _popOrGo(context, '/trips'),
      onGenerate: (trip) => _createTrip(context, trip),
    );
  }

  Widget _buildOnboardingScreen() {
    return OnboardingScreen(
      key: const ValueKey('onboarding'),
      account: widget.account,
      onComplete: _completeOnboarding,
    );
  }

  Widget _buildTripDetailScreen(BuildContext context, String tripId) {
    final trip = _tripForRoute(tripId);
    final location = _tripLocation(trip.id);
    return TripDetailScreen(
      key: ValueKey('trip-detail-${trip.id}'),
      trip: trip,
      onBack: () => _popOrGo(context, '/trips'),
      onOpenChat: () => context.push('/chat'),
      onOpenBudget: () => context.push('$location/budget'),
      onOpenPacking: () => context.push('$location/packing'),
      onOpenMap: () => context.push('$location/map'),
      onUpdateTrip: _updateTrip,
    );
  }

  Widget _buildTripsScreen(BuildContext context) {
    return TripsScreen(
      key: const ValueKey('trips'),
      trips: _trips,
      onBack: () => _popOrGo(context, '/'),
      onCreate: () => context.push('/trips/new'),
      onOpenTrip: (trip) => context.push(_tripLocation(trip.id)),
      onStartTrip: (trip) async {
        final started = await _startTrip(trip);
        if (started && context.mounted) context.go('/');
      },
    );
  }

  Widget _buildChatListScreen(BuildContext context) {
    return ChatListScreen(
      key: const ValueKey('chat-list'),
      account: widget.account,
      user: _user,
      onRoomOpenChanged: _setChatRoomOpen,
      onOpenChat: (chatId) => context.push(_chatLocation(chatId)),
    );
  }

  Widget _buildGroupChatRoomScreen(BuildContext context, String chatId) {
    return RoutedGroupChatRoomScreen(
      key: ValueKey('chat-room-$chatId'),
      chatId: Uri.decodeComponent(chatId),
      account: widget.account,
      user: _user,
      onRoomOpenChanged: _setChatRoomOpen,
      onBack: () => _popOrGo(context, '/chat'),
    );
  }

  Widget _buildProfileScreen(BuildContext context) {
    return ProfileScreen(
      key: const ValueKey('profile'),
      account: widget.account,
      user: _user,
      onSave: _saveProfile,
      onSignOut: _authService.signOut,
      onDeleteAccount: _deleteAccount,
      onOpenPerformance: () => context.push('/profile/performance'),
    );
  }

  Widget _buildPerformanceSettingsScreen(BuildContext context) {
    return PerformanceSettingsScreen(
      key: const ValueKey('performance'),
      onBack: () => _popOrGo(context, '/profile'),
    );
  }

  Widget _buildGlobalMapScreen(BuildContext context) {
    return MapScreen(
      key: const ValueKey('map'),
      trip: _currentTripForTools,
      onBack: () => _popOrGo(context, '/'),
    );
  }

  Widget _buildTripMapScreen(BuildContext context, String tripId) {
    final trip = _tripForRoute(tripId);
    return MapScreen(
      key: ValueKey('trip-map-${trip.id}'),
      trip: trip,
      onBack: () => _popOrGo(context, _tripLocation(trip.id)),
    );
  }

  Widget _buildInfoScreen(BuildContext context) {
    return InfoScreen(
      key: const ValueKey('info'),
      onBack: () => _popOrGo(context, '/'),
    );
  }

  Widget _buildTranslateScreen(BuildContext context) {
    return TranslateScreen(
      key: const ValueKey('translate'),
      onBack: () => _popOrGo(context, '/'),
    );
  }

  Widget _buildBudgetScreen(BuildContext context, String tripId) {
    final trip = _tripForRoute(tripId);
    return BudgetScreen(
      key: ValueKey('budget-${trip.id}'),
      trip: trip,
      onBack: () => _popOrGo(context, _tripLocation(trip.id)),
    );
  }

  Widget _buildPackingScreen(BuildContext context, String tripId) {
    final trip = _tripForRoute(tripId);
    return PackingScreen(
      key: ValueKey('packing-${trip.id}'),
      trip: trip,
      onBack: () => _popOrGo(context, _tripLocation(trip.id)),
    );
  }

  Trip get _currentTripForTools {
    return _activeTrip ?? (_trips.isEmpty ? mockKyotoTrip : _trips.first);
  }

  Trip _tripForRoute(String tripId) {
    return _tripById(_trips, Uri.decodeComponent(tripId)) ?? mockKyotoTrip;
  }

  void _popOrGo(BuildContext context, String fallbackLocation) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackLocation);
  }

  void _setChatRoomOpen(bool isOpen) {
    if (_isChatRoomOpen == isOpen) return;
    setState(() => _isChatRoomOpen = isOpen);
    _notifyRoutes();
  }

  void _notifyRoutes() {
    if (!mounted) return;
    _routerRefresh.refresh();
  }
}

class _TravelRouteRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

String _tripLocation(String tripId) {
  return '/trips/${Uri.encodeComponent(tripId)}';
}

String _chatLocation(String chatId) {
  return '/chat/${Uri.encodeComponent(chatId)}';
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
