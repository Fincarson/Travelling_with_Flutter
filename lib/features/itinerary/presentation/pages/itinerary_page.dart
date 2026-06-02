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

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  @override
  void didUpdateWidget(covariant _EditableTripDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip.id != oldWidget.trip.id || widget.trip != oldWidget.trip) {
      _trip = widget.trip;
    }
  }

  void _save(Trip trip) {
    setState(() => _trip = trip);
    widget.onUpdateTrip(trip);
  }

  @override
  Widget build(BuildContext context) {
    final performance = PerformanceScope.settingsOf(context);
    final tabs = [
      TripOverviewTab(trip: _trip),
      ScheduleTab(trip: _trip, onSave: _save),
      BudgetTab(trip: _trip, onSave: _save),
      TripMapTab(trip: _trip, onOpenMap: widget.onOpenMap),
      ChecklistTab(trip: _trip, onSave: _save),
      BookingTab(trip: _trip, onSave: _save),
      TripChatTab(
        trip: _trip,
        onOpenChat: widget.onOpenChat,
        initialPrompt: widget.initialAiPrompt,
      ),
    ];

    return DefaultTabController(
      length: 7,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
      child: ScreenScaffold(
        child: Column(
          children: [
            Padding(
              padding: _responsivePagePadding(context, top: 18, bottom: 10),
              child: TopBar(title: _trip.destination, onBack: widget.onBack),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).width < 340 ? 150 : 190,
              child: HeroTripCard(trip: _trip),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _primary,
                unselectedLabelColor: _secondary,
                indicatorColor: _accent,
                tabs: [
                  Tab(text: appText(context, 'Overview')),
                  Tab(text: appText(context, 'Schedule')),
                  Tab(text: appText(context, 'Budget')),
                  Tab(text: appText(context, 'Map')),
                  Tab(text: appText(context, 'Checklist')),
                  Tab(text: appText(context, 'Booking')),
                  Tab(text: appText(context, 'Chat')),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: performance.cachePages
                    ? tabs.map((tab) => KeepAlivePage(child: tab)).toList()
                    : tabs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
