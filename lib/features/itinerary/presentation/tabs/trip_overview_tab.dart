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
    final runtime = _tripRuntimePlan(trip);
    final previewItems = trip.status == TripStatus.ongoing
        ? runtime.todaysItems
        : trip.items.take(3).toList();

    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        if (trip.status == TripStatus.ongoing) ...[
          _TodayPlanPanel(runtime: runtime),
          const SizedBox(height: 12),
        ],
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
        SectionHeader(
          title: trip.status == TripStatus.ongoing
              ? 'Today schedule'
              : 'First schedule stops',
        ),
        const SizedBox(height: 10),
        if (previewItems.isEmpty)
          GlassPanel(
            child: Text(
              appText(context, 'No activities yet'),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        for (final item in previewItems) ScheduleTile(item: item),
      ],
    );
  }
}

class _TodayPlanPanel extends StatelessWidget {
  const _TodayPlanPanel({required this.runtime});

  final _TripRuntimePlan runtime;

  @override
  Widget build(BuildContext context) {
    final next = runtime.nextItem;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Running today'),
          const SizedBox(height: 8),
          Text(
            'Day ${runtime.currentDay} of ${runtime.totalDays}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'No more scheduled stops are waiting right now.'
                : 'Next: ${next.activity} at ${next.time}',
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
