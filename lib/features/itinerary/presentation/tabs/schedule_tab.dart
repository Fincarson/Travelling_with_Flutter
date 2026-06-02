part of travel_agent_app;

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({required this.trip, required this.onSave, super.key});

  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addScheduleStop(BuildContext context) async {
    final mode = await showModalBottomSheet<_ScheduleStopMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _responsiveHorizontalPadding(context),
            8,
            _responsiveHorizontalPadding(context),
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddStopModeCard(
                icon: Icons.edit_note_rounded,
                title: 'Add manually',
                text: 'Type the activity, time, day, and cost yourself.',
                onTap: () =>
                    Navigator.of(context).pop(_ScheduleStopMode.manual),
              ),
              const SizedBox(height: 10),
              _AddStopModeCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Add with AI',
                text: 'Describe what you need and let AI suggest one stop.',
                onTap: () => Navigator.of(context).pop(_ScheduleStopMode.ai),
              ),
            ],
          ),
        ),
      ),
    );
    if (mode == null) return;
    if (!context.mounted) return;

    final item = switch (mode) {
      // ignore: use_build_context_synchronously
      _ScheduleStopMode.manual => await _manualScheduleStopDialog(context),
      // ignore: use_build_context_synchronously
      _ScheduleStopMode.ai => await _aiScheduleStopDialog(context),
    };
    if (item == null) return;
    onSave(trip.copyWith(items: [...trip.items, item]));
  }

  Future<ScheduleItem?> _manualScheduleStopDialog(BuildContext context) async {
    final activity = TextEditingController();
    final time = TextEditingController(text: '10:00 AM');
    final cost = TextEditingController(text: '0');
    var day = _tripRuntimePlan(trip).currentDay;
    try {
      return await showDialog<ScheduleItem>(
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
    } finally {
      activity.dispose();
      time.dispose();
      cost.dispose();
    }
  }

  Future<ScheduleItem?> _aiScheduleStopDialog(BuildContext context) async {
    final description = TextEditingController();
    var day = _tripRuntimePlan(trip).currentDay;
    var isGenerating = false;
    String? error;
    try {
      return await showDialog<ScheduleItem>(
        context: context,
        barrierDismissible: !isGenerating,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> generate() async {
              if (isGenerating) return;
              setDialogState(() {
                isGenerating = true;
                error = null;
              });
              try {
                final item = await TravelAssistantService()
                    .generateScheduleStop(
                      trip: trip,
                      day: day,
                      description: description.text,
                    )
                    .timeout(const Duration(seconds: 20));
                if (!context.mounted) return;
                Navigator.of(context).pop(item);
              } catch (_) {
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pop(_fallbackAiScheduleStop(trip, day, description.text));
              }
            }

            return AlertDialog(
              title: Text(appText(context, 'Add with AI')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: appText(context, 'Description'),
                        hintText: appText(
                          context,
                          'Example: indoor lunch stop near the museum',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ScheduleDayStepper(
                      label: '${appText(context, 'Day')} $day',
                      onMinus: isGenerating
                          ? null
                          : () => setDialogState(
                              () => day = math.max(1, day - 1),
                            ),
                      onPlus: isGenerating
                          ? null
                          : () => setDialogState(() => day += 1),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      FormNotice(message: error!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isGenerating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(appText(context, 'Cancel')),
                ),
                FilledButton.icon(
                  onPressed: isGenerating ? null : () => unawaited(generate()),
                  icon: isGenerating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    appText(context, isGenerating ? 'Thinking...' : 'Generate'),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      description.dispose();
    }
  }

  ScheduleItem _fallbackAiScheduleStop(Trip trip, int day, String description) {
    final lower = description.toLowerCase();
    final minutes = _suggestStopMinutes(trip, day);
    final isFood =
        lower.contains('food') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('eat');
    final isIndoor =
        lower.contains('indoor') ||
        lower.contains('rain') ||
        lower.contains('museum');
    final isShopping = lower.contains('shop') || lower.contains('market');
    final isNature =
        lower.contains('nature') ||
        lower.contains('walk') ||
        lower.contains('hike');
    final activity = description.trim().isEmpty
        ? 'Suggested ${trip.destination.split(',').first} stop'
        : _titleFromDescription(description);
    return ScheduleItem(
      day,
      _minutesToScheduleLabel(minutes),
      activity,
      isFood
          ? Icons.restaurant_rounded
          : isShopping
          ? Icons.shopping_bag_rounded
          : isNature
          ? Icons.directions_walk_rounded
          : isIndoor
          ? Icons.museum_rounded
          : Icons.place_rounded,
      0,
    );
  }

  int _suggestStopMinutes(Trip trip, int day) {
    final dayItems = trip.items.where((item) => item.day == day).toList()
      ..sort(_compareRuntimeScheduleItems);
    if (dayItems.isEmpty) return 10 * 60;
    final last = dayItems
        .map((item) => _parseActivityTimeMinutes(item.time))
        .whereType<int>()
        .fold<int>(10 * 60, math.max);
    return math.min(21 * 60, last + 120);
  }

  String _minutesToScheduleLabel(int minutes) {
    var hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _titleFromDescription(String description) {
    final cleaned = description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 56) return cleaned;
    return '${cleaned.substring(0, 53).trim()}...';
  }

  void _removeScheduleStop(int index) {
    final next = [...trip.items];
    if (index < 0 || index >= next.length) return;
    next.removeAt(index);
    onSave(trip.copyWith(items: next));
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _tripRuntimePlan(trip);
    final grouped = <int, List<({int index, ScheduleItem item})>>{};
    for (var index = 0; index < trip.items.length; index++) {
      final item = trip.items[index];
      grouped.putIfAbsent(item.day, () => []).add((index: index, item: item));
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
        if (trip.status == TripStatus.ongoing) ...[
          GlassPanel(
            child: Row(
              children: [
                const IconBadge(icon: Icons.auto_awesome_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabelText(
                        'Today is day ${runtime.currentDay} of ${runtime.totalDays}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        runtime.nextItem == null
                            ? 'No more scheduled stops are waiting right now.'
                            : 'Next: ${runtime.nextItem!.activity} at ${runtime.nextItem!.time}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (grouped.isEmpty) ...[
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(icon: Icons.route_rounded, size: 46),
                const SizedBox(height: 12),
                Text(
                  appText(context, 'No activities yet'),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appText(context, 'Add stops to build this schedule.'),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final day in grouped.keys.toList()..sort()) ...[
          LabelText('${appText(context, 'Day')} $day'),
          const SizedBox(height: 10),
          for (final entry in grouped[day]!)
            Dismissible(
              key: ValueKey(
                '${entry.index}-${entry.item.day}-${entry.item.time}-${entry.item.activity}',
              ),
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
              onDismissed: (_) => _removeScheduleStop(entry.index),
              child: ScheduleTile(
                item: entry.item,
                onDelete: () => _removeScheduleStop(entry.index),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

enum _ScheduleStopMode { manual, ai }

class _AddStopModeCard extends StatelessWidget {
  const _AddStopModeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBadge(icon: icon, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, title),
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appText(context, text),
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
              const Icon(Icons.chevron_right_rounded, color: _primary),
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
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

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
