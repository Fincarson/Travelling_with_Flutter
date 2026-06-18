part of travel_agent_app;

class BookingTab extends StatelessWidget {
  const BookingTab({
    required this.trip,
    required this.onSave,
    this.readOnly = false,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;
  final bool readOnly;

  Future<void> _addBooking(BuildContext context) async {
    final title = TextEditingController();
    final reference = TextEditingController(text: 'TBD');
    final cost = TextEditingController(text: '0');
    final firstDate = _parseTripDate(trip.startDate) ?? DateTime(2000);
    final lastDate = _parseTripDate(trip.endDate) ?? DateTime(2100);
    var selectedDate = trip.startDate.trim().isEmpty
        ? _dateKey(firstDate)
        : trip.startDate;
    var selectedMinutes = 10 * 60;
    try {
      final booking = await _showTravelFormSheet<Booking>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  appText(sheetContext, 'Add booking'),
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: appText(sheetContext, 'Title'),
                  ),
                ),
                const SizedBox(height: 10),
                _SheetPickerField(
                  label: 'Date',
                  value: selectedDate,
                  icon: Icons.calendar_month_rounded,
                  onTap: () async {
                    final picked = await _pickSheetDate(
                      context,
                      initialDate: selectedDate,
                      firstDate: firstDate,
                      lastDate: lastDate.isBefore(firstDate)
                          ? firstDate
                          : lastDate,
                    );
                    if (picked == null || !context.mounted) return;
                    setDialogState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 10),
                _SheetPickerField(
                  label: 'Time',
                  value: _minutesToPickerTimeLabel(selectedMinutes),
                  icon: Icons.schedule_rounded,
                  onTap: () async {
                    final picked = await _showWheelTimePicker(
                      context,
                      initialMinutes: selectedMinutes,
                    );
                    if (picked == null || !context.mounted) return;
                    setDialogState(() => selectedMinutes = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: InputDecoration(
                    labelText: appText(sheetContext, 'Reference'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: appText(sheetContext, 'Cost'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => unawaited(
                          _closeTravelFormSheet<Booking>(sheetContext),
                        ),
                        child: Text(appText(sheetContext, 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => unawaited(
                          _closeTravelFormSheet<Booking>(
                            sheetContext,
                            Booking(
                              title.text.trim().isEmpty
                                  ? 'New booking'
                                  : title.text.trim(),
                              selectedDate,
                              _minutesToPickerTimeLabel(selectedMinutes),
                              reference.text.trim(),
                              int.tryParse(
                                    cost.text.replaceAll(RegExp(r'\D'), ''),
                                  ) ??
                                  0,
                              Icons.confirmation_number_rounded,
                            ),
                          ),
                        ),
                        child: Text(appText(sheetContext, 'Add')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (booking == null) return;
      onSave(trip.copyWith(bookings: [...trip.bookings, booking]));
    } finally {
      title.dispose();
      reference.dispose();
      cost.dispose();
    }
  }

  void _deleteBooking(BuildContext context, Booking booking) {
    final index = trip.bookings.indexOf(booking);
    if (index == -1) return;
    final next = [...trip.bookings]..removeAt(index);
    onSave(trip.copyWith(bookings: next));
    _showUndoSnackBar(
      context,
      message: 'Booking deleted',
      undoLabel: 'Undo',
      onUndo: () {
        final restored = [...trip.bookings];
        restored.insert(index.clamp(0, restored.length).toInt(), booking);
        onSave(trip.copyWith(bookings: restored));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        if (!readOnly) ...[
          PrimaryButton(
            label: 'Add booking',
            icon: Icons.add_rounded,
            onPressed: () => _addBooking(context),
          ),
          const SizedBox(height: 16),
        ],
        for (final booking in trip.bookings)
          if (readOnly)
            BookingTile(booking: booking, currency: trip.currency)
          else
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
              onDismissed: (_) => _deleteBooking(context, booking),
              child: BookingTile(booking: booking, currency: trip.currency),
            ),
      ],
    );
  }
}
