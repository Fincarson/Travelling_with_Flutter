part of travel_agent_app;

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({required this.trip, required this.onSave, super.key});

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
          label: 'Add Stop',
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
