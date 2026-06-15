part of travel_agent_app;

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenBudget,
    required this.onOpenPacking,
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
  final ValueChanged<Trip> onUpdateTrip;
  final int initialTabIndex;
  final String? initialAiPrompt;

  @override
  Widget build(BuildContext context) {
    return _EditableTripDetailScreen(
      trip: trip,
      onBack: onBack,
      onOpenChat: onOpenChat,
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
    required this.onUpdateTrip,
    required this.initialTabIndex,
    this.initialAiPrompt,
  });

  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
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
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: _responsivePagePadding(context, top: 18, bottom: 10),
                  child: TopBar(
                    title: _trip.destination,
                    onBack: widget.onBack,
                  ),
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).width < 340 ? 150 : 190,
                  child: HeroTripCard(trip: _trip),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _responsiveHorizontalPadding(context),
                  ),
                  child: _TripSectionButtonGrid(
                    sections: sections,
                    selectedIndex: selectedIndex,
                    onSelect: (index) =>
                        setState(() => _selectedSectionIndex = index),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
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
        child: TripMapTab(trip: _trip),
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

class _TripSectionButtonGrid extends StatelessWidget {
  const _TripSectionButtonGrid({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const _buttonSpacing = 10.0;
  static const _minButtonWidth = 66.0;
  static const _maxButtonWidth = 92.0;

  final List<_TripDetailSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxButtonsPerRow = math.max(
          1,
          ((constraints.maxWidth + _buttonSpacing) /
                  (_minButtonWidth + _buttonSpacing))
              .floor(),
        );
        final buttonsInRow = math.min(sections.length, maxButtonsPerRow);
        final rawButtonWidth =
            (constraints.maxWidth -
                (_buttonSpacing * math.max(0, buttonsInRow - 1))) /
            buttonsInRow;
        final buttonWidth = rawButtonWidth
            .clamp(_minButtonWidth, _maxButtonWidth)
            .toDouble();

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: _buttonSpacing,
          runSpacing: 10,
          children: [
            for (var index = 0; index < sections.length; index++)
              SizedBox(
                width: buttonWidth,
                child: _TripSectionButton(
                  section: sections[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelect(index),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TripSectionButton extends StatelessWidget {
  const _TripSectionButton({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _primary : Colors.white,
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
                child: Icon(
                  section.icon,
                  color: selected ? Colors.white : _primary,
                  size: 25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                appText(context, section.label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _primary : _secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
