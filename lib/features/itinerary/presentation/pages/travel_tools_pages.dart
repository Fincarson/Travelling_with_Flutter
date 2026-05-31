part of travel_agent_app;

class MapScreen extends StatelessWidget {
  const MapScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18),
        children: [
          TopBar(title: 'Map', onBack: onBack),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: _primary,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _MapPainter()),
                      ),
                      for (final stop in const [
                        Offset(.32, .24),
                        Offset(.58, .42),
                        Offset(.48, .66),
                        Offset(.72, .76),
                      ])
                        Positioned(
                          left: stop.dx * constraints.maxWidth,
                          top: stop.dy * constraints.maxHeight,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: _accent,
                            size: 34,
                          ),
                        ),
                      Positioned(
                        left: 18,
                        bottom: 18,
                        right: 18,
                        child: GlassPanel(
                          child: Text(
                            appText(
                              context,
                              '${trip.destination} route / ${trip.items.length} stops',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          for (final item in trip.items.take(4)) ScheduleTile(item: item),
        ],
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'Travel Info',
      onBack: onBack,
      children: const [
        InfoCard(
          icon: Icons.cloudy_snowing,
          title: 'Weather',
          text: 'Rain expected after 2 PM. Move outdoor shrines earlier.',
        ),
        InfoCard(
          icon: Icons.train_rounded,
          title: 'Transport',
          text: 'IC cards work across trains and buses around central Kyoto.',
        ),
        InfoCard(
          icon: Icons.payments_rounded,
          title: 'Local costs',
          text: 'Temples are often low-cost; cash is still useful for markets.',
        ),
      ],
    );
  }
}

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'Translate',
      onBack: onBack,
      children: const [
        InfoCard(
          icon: Icons.record_voice_over_rounded,
          title: 'Where is Kyoto Station?',
          text: '京都駅はどこですか？',
        ),
        InfoCard(
          icon: Icons.restaurant_rounded,
          title: 'No pork, please.',
          text: '豚肉なしでお願いします。',
        ),
        InfoCard(
          icon: Icons.confirmation_number_rounded,
          title: 'I have a reservation.',
          text: '予約があります。',
        ),
      ],
    );
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

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
    return SimpleToolScreen(
      title: 'Budget',
      onBack: onBack,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Spent'),
              Text(
                '${trip.currency} $actual of ${trip.currency} ${trip.budget}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                  backgroundColor: _primary.withValues(alpha: .12),
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
        for (final category in categories)
          BudgetBar(
            name: category.category,
            planned: category.planned,
            actual: category.actual,
            currency: trip.currency,
            color: _budgetColor(category.id),
          ),
      ],
    );
  }
}

Color _budgetColor(String id) {
  switch (id) {
    case 'transport':
      return _primary;
    case 'stay':
      return _secondary;
    case 'food':
      return _accent;
    default:
      return Colors.blueGrey.shade200;
  }
}

class PackingScreen extends StatelessWidget {
  const PackingScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'AI Packing List',
      onBack: onBack,
      children: [
        for (final group in trip.checklist)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, group.category),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in group.items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item == group.items.first,
                    onChanged: (_) {},
                    activeColor: _primary,
                    title: Text(
                      appText(context, item),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SimpleToolScreen extends StatelessWidget {
  const SimpleToolScreen({
    required this.title,
    required this.onBack,
    required this.children,
    super.key,
  });
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18),
        children: [
          TopBar(title: title, onBack: onBack),
          const SizedBox(height: 18),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
