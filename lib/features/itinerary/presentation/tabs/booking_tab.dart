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
    final date = TextEditingController(text: trip.startDate);
    final time = TextEditingController(text: '10:00');
    final reference = TextEditingController(text: 'TBD');
    final cost = TextEditingController(text: '0');
    try {
      final booking = await _showTravelFormSheet<Booking>(
        context: context,
        builder: (sheetContext) => SingleChildScrollView(
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
              TextField(
                controller: date,
                decoration: InputDecoration(
                  labelText: appText(sheetContext, 'Date'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: time,
                decoration: InputDecoration(
                  labelText: appText(sheetContext, 'Time'),
                ),
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
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(appText(sheetContext, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        Booking(
                          title.text.trim().isEmpty
                              ? 'New booking'
                              : title.text.trim(),
                          date.text.trim(),
                          time.text.trim(),
                          reference.text.trim(),
                          int.tryParse(
                                cost.text.replaceAll(RegExp(r'\D'), ''),
                              ) ??
                              0,
                          Icons.confirmation_number_rounded,
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
              onDismissed: (_) => onSave(
                trip.copyWith(
                  bookings: trip.bookings
                      .where((candidate) => candidate != booking)
                      .toList(),
                ),
              ),
              child: BookingTile(booking: booking, currency: trip.currency),
            ),
      ],
    );
  }
}
