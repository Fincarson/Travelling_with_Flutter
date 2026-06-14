part of travel_agent_app;

class ChecklistTab extends StatelessWidget {
  const ChecklistTab({required this.trip, required this.onSave, super.key});
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
                    Builder(
                      builder: (context) {
                        final isAiAdded = _isAiChecklistItem(item);
                        return Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            dense: true,
                            value: false,
                            onChanged: (_) {},
                            title: Text(
                              appText(context, _checklistDisplayText(item)),
                              style: TextStyle(
                                color: isAiAdded
                                    ? const Color(0xFFB7791F)
                                    : null,
                                fontWeight: isAiAdded
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                backgroundColor: isAiAdded
                                    ? const Color(0xFFFFF3BF)
                                    : null,
                              ),
                            ),
                            secondary: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () {
                                final next = trip.checklist
                                    .map(
                                      (candidate) => candidate == category
                                          ? ChecklistCategory(
                                              candidate.category,
                                              candidate.items
                                                  .where(
                                                    (value) => value != item,
                                                  )
                                                  .toList(),
                                            )
                                          : candidate,
                                    )
                                    .toList();
                                onSave(trip.copyWith(checklist: next));
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
