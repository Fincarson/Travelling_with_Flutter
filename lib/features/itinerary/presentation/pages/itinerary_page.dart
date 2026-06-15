part of travel_agent_app;

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenBudget,
    required this.onOpenPacking,
    required this.onOpenSettings,
    required this.onUpdateTrip,
    required this.accountId,
    required this.repository,
    required this.onLeftTrip,
    this.initialTabIndex = 0,
    this.initialAiPrompt,
    super.key,
  });
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenSettings;
  final ValueChanged<Trip> onUpdateTrip;
  final String accountId;
  final TravelDataRepository repository;
  final VoidCallback onLeftTrip;
  final int initialTabIndex;
  final String? initialAiPrompt;

  @override
  Widget build(BuildContext context) {
    return _EditableTripDetailScreen(
      trip: trip,
      onBack: onBack,
      onOpenChat: onOpenChat,
      onOpenSettings: onOpenSettings,
      onUpdateTrip: onUpdateTrip,
      accountId: accountId,
      repository: repository,
      onLeftTrip: onLeftTrip,
      initialTabIndex: initialTabIndex,
      initialAiPrompt: initialAiPrompt,
    );
  }
}

class _EditableTripDetailScreen extends StatefulWidget {
  const _EditableTripDetailScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenSettings,
    required this.onUpdateTrip,
    required this.accountId,
    required this.repository,
    required this.onLeftTrip,
    required this.initialTabIndex,
    this.initialAiPrompt,
  });

  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenSettings;
  final ValueChanged<Trip> onUpdateTrip;
  final String accountId;
  final TravelDataRepository repository;
  final VoidCallback onLeftTrip;
  final int initialTabIndex;
  final String? initialAiPrompt;

  @override
  State<_EditableTripDetailScreen> createState() =>
      _EditableTripDetailScreenState();
}

class _EditableTripDetailScreenState extends State<_EditableTripDetailScreen> {
  late Trip _trip;
  late int _selectedSectionIndex;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _selectedSectionIndex = _clampedSectionIndex(widget.initialTabIndex);
  }

  @override
  void didUpdateWidget(covariant _EditableTripDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip.id != oldWidget.trip.id || widget.trip != oldWidget.trip) {
      _trip = widget.trip;
    }
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      _selectedSectionIndex = _clampedSectionIndex(widget.initialTabIndex);
    }
  }

  void _save(Trip trip) {
    setState(() => _trip = trip);
    widget.onUpdateTrip(trip);
  }

  int _clampedSectionIndex(int index) => index.clamp(0, 7);

  @override
  Widget build(BuildContext context) {
    final sections = _tripDetailSections();
    final selectedIndex = _selectedSectionIndex.clamp(0, sections.length - 1);

    return ScreenScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _TripDetailSliverAppBar(
            trip: _trip,
            sections: sections,
            selectedIndex: selectedIndex,
            forceElevated: innerBoxIsScrolled,
            onBack: widget.onBack,
            onOpenSettings: widget.onOpenSettings,
            onSelect: (index) => setState(() => _selectedSectionIndex = index),
          ),
        ],
        body: Column(
          children: [
            if (!_trip.canEdit) const _TripReadOnlyBanner(),
            Expanded(child: sections[selectedIndex].child),
          ],
        ),
      ),
    );
  }

  List<_TripDetailSection> _tripDetailSections() {
    return [
      _TripDetailSection(
        label: 'Overview',
        icon: Icons.dashboard_rounded,
        child: TripOverviewTab(
          trip: _trip,
          onSave: _save,
          readOnly: !_trip.canEdit,
        ),
      ),
      _TripDetailSection(
        label: 'Schedule',
        icon: Icons.route_rounded,
        child: ScheduleTab(
          trip: _trip,
          onSave: _save,
          readOnly: !_trip.canEdit,
        ),
      ),
      _TripDetailSection(
        label: 'Budget',
        icon: Icons.account_balance_wallet_rounded,
        child: BudgetTab(trip: _trip, onSave: _save, readOnly: !_trip.canEdit),
      ),
      _TripDetailSection(
        label: 'Map',
        icon: Icons.map_rounded,
        child: TripMapTab(trip: _trip),
      ),
      _TripDetailSection(
        label: 'Checklist',
        icon: Icons.checklist_rounded,
        child: ChecklistTab(
          trip: _trip,
          onSave: _save,
          readOnly: !_trip.canEdit,
        ),
      ),
      _TripDetailSection(
        label: 'Booking',
        icon: Icons.confirmation_number_rounded,
        child: BookingTab(trip: _trip, onSave: _save, readOnly: !_trip.canEdit),
      ),
      _TripDetailSection(
        label: 'Members',
        icon: Icons.groups_rounded,
        child: TripMembersTab(
          trip: _trip,
          accountId: widget.accountId,
          repository: widget.repository,
          onLeftTrip: widget.onLeftTrip,
        ),
      ),
      _TripDetailSection(
        label: 'Chat',
        icon: Icons.chat_bubble_rounded,
        child: TripChatTab(
          trip: _trip,
          onOpenChat: widget.onOpenChat,
          initialPrompt: widget.initialAiPrompt,
        ),
      ),
    ];
  }
}

class _TripReadOnlyBanner extends StatelessWidget {
  const _TripReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _responsiveHorizontalPadding(context),
          vertical: 9,
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appText(
                  context,
                  'View only: the trip owner manages this plan.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripDetailSection {
  const _TripDetailSection({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;
}

class _TripDetailSliverAppBar extends StatelessWidget {
  const _TripDetailSliverAppBar({
    required this.trip,
    required this.sections,
    required this.selectedIndex,
    required this.forceElevated,
    required this.onBack,
    required this.onOpenSettings,
    required this.onSelect,
  });

  final Trip trip;
  final List<_TripDetailSection> sections;
  final int selectedIndex;
  final bool forceElevated;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bannerHeight = width < 340 ? 148.0 : (width < 700 ? 188.0 : 216.0);
    final expandedHeight =
        kToolbarHeight + bannerHeight + _TripSectionTabBar.height + 28;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      forceElevated: forceElevated,
      expandedHeight: expandedHeight,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _primary,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          tooltip: appText(context, 'Back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: _primary,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .88),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: appText(context, 'Trip settings'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
            color: _primary,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .88),
            ),
          ),
        ),
      ],
      flexibleSpace: _TripDetailFlexibleBanner(trip: trip),
      bottom: _TripSectionTabBar(
        sections: sections,
        selectedIndex: selectedIndex,
        onSelect: onSelect,
      ),
    );
  }
}

class _TripDetailFlexibleBanner extends StatelessWidget {
  const _TripDetailFlexibleBanner({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final image = trip.images.isEmpty
        ? destinations.first.image
        : trip.images.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        const bannerBottom = _TripSectionTabBar.height;
        final contentHeight = math.max(
          0.0,
          constraints.maxHeight - bannerBottom,
        );
        final contentOpacity = ((contentHeight - 126) / 120).clamp(0.0, 1.0);
        final collapsedOpacity = (1.0 - ((contentHeight - 72) / 72)).clamp(
          0.0,
          1.0,
        );
        final imageOpacity = ((contentHeight - 72) / 120).clamp(0.0, 1.0);
        final background = Theme.of(context).scaffoldBackgroundColor;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              bottom: bannerBottom,
              child: ColoredBox(color: background),
            ),
            Positioned.fill(
              bottom: bannerBottom,
              child: Opacity(
                opacity: imageOpacity,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  filterQuality: PerformanceScope.maybeSettingsOf(
                    context,
                  ).filterQuality,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: _primary),
                ),
              ),
            ),
            Positioned.fill(
              bottom: bannerBottom,
              child: Opacity(
                opacity: imageOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _primary.withValues(alpha: .86),
                        _primary.withValues(alpha: .45),
                        _primary.withValues(alpha: .9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: _responsiveHorizontalPadding(context),
              right: _responsiveHorizontalPadding(context),
              bottom: bannerBottom + 18,
              child: Opacity(
                opacity: contentOpacity,
                child: IgnorePointer(
                  ignoring: contentOpacity == 0,
                  child: _TripHeaderBannerContent(trip: trip),
                ),
              ),
            ),
            Positioned(
              left: kToolbarHeight + 12,
              right: 16,
              top: MediaQuery.paddingOf(context).top,
              height: kToolbarHeight,
              child: Opacity(
                opacity: collapsedOpacity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    trip.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TripHeaderBannerContent extends StatelessWidget {
  const _TripHeaderBannerContent({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trip.destination,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.sizeOf(context).width < 340 ? 24 : 30,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        _TripDateTravelerLine(
          dates: trip.startDate == trip.endDate
              ? trip.startDate
              : '${trip.startDate} ~ ${trip.endDate}',
          travelerCount: trip.numOfTravelers,
          dateStyle: TextStyle(
            color: Colors.white.withValues(alpha: .82),
            fontWeight: FontWeight.w800,
          ),
          travelerForeground: Colors.white,
          travelerBackground: Colors.white.withValues(alpha: .14),
        ),
      ],
    );
  }
}

class _TripSectionTabBar extends StatefulWidget implements PreferredSizeWidget {
  const _TripSectionTabBar({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const height = 76.0;

  final List<_TripDetailSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<_TripSectionTabBar> createState() => _TripSectionTabBarState();
}

class _TripSectionTabBarState extends State<_TripSectionTabBar> {
  final _controller = ScrollController();
  var _canScrollLeft = false;
  var _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshScrollHints);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScrollHints());
  }

  @override
  void didUpdateWidget(covariant _TripSectionTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScrollHints());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refreshScrollHints)
      ..dispose();
    super.dispose();
  }

  void _refreshScrollHints() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final nextCanScrollLeft = position.pixels > 1;
    final nextCanScrollRight = position.maxScrollExtent - position.pixels > 1;
    if (nextCanScrollLeft == _canScrollLeft &&
        nextCanScrollRight == _canScrollRight) {
      return;
    }
    setState(() {
      _canScrollLeft = nextCanScrollLeft;
      _canScrollRight = nextCanScrollRight;
    });
  }

  void _nudgeTabs(double direction) {
    if (!_controller.hasClients) return;
    final nextOffset = (_controller.offset + (direction * 168)).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      nextOffset,
      duration: PerformanceScope.maybeSettingsOf(context).transitionDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = _responsiveHorizontalPadding(context);
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Material(
      color: background,
      elevation: 8,
      shadowColor: _primary.withValues(alpha: .08),
      child: SizedBox(
        height: _TripSectionTabBar.height,
        child: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _refreshScrollHints(),
                );
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  10,
                  horizontalPadding,
                  12,
                ),
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < widget.sections.length;
                      index++
                    ) ...[
                      _TripSectionTab(
                        section: widget.sections[index],
                        selected: widget.selectedIndex == index,
                        onTap: () => widget.onSelect(index),
                      ),
                      if (index != widget.sections.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (_canScrollLeft)
              _TripTabScrollHint(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_left_rounded,
                background: background,
                onTap: () => _nudgeTabs(-1),
              ),
            if (_canScrollRight)
              _TripTabScrollHint(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_right_rounded,
                background: background,
                onTap: () => _nudgeTabs(1),
              ),
          ],
        ),
      ),
    );
  }
}

class _TripSectionTab extends StatelessWidget {
  const _TripSectionTab({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _TripDetailSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: appText(context, section.label),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 98, maxWidth: 126),
        child: Material(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? _primary : const Color(0xFFEFF3F6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: selected ? .14 : .06),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    section.icon,
                    color: selected ? Colors.white : _primary,
                    size: 21,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      appText(context, section.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : _secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
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

class _TripTabScrollHint extends StatelessWidget {
  const _TripTabScrollHint({
    required this.alignment,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 48,
          alignment: alignment,
          padding: EdgeInsets.only(left: isLeft ? 8 : 0, right: isLeft ? 0 : 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                background,
                background.withValues(alpha: .92),
                background.withValues(alpha: 0),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: .24),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, color: _primary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
