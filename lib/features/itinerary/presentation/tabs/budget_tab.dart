part of travel_agent_app;

class BudgetTab extends StatelessWidget {
  const BudgetTab({required this.trip, required this.onSave, super.key});
  final Trip trip;
  final ValueChanged<Trip> onSave;

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
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Budget'),
              const SizedBox(height: 8),
              Text(
                '${trip.currency} $actual of ${trip.currency} ${trip.budget}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  backgroundColor: _secondary.withValues(alpha: .16),
                  color: _secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BudgetCategoryEditor(
              category: category,
              currency: trip.currency,
              onChanged: (updated) {
                final next = categories
                    .map((item) => item.id == updated.id ? updated : item)
                    .toList();
                onSave(
                  trip.copyWith(
                    budgetCategories: next,
                    spent: next.fold<int>(
                      0,
                      (total, item) => total + item.actual,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BudgetCategoryEditor extends StatelessWidget {
  const _BudgetCategoryEditor({
    required this.category,
    required this.currency,
    required this.onChanged,
  });
  final BudgetCategory category;
  final String currency;
  final ValueChanged<BudgetCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final planned = TextEditingController(text: category.planned.toString());
    final actual = TextEditingController(text: category.actual.toString());
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, category.category),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ResponsiveSplit(
            children: [
              TextField(
                controller: planned,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${appText(context, 'Planned')} $currency',
                ),
                onSubmitted: (_) => onChanged(
                  category.copyWith(
                    planned:
                        int.tryParse(
                          planned.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.planned,
                    actual:
                        int.tryParse(
                          actual.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.actual,
                  ),
                ),
              ),
              TextField(
                controller: actual,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${appText(context, 'Actual')} $currency',
                ),
                onSubmitted: (_) => onChanged(
                  category.copyWith(
                    planned:
                        int.tryParse(
                          planned.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.planned,
                    actual:
                        int.tryParse(
                          actual.text.replaceAll(RegExp(r'\D'), ''),
                        ) ??
                        category.actual,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
