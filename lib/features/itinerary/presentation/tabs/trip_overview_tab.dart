part of travel_agent_app;

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
