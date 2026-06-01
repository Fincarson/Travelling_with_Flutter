part of travel_agent_app;

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({required this.trip, required this.onSave, super.key});

  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  var _selectedDay = 1;

  @override
  void didUpdateWidget(covariant ScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final days = _scheduleDays(widget.trip.items);
    if (!days.contains(_selectedDay)) {
      _selectedDay = days.first;
    }
  }

  Future<void> _addDestination(BuildContext context) async {
    final activity = TextEditingController();
    final time = TextEditingController(text: '10:00 AM');
    final cost = TextEditingController(text: '0');
    var day = _selectedDay;
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
                  _ScheduleDayStepper(
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
      setState(() => _selectedDay = item.day);
      widget.onSave(widget.trip.copyWith(items: [...widget.trip.items, item]));
    } finally {
      activity.dispose();
      time.dispose();
      cost.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ScheduleItem>>{};
    for (final item in widget.trip.items) {
      grouped.putIfAbsent(item.day, () => []).add(item);
    }
    final days = _scheduleDays(widget.trip.items);
    final selectedItems = grouped[_selectedDay] ?? const <ScheduleItem>[];

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        _ScheduleDayTabs(
          days: days,
          selectedDay: _selectedDay,
          onSelect: (day) => setState(() => _selectedDay = day),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Add Destination',
          icon: Icons.add_rounded,
          onPressed: () => _addDestination(context),
        ),
        const SizedBox(height: 16),
        LabelText('${appText(context, 'Day')} $_selectedDay'),
        const SizedBox(height: 10),
        for (final item in selectedItems)
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
            onDismissed: (_) {
              final nextItems = widget.trip.items
                  .where((candidate) => candidate != item)
                  .toList();
              final nextDays = _scheduleDays(nextItems);
              setState(() {
                if (!nextDays.contains(_selectedDay)) {
                  _selectedDay = nextDays.first;
                }
              });
              widget.onSave(widget.trip.copyWith(items: nextItems));
            },
            child: ScheduleTile(item: item),
          ),
      ],
    );
  }

  List<int> _scheduleDays(List<ScheduleItem> items) {
    final days = items.map((item) => item.day).toSet().toList()..sort();
    return days.isEmpty ? [1] : days;
  }
}

class _ScheduleDayTabs extends StatelessWidget {
  const _ScheduleDayTabs({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<int> days;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _ScheduleDayTab(
                day: day,
                selected: day == selectedDay,
                onTap: () => onSelect(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleDayTab extends StatelessWidget {
  const _ScheduleDayTab({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: selected ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _primary : const Color(0xFFEFF3F6),
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: selected ? .16 : .06),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                appText(context, 'DAY'),
                style: TextStyle(
                  color: selected ? _accent : _secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$day',
                style: TextStyle(
                  color: selected ? Colors.white : _primary,
                  fontSize: 34,
                  height: .95,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleDayStepper extends StatelessWidget {
  const _ScheduleDayStepper({
    required this.label,
    required this.onMinus,
    required this.onPlus,
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
