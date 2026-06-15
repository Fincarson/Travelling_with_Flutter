part of travel_agent_app;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.trips,
    required this.activeTrip,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    required this.onAskAi,
    required this.onOpenMap,
    required this.onOpenInfo,
    required this.onOpenTranslate,
    required this.onOpenNotifications,
    this.memories = const [],
    this.onToggleFavoritePlace,
    this.onAddPlaceToTrip,
    super.key,
  });
  final UserProfile user;
  final List<Trip> trips;
  final Trip? activeTrip;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;
  final ValueChanged<String> onAskAi;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenTranslate;
  final VoidCallback onOpenNotifications;
  final List<TripMemory> memories;
  final Future<void> Function(Destination)? onToggleFavoritePlace;
  final ValueChanged<Destination>? onAddPlaceToTrip;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _query = TextEditingController();
  List<Destination> _recommendations = const [];
  final Map<String, bool> _pendingFavoriteStates = {};
  var _recommendationsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pendingFavoriteStates.removeWhere((id, desiredState) {
      final persistedState = widget.user.favoritePlaces.any(
        (place) => place.id == id,
      );
      return persistedState == desiredState;
    });
    if (oldWidget.user.interests != widget.user.interests ||
        oldWidget.user.favoritePlaces != widget.user.favoritePlaces ||
        oldWidget.memories != widget.memories) {
      _loadRecommendations();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final fallback = _rankedDestinationFallback(widget.user);
    if (mounted) {
      setState(() {
        _recommendations = fallback;
        _recommendationsLoading = true;
      });
    }
    try {
      final names = await TravelAssistantService().recommendDestinationNames(
        user: widget.user,
        memories: widget.memories,
        candidates: destinations,
      );
      if (!mounted || names.isEmpty) return;
      final byName = {
        for (final destination in destinations) destination.name: destination,
      };
      final recommended = names
          .map((name) => byName[name])
          .whereType<Destination>()
          .toList(growable: false);
      if (recommended.isNotEmpty) {
        setState(() => _recommendations = recommended);
      }
    } catch (_) {
      // Curated recommendations remain visible when the AI service is offline.
    } finally {
      if (mounted) setState(() => _recommendationsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip =
        widget.activeTrip ?? (widget.trips.isEmpty ? null : widget.trips.first);
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 12, bottom: 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelText(appText(context, 'Welcome Back')),
                    Text(
                      '${widget.user.name.isEmpty ? 'Explorer' : widget.user.name}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IconButton.filled(
                        tooltip: appText(context, 'Notifications'),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: widget.onOpenNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ),
                    if (widget.user.notificationsEnabled)
                      const Positioned(right: 10, top: 10, child: Dot()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SearchBox(
            controller: _query,
            hint: "Ask AI: 'Best ramen in Kyoto?'",
            onSubmit: () {
              final query = _query.text.trim();
              if (query.isNotEmpty) widget.onAskAi(query);
            },
          ),
          const SizedBox(height: 10),
          AlertRail(trip: trip),
          const SizedBox(height: 28),
          if (trip == null) ...[
            _EmptyTripCard(onCreate: widget.onCreate),
          ] else ...[
            LabelText(
              appText(context, 'Current trip'),
            ), // TODO make responsive: show current/past/upcoming trip
            const SizedBox(height: 8),
            CurrentTripCard(
              trip: trip,
              onTap: () => widget.onOpenTrip(trip),
              onStart: trip.status == TripStatus.ongoing || !trip.canEdit
                  ? null
                  : () => widget.onStartTrip(trip),
            ),
            const SizedBox(height: 22),
            ResponsiveActionWrap(
              children: [
                QuickAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Info',
                  onTap: widget.onOpenInfo,
                ),
                QuickAction(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  onTap: widget.onOpenMap,
                ),
                QuickAction(
                  icon: Icons.translate_rounded,
                  label: 'Translate',
                  onTap: widget.onOpenTranslate,
                ),
                QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI',
                  onTap: () => widget.onAskAi(_dailyTripPrompt(trip)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Places picked for you',
            action: _recommendationsLoading ? 'Personalizing...' : 'Refresh',
            onTap: _recommendationsLoading ? null : _loadRecommendations,
          ),
          const SizedBox(height: 12),
          for (final destination in _recommendations) ...[
            _RecommendedPlaceCard(
              destination: destination,
              favorite: _isFavorite(destination),
              favoriteBusy: _pendingFavoriteStates.containsKey(
                _favoritePlaceId(destination.name),
              ),
              onFavorite: () => _toggleFavorite(destination),
              onDetails: () => _showDestinationDetails(destination),
              onAdd: () => widget.onAddPlaceToTrip?.call(destination),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  bool _isFavorite(Destination destination) {
    final id = _favoritePlaceId(destination.name);
    return _pendingFavoriteStates[id] ??
        widget.user.favoritePlaces.any((place) => place.id == id);
  }

  Future<void> _toggleFavorite(Destination destination) async {
    final callback = widget.onToggleFavoritePlace;
    if (callback == null) return;
    final id = _favoritePlaceId(destination.name);
    final desiredState = !_isFavorite(destination);
    setState(() => _pendingFavoriteStates[id] = desiredState);
    try {
      await callback(destination);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingFavoriteStates.remove(id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not update favorite place.')),
        );
    }
  }

  void _showDestinationDetails(Destination destination) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close place details',
      barrierColor: Colors.black.withValues(alpha: .42),
      transitionDuration: settings.animationsEnabled
          ? settings.transitionDuration
          : Duration.zero,
      pageBuilder: (dialogContext, _, __) => _DestinationDetailsPanel(
        destination: destination,
        favorite: _isFavorite(destination),
        onFavorite: () async {
          await _toggleFavorite(destination);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
        onAdd: () {
          Navigator.of(dialogContext).pop();
          widget.onAddPlaceToTrip?.call(destination);
        },
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}

List<Destination> _rankedDestinationFallback(UserProfile user) {
  final interests = user.interests
      .map((interest) => interest.toLowerCase())
      .toSet();
  final saved = user.favoritePlaces.map((place) => place.name).toSet();
  final ranked = [...destinations]
    ..sort((a, b) {
      int score(Destination destination) {
        final tagMatches = destination.tags
            .where((tag) => interests.contains(tag.toLowerCase()))
            .length;
        return tagMatches * 3 + (saved.contains(destination.name) ? 2 : 0);
      }

      return score(b).compareTo(score(a));
    });
  return ranked.take(5).toList(growable: false);
}

class _RecommendedPlaceCard extends StatelessWidget {
  const _RecommendedPlaceCard({
    required this.destination,
    required this.favorite,
    required this.favoriteBusy,
    required this.onFavorite,
    required this.onDetails,
    required this.onAdd,
  });

  final Destination destination;
  final bool favorite;
  final bool favoriteBusy;
  final VoidCallback onFavorite;
  final VoidCallback onDetails;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final image = ClipRRect(
            borderRadius: compact
                ? BorderRadius.zero
                : const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Image.network(
              destination.image,
              height: compact ? 170 : 210,
              width: compact ? double.infinity : 220,
              fit: BoxFit.cover,
              filterQuality: PerformanceScope.maybeSettingsOf(
                context,
              ).filterQuality,
              errorBuilder: (_, __, ___) => Container(
                color: scheme.surfaceContainer,
                child: Icon(Icons.landscape_rounded, color: scheme.primary),
              ),
            ),
          );
          final content = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destination.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                        'favorite-place-${_favoritePlaceId(destination.name)}',
                      ),
                      tooltip: favorite
                          ? 'Remove from favorites'
                          : 'Save place',
                      onPressed: favoriteBusy ? null : onFavorite,
                      icon: AnimatedSwitcher(
                        duration: PerformanceScope.maybeSettingsOf(
                          context,
                        ).transitionDuration,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(favorite),
                          color: favorite ? scheme.error : scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  destination.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: onDetails,
                      child: const Text('Details'),
                    ),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add to trip'),
                    ),
                  ],
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              image,
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _DestinationDetailsPanel extends StatelessWidget {
  const _DestinationDetailsPanel({
    required this.destination,
    required this.favorite,
    required this.onFavorite,
    required this.onAdd,
  });

  final Destination destination;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: screenHeight * .84,
          ),
          child: Material(
            color: scheme.surface,
            elevation: 20,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 2,
                        child: Image.network(
                          destination.image,
                          fit: BoxFit.cover,
                          filterQuality: PerformanceScope.maybeSettingsOf(
                            context,
                          ).filterQuality,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.landscape_rounded,
                              size: 56,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton.filledTonal(
                          tooltip: 'Close details',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          destination.description,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in destination.tags)
                              Chip(label: Text(tag)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onFavorite,
                              icon: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                              ),
                              label: Text(
                                favorite ? 'Favorited' : 'Save place',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: onAdd,
                              icon: const Icon(Icons.add_location_alt_rounded),
                              label: const Text('Add to a new trip'),
                            ),
                          ],
                        ),
                      ],
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

String _dailyTripPrompt(Trip trip) {
  if (trip.status != TripStatus.ongoing) {
    return 'Help me prepare to start my ${trip.destination} trip.';
  }
  final runtime = _tripRuntimePlan(trip);
  final next = runtime.nextItem;
  final base =
      'I am currently running my ${trip.destination} trip. Today is day ${runtime.currentDay} of ${runtime.totalDays}.';
  if (next == null) {
    return '$base Help me plan the rest of today based on my schedule, current time, and location if available.';
  }
  return '$base My next scheduled activity is "${next.activity}" at ${next.time}. Help me run today smoothly using current time and location if available.';
}

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.add_location_alt_rounded, size: 48),
          const SizedBox(height: 14),
          Text(
            appText(context, 'Start your trip'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            appText(context, 'Create a schedule to see your route here.'),
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Create schedule',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet({
    required this.notificationsEnabled,
    required this.trip,
    required this.upcomingTripCount,
    required this.onEnableNotifications,
    required this.onOpenTrip,
  });

  final bool notificationsEnabled;
  final Trip? trip;
  final int upcomingTripCount;
  final VoidCallback onEnableNotifications;
  final VoidCallback? onOpenTrip;

  @override
  Widget build(BuildContext context) {
    final updates = [
      ..._generalAgentFallbackUpdates(),
      if (trip != null) ..._dailyAgentUpdates(trip!),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const IconBadge(
                      icon: Icons.notifications_active_rounded,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LabelText('Notification center'),
                          const SizedBox(height: 3),
                          Text(
                            notificationsEnabled
                                ? 'Daily agent notifications are ready.'
                                : 'Notifications are off for this browser.',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
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
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallPill(
                      label: notificationsEnabled ? 'Enabled' : 'Needs setup',
                    ),
                    SmallPill(label: '$upcomingTripCount active/upcoming'),
                    if (trip != null) SmallPill(label: trip!.destination),
                  ],
                ),
                const SizedBox(height: 16),
                for (final update in updates.take(4)) ...[
                  _NotificationUpdateTile(update: update),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenTrip,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(appText(context, 'Open trip')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onEnableNotifications,
                        icon: Icon(
                          notificationsEnabled
                              ? Icons.sync_rounded
                              : Icons.notifications_active_rounded,
                          size: 18,
                        ),
                        label: Text(
                          appText(
                            context,
                            notificationsEnabled ? 'Refresh' : 'Enable',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationUpdateTile extends StatelessWidget {
  const _NotificationUpdateTile({required this.update});

  final _DailyAgentUpdate update;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconBadge(icon: update.icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, update.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(context, update.detail),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
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
    );
  }
}
