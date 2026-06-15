part of travel_agent_app;

const _tripsColumnsPrefKey = 'travel_agent.layout.trips_columns';

enum _TripsTab { upcoming, past }

enum _TripSort {
  dateAscending('Soonest first'),
  dateDescending('Latest first'),
  spendingDescending('Highest spending');

  const _TripSort(this.label);

  final String label;
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({
    required this.trips,
    required this.memories,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    required this.onDeleteTrip,
    this.favoriteTripIds = const [],
    this.onToggleFavoriteTrip,
    this.onRateMemory,
    super.key,
  });

  final List<Trip> trips;
  final List<TripMemory> memories;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;
  final ValueChanged<Trip> onDeleteTrip;
  final List<String> favoriteTripIds;
  final Future<void> Function(Trip)? onToggleFavoriteTrip;
  final Future<void> Function(TripMemory memory, int rating, String feedback)?
  onRateMemory;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _TripsTab _selectedTab = _TripsTab.upcoming;
  _TripSort _sort = _TripSort.dateAscending;
  int? _travelerFilter;
  bool _filtersExpanded = false;
  int _columns = 1;
  final Map<String, bool> _pendingFavoriteTripStates = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadColumns());
  }

  Future<void> _loadColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_tripsColumnsPrefKey);
    if (!mounted || stored == null) return;
    setState(() => _columns = stored == 2 ? 2 : 1);
  }

  void _setColumns(int value) {
    if (_columns == value) return;
    setState(() => _columns = value);
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt(_tripsColumnsPrefKey, value),
      ),
    );
  }

  List<Trip> get _tabTrips {
    final trips = widget.trips
        .where((trip) {
          return switch (_selectedTab) {
            _TripsTab.upcoming => trip.status != TripStatus.past,
            _TripsTab.past => trip.status == TripStatus.past,
          };
        })
        .where(_matchesTripFilters)
        .toList();
    trips.sort(_compareTrips);
    return trips;
  }

  List<TripMemory> get _visibleMemories {
    if (_selectedTab != _TripsTab.past || _travelerFilter != null) {
      return const [];
    }
    final query = _searchController.text.trim().toLowerCase();
    final memories = widget.memories.where((memory) {
      if (query.isEmpty) return true;
      return memory.title.toLowerCase().contains(query) ||
          memory.summary.toLowerCase().contains(query);
    }).toList();
    memories.sort((a, b) {
      final comparison = _dateValue(
        a.startDate,
      ).compareTo(_dateValue(b.startDate));
      return switch (_sort) {
        _TripSort.dateAscending => comparison,
        _TripSort.dateDescending => -comparison,
        _TripSort.spendingDescending => b.actualSpend.compareTo(a.actualSpend),
      };
    });
    return memories;
  }

  List<int> get _travelerCounts {
    final values = widget.trips
        .map((trip) => trip.numOfTravelers.clamp(1, 99).toInt())
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_travelerFilter != null) count++;
    if (_sort != _TripSort.dateAscending) count++;
    return count;
  }

  int get _upcomingCount =>
      widget.trips.where((trip) => trip.status != TripStatus.past).length;

  int get _pastCount =>
      widget.trips.where((trip) => trip.status == TripStatus.past).length +
      widget.memories.length;

  @override
  void didUpdateWidget(covariant TripsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pendingFavoriteTripStates.removeWhere((id, desiredState) {
      return widget.favoriteTripIds.contains(id) == desiredState;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesTripFilters(Trip trip) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !trip.destination.toLowerCase().contains(query) &&
        !trip.title.toLowerCase().contains(query)) {
      return false;
    }
    return _travelerFilter == null || trip.numOfTravelers == _travelerFilter;
  }

  int _compareTrips(Trip a, Trip b) {
    return switch (_sort) {
      _TripSort.dateAscending => _dateValue(
        a.startDate,
      ).compareTo(_dateValue(b.startDate)),
      _TripSort.dateDescending => _dateValue(
        b.startDate,
      ).compareTo(_dateValue(a.startDate)),
      _TripSort.spendingDescending => b.spent.compareTo(a.spent),
    };
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _travelerFilter = null;
      _sort = _TripSort.dateAscending;
    });
  }

  bool _isFavoriteTrip(Trip trip) {
    return _pendingFavoriteTripStates[trip.id] ??
        widget.favoriteTripIds.contains(trip.id);
  }

  Future<void> _toggleFavoriteTrip(Trip trip) async {
    final callback = widget.onToggleFavoriteTrip;
    if (callback == null) return;
    final desiredState = !_isFavoriteTrip(trip);
    setState(() => _pendingFavoriteTripStates[trip.id] = desiredState);
    try {
      await callback(trip);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingFavoriteTripStates.remove(trip.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(appText(context, 'Could not update favorite.')),
          ),
        );
    }
  }

  Future<bool> _confirmDelete(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFC64D57),
        ),
        title: Text('${appText(context, 'Delete')} ${trip.destination}?'),
        content: Text(
          appText(
            context,
            'This trip will be queued for deletion. You can still undo it from the confirmation message.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC64D57),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(appText(context, 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    widget.onDeleteTrip(trip);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final duration = settings.animationsEnabled
        ? settings.transitionDuration
        : Duration.zero;
    final trips = _tabTrips;
    final memories = _visibleMemories;
    final hasResults = trips.isNotEmpty || memories.isNotEmpty;

    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: _responsivePagePadding(context, top: 22, bottom: 112),
            children: [
              _TripsControlBar(
                selected: _selectedTab,
                upcomingCount: _upcomingCount,
                pastCount: _pastCount,
                activeFilterCount: _activeFilterCount,
                filtersExpanded: _filtersExpanded,
                onToggleFilters: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: LayoutColumnsToggle(
                    columns: _columns,
                    onChanged: _setColumns,
                  ),
                ),
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _filtersExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _TripFilters(
                          searchController: _searchController,
                          travelerCounts: _travelerCounts,
                          selectedTravelerCount: _travelerFilter,
                          selectedSort: _sort,
                          activeFilterCount: _activeFilterCount,
                          onSearchChanged: (_) => setState(() {}),
                          onTravelerCountSelected: (value) =>
                              setState(() => _travelerFilter = value),
                          onSortSelected: (value) =>
                              setState(() => _sort = value),
                          onClear: _clearFilters,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: hasResults
                    ? LayoutBuilder(
                        key: ValueKey(
                          '${_selectedTab.name}-${_travelerFilter ?? 'all'}-${_sort.name}-${_searchController.text}-$_columns',
                        ),
                        builder: (context, constraints) {
                          const spacing = 16.0;
                          final effectiveColumns = _columns == 2 ? 2 : 1;
                          final cellWidth = effectiveColumns == 2
                              ? (constraints.maxWidth - spacing) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: 16,
                            children: [
                              for (final trip in trips)
                                SizedBox(
                                  width: cellWidth,
                                  child: trip.isOwner
                                      ? _SwipeToDeleteTrip(
                                          trip: trip,
                                          confirmDelete: () =>
                                              _confirmDelete(trip),
                                          child: TripListCard(
                                            trip: trip,
                                            onTap: () =>
                                                widget.onOpenTrip(trip),
                                            onStart: () =>
                                                widget.onStartTrip(trip),
                                            favorite: _isFavoriteTrip(trip),
                                            onToggleFavorite:
                                                widget.onToggleFavoriteTrip ==
                                                        null ||
                                                    effectiveColumns == 2
                                                ? null
                                                : () => unawaited(
                                                    _toggleFavoriteTrip(trip),
                                                  ),
                                          ),
                                        )
                                      : TripListCard(
                                          trip: trip,
                                          onTap: () => widget.onOpenTrip(trip),
                                          onStart: trip.canEdit
                                              ? () => widget.onStartTrip(trip)
                                              : null,
                                          canDelete: false,
                                          favorite: _isFavoriteTrip(trip),
                                          onToggleFavorite:
                                              widget.onToggleFavoriteTrip ==
                                                      null ||
                                                  effectiveColumns == 2
                                              ? null
                                              : () => unawaited(
                                                  _toggleFavoriteTrip(trip),
                                                ),
                                        ),
                                ),
                              if (memories.isNotEmpty) ...[
                                const SizedBox(
                                  width: double.infinity,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: LabelText('Trip memories'),
                                    ),
                                  ),
                                ),
                                for (final memory in memories)
                                  SizedBox(
                                    width: cellWidth,
                                    child: _TripMemoryCard(
                                      memory: memory,
                                      onRate: widget.onRateMemory == null
                                          ? null
                                          : () => _rateMemory(memory),
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      )
                    : _TripsEmptyState(
                        key: ValueKey(
                          'empty-${_selectedTab.name}-$_activeFilterCount',
                        ),
                        tab: _selectedTab,
                        hasFilters: _activeFilterCount > 0,
                        onClearFilters: _clearFilters,
                        onCreate: widget.onCreate,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rateMemory(TripMemory memory) async {
    var rating = memory.rating ?? 5;
    final feedback = TextEditingController(text: memory.feedback);
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${appText(context, 'Rate')} ${memory.destination}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(
                    context,
                    'How well did this trip match your preferences?',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        onPressed: () => setDialogState(() => rating = star),
                        icon: Icon(
                          star <= rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFF3977A8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feedback,
                  maxLines: 3,
                  maxLength: 400,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Optional feedback'),
                    hintText: appText(
                      context,
                      'What should future recommendations change?',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appText(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((rating, feedback.text)),
              child: Text(appText(context, 'Save rating')),
            ),
          ],
        ),
      ),
    );
    feedback.dispose();
    if (result == null || widget.onRateMemory == null) return;
    await widget.onRateMemory!(memory, result.$1, result.$2);
  }
}

class _TripsControlBar extends StatelessWidget {
  const _TripsControlBar({
    required this.selected,
    required this.upcomingCount,
    required this.pastCount,
    required this.activeFilterCount,
    required this.filtersExpanded,
    required this.onToggleFilters,
    required this.onSelected,
  });

  final _TripsTab selected;
  final int upcomingCount;
  final int pastCount;
  final int activeFilterCount;
  final bool filtersExpanded;
  final VoidCallback onToggleFilters;
  final ValueChanged<_TripsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = PerformanceScope.maybeSettingsOf(context);
    return Material(
      key: const ValueKey('trip-control-bar'),
      color: scheme.surface,
      elevation: settings.heavyVisualEffects ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: _TripsControlButton(
                  key: const ValueKey('trip-filter-button'),
                  label: 'FILTER',
                  icon: filtersExpanded
                      ? Icons.tune_rounded
                      : Icons.filter_list_rounded,
                  count: activeFilterCount,
                  selected: filtersExpanded,
                  onTap: onToggleFilters,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final tab in _TripsTab.values)
                    Expanded(
                      child: _TripsControlButton(
                        key: ValueKey(
                          'trip-tab-${tab == _TripsTab.upcoming ? 'upcoming' : 'past'}',
                        ),
                        label: tab == _TripsTab.upcoming ? 'UPCOMING' : 'PAST',
                        count: tab == _TripsTab.upcoming
                            ? upcomingCount
                            : pastCount,
                        selected: selected == tab,
                        onTap: () => onSelected(tab),
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

class _TripsControlButton extends StatelessWidget {
  const _TripsControlButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: settings.animationsEnabled
                ? settings.transitionDuration
                : Duration.zero,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected && settings.heavyVisualEffects
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .45,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: .12)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripFilters extends StatelessWidget {
  const _TripFilters({
    required this.searchController,
    required this.travelerCounts,
    required this.selectedTravelerCount,
    required this.selectedSort,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onTravelerCountSelected,
    required this.onSortSelected,
    required this.onClear,
  });

  final TextEditingController searchController;
  final List<int> travelerCounts;
  final int? selectedTravelerCount;
  final _TripSort selectedSort;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onTravelerCountSelected;
  final ValueChanged<_TripSort> onSortSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('trip-filter-panel'),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final search = TextField(
                  key: const ValueKey('trip-search-field'),
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Search trips'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                );
                final sort = DropdownButtonFormField<_TripSort>(
                  key: const ValueKey('trip-sort-dropdown'),
                  initialValue: selectedSort,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Sort by'),
                    prefixIcon: const Icon(Icons.sort_rounded),
                    isDense: true,
                  ),
                  items: [
                    for (final option in _TripSort.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(appText(context, option.label)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortSelected(value);
                  },
                );
                if (narrow) {
                  return Column(
                    children: [search, const SizedBox(height: 12), sort],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: search),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: sort),
                  ],
                );
              },
            ),
            if (travelerCounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                appText(context, 'TRAVELERS'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(appText(context, 'All')),
                    selected: selectedTravelerCount == null,
                    onSelected: (_) => onTravelerCountSelected(null),
                  ),
                  for (final count in travelerCounts)
                    ChoiceChip(
                      label: Text(appText(context, _travelerCountLabel(count))),
                      selected: selectedTravelerCount == count,
                      onSelected: (_) => onTravelerCountSelected(count),
                    ),
                ],
              ),
            ],
            if (activeFilterCount > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(appText(context, 'Clear filters')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeToDeleteTrip extends StatelessWidget {
  const _SwipeToDeleteTrip({
    required this.trip,
    required this.confirmDelete,
    required this.child,
  });

  final Trip trip;
  final Future<bool> Function() confirmDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('trip-${trip.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) => confirmDelete(),
      background: _TripDeleteBackground(
        tripId: trip.id,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _TripDeleteBackground(
        tripId: trip.id,
        alignment: Alignment.centerRight,
      ),
      child: child,
    );
  }
}

class _TripDeleteBackground extends StatelessWidget {
  const _TripDeleteBackground({required this.tripId, required this.alignment});

  final String tripId;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final alignLeft = alignment == Alignment.centerLeft;
    return Container(
      key: ValueKey(
        'trip-delete-background-$tripId-${alignLeft ? 'left' : 'right'}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignLeft) ...[
            const Text(
              'DELETE TRIP',
              style: TextStyle(
                color: Color(0xFF9F3340),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(width: 10),
          ],
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFFFC7CD),
            child: Icon(Icons.delete_rounded, color: Color(0xFF9F3340)),
          ),
          if (alignLeft) ...[
            const SizedBox(width: 10),
            const Text(
              'DELETE TRIP',
              style: TextStyle(
                color: Color(0xFF9F3340),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripsEmptyState extends StatelessWidget {
  const _TripsEmptyState({
    required this.tab,
    required this.hasFilters,
    required this.onClearFilters,
    required this.onCreate,
    super.key,
  });

  final _TripsTab tab;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: tab == _TripsTab.upcoming
                ? Icons.travel_explore_rounded
                : Icons.auto_stories_rounded,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            appText(
              context,
              hasFilters
                  ? 'No matching trips'
                  : tab == _TripsTab.upcoming
                  ? 'No trips yet'
                  : 'No past trips yet',
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appText(
              context,
              hasFilters
                  ? 'Try clearing a filter or searching for another destination.'
                  : tab == _TripsTab.upcoming
                  ? 'Create a trip to see it here.'
                  : 'Completed trips and travel memories will appear here.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(appText(context, 'Clear filters')),
            )
          else if (tab == _TripsTab.upcoming)
            PrimaryButton(
              label: 'Create trip',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
        ],
      ),
    );
  }
}

class _TripMemoryCard extends StatelessWidget {
  const _TripMemoryCard({required this.memory, this.onRate});

  final TripMemory memory;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final image = memory.imageUrls.isEmpty
        ? destinations.first.image
        : memory.imageUrls.first;
    final dateLabel = memory.startDate == memory.endDate
        ? memory.startDate
        : '${memory.startDate} to ${memory.endDate}';
    final missedLabel = memory.missedStops.isEmpty
        ? 'No missed stops logged'
        : memory.missedStops.join(' / ');

    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              image,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              filterQuality: PerformanceScope.maybeSettingsOf(
                context,
              ).filterQuality,
              errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: _secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        memory.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memory.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallPill(
                      label:
                          '${_displayMoney(context, memory.actualSpend, memory.currency)} remembered',
                    ),
                    SmallPill(label: missedLabel),
                    for (final place in memory.favoritePlaces.take(2))
                      SmallPill(label: place),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (memory.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF4A340),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${memory.rating}/5',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (onRate != null)
                      Flexible(
                        child: OutlinedButton.icon(
                          onPressed: onRate,
                          icon: const Icon(
                            Icons.rate_review_outlined,
                            size: 18,
                          ),
                          label: Text(
                            memory.rating == null
                                ? 'Rate this trip'
                                : 'Update rating',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
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

DateTime _dateValue(String value) =>
    DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
