part of travel_agent_app;

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenBudget,
    required this.onOpenPacking,
    required this.onOpenMap,
    required this.onUpdateTrip,
    this.initialTabIndex = 0,
    this.initialAiPrompt,
    super.key,
  });
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;
  final int initialTabIndex;
  final String? initialAiPrompt;

  @override
  Widget build(BuildContext context) {
    return _EditableTripDetailScreen(
      trip: trip,
      onBack: onBack,
      onOpenChat: onOpenChat,
      onOpenMap: onOpenMap,
      onUpdateTrip: onUpdateTrip,
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
    required this.onOpenMap,
    required this.onUpdateTrip,
    required this.initialTabIndex,
    this.initialAiPrompt,
  });

  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;
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

  int _clampedSectionIndex(int index) => index.clamp(0, 6);

  @override
  Widget build(BuildContext context) {
    final sections = _tripDetailSections();
    final selectedIndex = _selectedSectionIndex.clamp(0, sections.length - 1);

    return ScreenScaffold(
      bottomPadding: 92,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _TripDetailSliverAppBar(
            trip: _trip,
            sections: sections,
            selectedIndex: selectedIndex,
            forceElevated: innerBoxIsScrolled,
            onBack: widget.onBack,
            onSelect: (index) => setState(() => _selectedSectionIndex = index),
          ),
        ],
        body: sections[selectedIndex].child,
      ),
    );
  }

  List<_TripDetailSection> _tripDetailSections() {
    return [
      _TripDetailSection(
        label: 'Overview',
        icon: Icons.dashboard_rounded,
        child: TripOverviewTab(trip: _trip, onSave: _save),
      ),
      _TripDetailSection(
        label: 'Schedule',
        icon: Icons.route_rounded,
        child: ScheduleTab(trip: _trip, onSave: _save),
      ),
      _TripDetailSection(
        label: 'Budget',
        icon: Icons.account_balance_wallet_rounded,
        child: BudgetTab(trip: _trip, onSave: _save),
      ),
      _TripDetailSection(
        label: 'Map',
        icon: Icons.map_rounded,
        child: TripMapTab(trip: _trip, onOpenMap: widget.onOpenMap),
      ),
      _TripDetailSection(
        label: 'Checklist',
        icon: Icons.checklist_rounded,
        child: ChecklistTab(trip: _trip, onSave: _save),
      ),
      _TripDetailSection(
        label: 'Booking',
        icon: Icons.confirmation_number_rounded,
        child: BookingTab(trip: _trip, onSave: _save),
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
    required this.onSelect,
  });

  final Trip trip;
  final List<_TripDetailSection> sections;
  final int selectedIndex;
  final bool forceElevated;
  final VoidCallback onBack;
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
      backgroundColor: _primary,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          tooltip: appText(context, 'Back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
        ),
      ),
      title: Text(
        trip.destination,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const bannerBottom = _TripSectionTabBar.height;
        final contentHeight = math.max(
          0.0,
          constraints.maxHeight - bannerBottom,
        );
        final contentOpacity = ((contentHeight - 126) / 120).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              bottom: bannerBottom,
              child: Image.network(
                trip.images.first,
                fit: BoxFit.cover,
                filterQuality: PerformanceScope.maybeSettingsOf(
                  context,
                ).filterQuality,
                errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
              ),
            ),
            Positioned.fill(
              bottom: bannerBottom,
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
        Row(
          children: [
            Expanded(
              child: Text(
                '${trip.startDate} ~ ${trip.endDate}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                '67 PEOPLE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
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
