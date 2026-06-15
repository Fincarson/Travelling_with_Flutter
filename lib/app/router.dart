part of travel_agent_app;

class AppRouter {
  const AppRouter._();

  static GoRouter _createTravelAgentRouter({
    required _TravelAgentAppState appState,
    required Listenable refreshListenable,
  }) {
    return GoRouter(
      initialLocation: _initialTravelLocation(),
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        return null;
      },
      routes: [
        GoRoute(path: '/onboarding', redirect: (context, state) => '/'),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _TravelRouteFrame(
              appState: appState,
              navigationShell: navigationShell,
              location: state.uri.path,
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      appState._buildDashboardScreen(context),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      builder: (context, state) =>
                          appState._buildNotificationsScreen(context),
                    ),
                    GoRoute(
                      path: 'tools/info',
                      builder: (context, state) =>
                          appState._buildInfoScreen(context),
                    ),
                    GoRoute(
                      path: 'tools/translate',
                      builder: (context, state) =>
                          appState._buildTranslateScreen(context),
                    ),
                    GoRoute(
                      path: 'tools/map',
                      builder: (context, state) =>
                          appState._buildGlobalMapScreen(context),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trips',
                  builder: (context, state) =>
                      appState._buildTripsScreen(context),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) =>
                          appState._buildCreateTripScreen(context),
                    ),
                    GoRoute(
                      path: ':tripId',
                      builder: (context, state) =>
                          appState._buildTripDetailScreen(
                            context,
                            state.pathParameters['tripId'] ?? '',
                          ),
                      routes: [
                        GoRoute(
                          path: 'map',
                          builder: (context, state) =>
                              appState._buildTripMapScreen(
                                context,
                                state.pathParameters['tripId'] ?? '',
                              ),
                        ),
                        GoRoute(
                          path: 'budget',
                          builder: (context, state) =>
                              appState._buildBudgetScreen(
                                context,
                                state.pathParameters['tripId'] ?? '',
                              ),
                        ),
                        GoRoute(
                          path: 'packing',
                          builder: (context, state) =>
                              appState._buildPackingScreen(
                                context,
                                state.pathParameters['tripId'] ?? '',
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) =>
                      appState._buildChatListScreen(context),
                  routes: [
                    GoRoute(
                      path: ':chatId',
                      builder: (context, state) =>
                          appState._buildGroupChatRoomScreen(
                            context,
                            state.pathParameters['chatId'] ?? '',
                          ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      appState._buildProfileScreen(context),
                  routes: [
                    GoRoute(
                      path: 'settings',
                      builder: (context, state) =>
                          appState._buildSettingsScreen(context),
                      routes: [
                        GoRoute(
                          path: 'linked-accounts',
                          builder: (context, state) =>
                              appState._buildLinkedAccountsScreen(context),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'archived',
                      builder: (context, state) =>
                          appState._buildArchivedItemsScreen(context),
                    ),
                    GoRoute(
                      path: 'performance',
                      builder: (context, state) =>
                          appState._buildPerformanceSettingsScreen(context),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _initialTravelLocation() {
    if (!kIsWeb) return '/';
    final uri = Uri.base;
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }
}

class _TravelRouteFrame extends StatefulWidget {
  const _TravelRouteFrame({
    required this.appState,
    required this.navigationShell,
    required this.location,
  });

  final _TravelAgentAppState appState;
  final StatefulNavigationShell navigationShell;
  final String location;

  @override
  State<_TravelRouteFrame> createState() => _TravelRouteFrameState();
}

class _TravelRouteFrameState extends State<_TravelRouteFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController = AnimationController(
    vsync: this,
    value: 1,
  );
  Offset _slideBegin = Offset.zero;
  double _horizontalDrag = 0;
  bool _tracksHorizontalDrag = false;

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.settingsOf(context);
    final title = _mainPageTitle(widget.location);
    final headerAction = _headerAction(context, widget.location);
    _slideController.duration = performance.transitionDuration;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _resetHorizontalDrag,
            child: SlideTransition(
              position: Tween<Offset>(begin: _slideBegin, end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: _slideController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: Column(
                children: [
                  if (title != null)
                    _MainPageHeader(
                      title: title,
                      action: widget.location == '/profile'
                          ? IconButton(
                              tooltip: appText(context, 'Settings'),
                              onPressed: () => context.go('/profile/settings'),
                              icon: const Icon(Icons.settings_rounded),
                            )
                          : headerAction,
                    ),
                  Expanded(
                    child: widget.appState._performanceBoundary(
                      widget.navigationShell,
                      performance,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showsBottomNav(widget.location))
          _BottomNav(
            tab: _tabForIndex,
            onSelect: (tab) => _select(context, tab),
          ),
      ],
    );
  }

  Widget? _headerAction(BuildContext context, String location) {
    if (location == '/chat' && !widget.appState._isChatRoomOpen) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: appText(context, 'Accept invite'),
            onPressed: widget.appState._reviewChatInviteFromHeader,
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton.filled(
            tooltip: appText(context, 'Create chat'),
            onPressed: widget.appState._createChatFromHeader,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      );
    }

    return null;
  }

  bool _showsBottomNav(String location) {
    if (location == '/notifications' ||
        location == '/trips/new' ||
        location == '/profile/archived' ||
        location == '/profile/performance') {
      return false;
    }
    if (location.startsWith('/profile/settings')) return false;
    if (location.startsWith('/chat/') ||
        (location == '/chat' && widget.appState._isChatRoomOpen)) {
      return false;
    }
    return true;
  }

  String? _mainPageTitle(String location) {
    if (location == '/') return 'Home';
    if (location == '/trips') return 'Trips';
    if (location == '/trips/new') return 'New Plan';
    if (location == '/profile') return 'Profile';
    if (location == '/chat' && !widget.appState._isChatRoomOpen) return 'Chats';
    return null;
  }

  _NavTab get _tabForIndex {
    return switch (widget.navigationShell.currentIndex) {
      0 => _NavTab.home,
      1 => _NavTab.trips,
      2 => _NavTab.chat,
      3 => _NavTab.profile,
      _ => _NavTab.home,
    };
  }

  void _select(BuildContext context, _NavTab tab) {
    if (tab == _NavTab.add) {
      context.push('/trips/new');
      return;
    }

    final index = switch (tab) {
      _NavTab.home => 0,
      _NavTab.trips => 1,
      _NavTab.chat => 2,
      _NavTab.profile => 3,
      _NavTab.add => 1,
    };
    _goToMainTab(index);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    final isMainPage = _mainTabIndex(widget.location) != null;
    _tracksHorizontalDrag = isMainPage || details.globalPosition.dx <= 32;
    _horizontalDrag = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_tracksHorizontalDrag) return;
    _horizontalDrag += details.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_tracksHorizontalDrag) {
      _resetHorizontalDrag();
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final currentTab = _mainTabIndex(widget.location);
    if (currentTab != null) {
      if (_horizontalDrag <= -64 || velocity <= -550) {
        _goToMainTab(currentTab + 1);
      } else if (_horizontalDrag >= 64 || velocity >= 550) {
        _goToMainTab(currentTab - 1);
      }
    } else if (_horizontalDrag >= 64 || velocity >= 550) {
      _navigateBack();
    }
    _resetHorizontalDrag();
  }

  void _resetHorizontalDrag() {
    _tracksHorizontalDrag = false;
    _horizontalDrag = 0;
  }

  void _goToMainTab(int index) {
    if (index < 0 || index > 3) return;
    final currentIndex = widget.navigationShell.currentIndex;
    if (index == currentIndex && _mainTabIndex(widget.location) == index) {
      return;
    }
    _runNavigationAnimation(
      incomingFromRight: index > currentIndex,
      navigate: () =>
          widget.navigationShell.goBranch(index, initialLocation: true),
    );
  }

  void _navigateBack() {
    final parent = _parentLocation(widget.location);
    if (parent == null) return;
    _runNavigationAnimation(
      incomingFromRight: false,
      navigate: () => context.go(parent),
    );
  }

  void _runNavigationAnimation({
    required bool incomingFromRight,
    required VoidCallback navigate,
  }) {
    final performance = PerformanceScope.settingsOf(context);
    if (!performance.animationsEnabled) {
      navigate();
      _slideController.value = 1;
      return;
    }
    setState(() {
      _slideBegin = Offset(incomingFromRight ? 1 : -1, 0);
    });
    _slideController.value = 0;
    navigate();
    _slideController.forward(from: 0);
  }
}

int? _mainTabIndex(String location) {
  return switch (location) {
    '/' => 0,
    '/trips' => 1,
    '/chat' => 2,
    '/profile' => 3,
    _ => null,
  };
}

String? _parentLocation(String location) {
  if (location == '/notifications' || location.startsWith('/tools/')) {
    return '/';
  }
  if (location == '/trips/new') return '/trips';
  if (location.startsWith('/trips/')) {
    final segments = location
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.length >= 3) return '/trips/${segments[1]}';
    return '/trips';
  }
  if (location.startsWith('/chat/')) return '/chat';
  if (location == '/profile/settings/linked-accounts') {
    return '/profile/settings';
  }
  if (location == '/profile/performance' || location == '/profile/archived') {
    return '/profile/settings';
  }
  if (location == '/profile/settings') return '/profile';
  return null;
}

class _MainPageHeader extends StatelessWidget {
  const _MainPageHeader({required this.title, this.action});

  static const height = 40.0;
  static const verticalPadding = 8.0;

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final pageColor = Theme.of(context).scaffoldBackgroundColor;
    return Material(
      color: pageColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            _responsiveHorizontalPadding(context),
            verticalPadding,
            _responsiveHorizontalPadding(context),
            verticalPadding,
          ),
          color: pageColor,
          child: SizedBox(
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  left: 92,
                  right: 92,
                  child: Center(
                    child: Text(
                      appText(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  Align(alignment: Alignment.centerRight, child: action!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
