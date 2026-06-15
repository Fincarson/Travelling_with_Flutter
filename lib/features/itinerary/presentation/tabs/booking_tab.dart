part of travel_agent_app;

class BookingTab extends StatelessWidget {
  const BookingTab({required this.trip, required this.onSave, super.key});
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
            child: BookingTile(booking: booking, currency: trip.currency),
          ),
      ],
    );
  }
}
