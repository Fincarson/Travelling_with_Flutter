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
    super.key,
  });
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;

  @override
  Widget build(BuildContext context) {
    return _EditableTripDetailScreen(
      trip: trip,
      onBack: onBack,
      onOpenChat: onOpenChat,
      onOpenMap: onOpenMap,
      onUpdateTrip: onUpdateTrip,
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
  });

  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;

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
      EditableScheduleTab(trip: _trip, onSave: _save),
      EditableBudgetTab(trip: _trip, onSave: _save),
      TripMapTab(trip: _trip, onOpenMap: widget.onOpenMap),
      EditableChecklistTab(trip: _trip, onSave: _save),
      EditableBookingTab(trip: _trip, onSave: _save),
      TripChatTab(trip: _trip, onOpenChat: widget.onOpenChat),
    ];

    return DefaultTabController(
      length: 7,
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

class TripOverviewTab extends StatelessWidget {
  const TripOverviewTab({required this.trip, super.key});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: trip.budget,
            actual: trip.spent,
            items: trip.items,
            bookings: trip.bookings,
          )
        : trip.budgetCategories;
    final actual = categories.fold<int>(
      0,
      (total, item) => total + item.actual,
    );

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        ResponsiveSplit(
          children: [
            StatCard(
              title: 'Dates',
              value: trip.startDate,
              detail: trip.endDate,
            ),
            StatCard(
              title: 'Budget',
              value: '${trip.currency} $actual',
              detail: 'of ${trip.currency} ${trip.budget}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Trip tags'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (trip.preferences.isEmpty
                            ? ['Culture', 'Food']
                            : trip.preferences)
                        .map((tag) => SmallPill(label: tag))
                        .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Bookings'),
        const SizedBox(height: 10),
        for (final booking in trip.bookings.take(2))
          BookingTile(booking: booking),
        const SizedBox(height: 12),
        const SectionHeader(title: 'First schedule stops'),
        const SizedBox(height: 10),
        for (final item in trip.items.take(3)) ScheduleTile(item: item),
      ],
    );
  }
}

class EditableScheduleTab extends StatelessWidget {
  const EditableScheduleTab({
    required this.trip,
    required this.onSave,
    super.key,
  });

  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addScheduleStop(BuildContext context) async {
    final activity = TextEditingController();
    final time = TextEditingController(text: '10:00 AM');
    final cost = TextEditingController(text: '0');
    var day = 1;
    try {
      final item = await showDialog<ScheduleItem>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(appText(context, 'Add schedule stop')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: activity,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Activity'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: time,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Time'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cost,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Cost'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StepperControl(
                    label: '${appText(context, 'Day')} $day',
                    onMinus: () =>
                        setDialogState(() => day = math.max(1, day - 1)),
                    onPlus: () => setDialogState(() => day += 1),
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
                onPressed: () => Navigator.of(context).pop(
                  ScheduleItem(
                    day,
                    time.text.trim().isEmpty ? '10:00 AM' : time.text.trim(),
                    activity.text.trim().isEmpty
                        ? 'New activity'
                        : activity.text.trim(),
                    Icons.place_rounded,
                    int.tryParse(cost.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
                  ),
                ),
                child: Text(appText(context, 'Add')),
              ),
            ],
          ),
        ),
      );
      if (item == null) return;
      onSave(trip.copyWith(items: [...trip.items, item]));
    } finally {
      activity.dispose();
      time.dispose();
      cost.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ScheduleItem>>{};
    for (final item in trip.items) {
      grouped.putIfAbsent(item.day, () => []).add(item);
    }

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        PrimaryButton(
          label: 'Add schedule stop',
          icon: Icons.add_rounded,
          onPressed: () => _addScheduleStop(context),
        ),
        const SizedBox(height: 16),
        for (final day in grouped.keys.toList()..sort()) ...[
          LabelText('${appText(context, 'Day')} $day'),
          const SizedBox(height: 10),
          for (final item in grouped[day]!)
            Dismissible(
              key: ValueKey('${item.day}-${item.time}-${item.activity}'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
              onDismissed: (_) => onSave(
                trip.copyWith(
                  items: trip.items
                      .where((candidate) => candidate != item)
                      .toList(),
                ),
              ),
              child: ScheduleTile(item: item),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class EditableBudgetTab extends StatelessWidget {
  const EditableBudgetTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: trip.budget,
            actual: trip.spent,
            items: trip.items,
            bookings: trip.bookings,
          )
        : trip.budgetCategories;
    final actual = categories.fold<int>(
      0,
      (total, item) => total + item.actual,
    );

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Budget'),
              const SizedBox(height: 8),
              Text(
                '${trip.currency} $actual of ${trip.currency} ${trip.budget}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: trip.budget == 0
                      ? 0
                      : (actual / trip.budget).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: _secondary.withValues(alpha: .16),
                  color: _secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BudgetCategoryEditor(
              category: category,
              currency: trip.currency,
              onChanged: (updated) {
                final next = categories
                    .map((item) => item.id == updated.id ? updated : item)
                    .toList();
                onSave(
                  trip.copyWith(
                    budgetCategories: next,
                    spent: next.fold<int>(
                      0,
                      (total, item) => total + item.actual,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TripMapTab extends StatelessWidget {
  const TripMapTab({required this.trip, required this.onOpenMap, super.key});
  final Trip trip;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Route map'),
              const SizedBox(height: 8),
              Text(
                appText(context, trip.formattedAddress ?? trip.destination),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Open map',
                icon: Icons.map_rounded,
                onPressed: onOpenMap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in trip.items.take(6)) ScheduleTile(item: item),
      ],
    );
  }
}

class EditableChecklistTab extends StatelessWidget {
  const EditableChecklistTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addItem(
    BuildContext context,
    ChecklistCategory category,
  ) async {
    final controller = TextEditingController();
    try {
      final item = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${appText(context, 'Add to')} ${category.category}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: appText(context, 'Checklist item'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appText(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(appText(context, 'Add')),
            ),
          ],
        ),
      );
      if (item == null || item.isEmpty) return;
      final next = trip.checklist
          .map(
            (candidate) => candidate == category
                ? ChecklistCategory(candidate.category, [
                    ...candidate.items,
                    item,
                  ])
                : candidate,
          )
          .toList();
      onSave(trip.copyWith(checklist: next));
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        for (final category in trip.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appText(context, category.category),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addItem(context, category),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  for (final item in category.items)
                    CheckboxListTile(
                      dense: true,
                      value: false,
                      onChanged: (_) {},
                      title: Text(appText(context, item)),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          final next = trip.checklist
                              .map(
                                (candidate) => candidate == category
                                    ? ChecklistCategory(
                                        candidate.category,
                                        candidate.items
                                            .where((value) => value != item)
                                            .toList(),
                                      )
                                    : candidate,
                              )
                              .toList();
                          onSave(trip.copyWith(checklist: next));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class EditableBookingTab extends StatelessWidget {
  const EditableBookingTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addBooking(BuildContext context) async {
    final title = TextEditingController();
    final date = TextEditingController(text: trip.startDate);
    final time = TextEditingController(text: '10:00');
    final reference = TextEditingController(text: 'TBD');
    final cost = TextEditingController(text: '0');
    try {
      final booking = await showDialog<Booking>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(appText(context, 'Add booking')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Title'),
                  ),
                ),
                TextField(
                  controller: date,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Date'),
                  ),
                ),
                TextField(
                  controller: time,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Time'),
                  ),
                ),
                TextField(
                  controller: reference,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Reference'),
                  ),
                ),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Cost'),
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
              onPressed: () => Navigator.of(context).pop(
                Booking(
                  title.text.trim().isEmpty ? 'New booking' : title.text.trim(),
                  date.text.trim(),
                  time.text.trim(),
                  reference.text.trim(),
                  int.tryParse(cost.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
                  Icons.confirmation_number_rounded,
                ),
              ),
              child: Text(appText(context, 'Add')),
            ),
          ],
        ),
      );
      if (booking == null) return;
      onSave(trip.copyWith(bookings: [...trip.bookings, booking]));
    } finally {
      title.dispose();
      date.dispose();
      time.dispose();
      reference.dispose();
      cost.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        PrimaryButton(
          label: 'Add booking',
          icon: Icons.add_rounded,
          onPressed: () => _addBooking(context),
        ),
        const SizedBox(height: 16),
        for (final booking in trip.bookings)
          Dismissible(
            key: ValueKey('${booking.title}-${booking.reference}'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 10),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            onDismissed: (_) => onSave(
              trip.copyWith(
                bookings: trip.bookings
                    .where((candidate) => candidate != booking)
                    .toList(),
              ),
            ),
            child: BookingTile(booking: booking),
          ),
      ],
    );
  }
}

class TripChatTab extends StatelessWidget {
  const TripChatTab({required this.trip, required this.onOpenChat, super.key});
  final Trip trip;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            children: [
              const IconBadge(icon: Icons.chat_bubble_rounded, size: 54),
              const SizedBox(height: 12),
              Text(
                '${trip.destination} AI',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  'Ask for route changes, cheaper options, packing help, or booking reminders.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Open chat',
                icon: Icons.arrow_forward_rounded,
                onPressed: onOpenChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl({
    required this.label,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });
  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}

class BudgetCategoryEditor extends StatelessWidget {
  const BudgetCategoryEditor({
    required this.category,
    required this.currency,
    required this.onChanged,
    super.key,
  });
  final BudgetCategory category;
  final String currency;
  final ValueChanged<BudgetCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final planned = TextEditingController(text: category.planned.toString());
    final actual = TextEditingController(text: category.actual.toString());
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, category.category),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ResponsiveSplit(
            children: [
              TextField(
                controller: planned,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${appText(context, 'Planned')} $currency',
                ),
                onSubmitted: (_) => onChanged(
                  category.copyWith(
                    planned:
                        int.tryParse(
                          planned.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.planned,
                    actual:
                        int.tryParse(
                          actual.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.actual,
                  ),
                ),
              ),
              TextField(
                controller: actual,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${appText(context, 'Actual')} $currency',
                ),
                onSubmitted: (_) => onChanged(
                  category.copyWith(
                    planned:
                        int.tryParse(
                          planned.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.planned,
                    actual:
                        int.tryParse(
                          actual.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.actual,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
