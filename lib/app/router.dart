part of travel_agent_app;

class AppRouter {
  const AppRouter._();

  static GoRouter _createTravelAgentRouter({
    required _TravelAgentAppState appState,
    required Listenable refreshListenable,
  }) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        final isOnboarding = state.uri.path == '/onboarding';
        if (appState._showOnboarding && !isOnboarding) return '/onboarding';
        if (!appState._showOnboarding && isOnboarding) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => appState._buildOnboardingScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _TravelRouteFrame(
              appState: appState,
              navigationShell: navigationShell,
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
}

class _TravelRouteFrame extends StatelessWidget {
  const _TravelRouteFrame({
    required this.appState,
    required this.navigationShell,
  });

  final _TravelAgentAppState appState;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.settingsOf(context);
    final location = GoRouterState.of(context).uri.path;

    return Stack(
      children: [
        appState._performanceBoundary(navigationShell, performance),
        if (_showsBottomNav(location))
          _BottomNav(
            tab: _tabForIndex,
            onSelect: (tab) => _select(context, tab),
          ),
      ],
    );
  }

  bool _showsBottomNav(String location) {
    if (location == '/trips/new' || location == '/profile/performance') {
      return false;
    }
    if (location.startsWith('/chat/') ||
        (location == '/chat' && appState._isChatRoomOpen)) {
      return false;
    }
    return true;
  }

  _NavTab get _tabForIndex {
    return switch (navigationShell.currentIndex) {
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
    navigationShell.goBranch(index, initialLocation: true);
  }
}
