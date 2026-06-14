part of travel_agent_app;

class BudgetTab extends StatefulWidget {
  const BudgetTab({required this.trip, required this.onSave, super.key});

  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final Set<String> _expandedCategoryIds = {};
  String? _selectedCurrencyCode;

  Trip get trip => widget.trip;

  @override
  Widget build(BuildContext context) {
    final currencyScope = CurrencyScope.maybeOf(context);
    final displayCurrency = _budgetDisplayCurrency(
      scope: currencyScope,
      selectedCurrency: _selectedCurrencyCode,
      originalCurrency: trip.currency,
    );
    final categories = _budgetCategoriesForTrip(trip);
    final actual = _budgetActual(categories);

    return ListView(
      padding: _responsivePagePadding(context, top: 16, bottom: 112),
      children: [
        _BudgetSummaryPanel(
          trip: trip,
          categories: categories,
          actual: actual,
          displayCurrency: displayCurrency,
        ),

        const SizedBox(height: 14),

        _BudgetCurrencySelector(
            value: displayCurrency,
            originalCurrency: trip.currency,
            localCurrency:
                currencyScope?.displayCurrencyCode ??
                AppCurrency.fallbackCurrencyCode,
            currencies:
                currencyScope?.currencies ??
                CurrencyExchangeData.fallback.currencies,
            onChanged: (value) => setState(() => _selectedCurrencyCode = value),
          ),

        const SizedBox(height: 14),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BudgetCategoryAccordion(
              category: category,
              sourceCurrency: trip.currency,
              displayCurrency: displayCurrency,
              expanded: _expandedCategoryIds.contains(category.id),
              onToggle: () => setState(() {
                if (!_expandedCategoryIds.remove(category.id)) {
                  _expandedCategoryIds.add(category.id);
                }
              }),
              onSpendingCreate: () =>
                  _editSpending(category, displayCurrency: displayCurrency),
              onSpendingEdit: (spending) => _editSpending(
                category,
                existing: spending,
                displayCurrency: displayCurrency,
              ),
              onSpendingDelete: (spending) =>
                  _deleteSpending(category, spending),
            ),
          ),
      ],
    );
  }

  Future<void> _editSpending(
    BudgetCategory category, {
    required String displayCurrency,
    BudgetSpending? existing,
  }) async {
    final spending = await _showSpendingDialog(
      context,
      category: category,
      sourceCurrency: trip.currency,
      displayCurrency: displayCurrency,
      existing: existing,
    );
    if (spending == null) return;
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentCategory = _budgetCategoriesForTrip(
        trip,
      ).firstWhere((item) => item.id == category.id, orElse: () => category);
      final spendings = [...currentCategory.spendings];
      final index = spendings.indexWhere((item) => item.id == spending.id);
      if (index == -1) {
        spendings.add(spending);
      } else {
        spendings[index] = spending;
      }
      _saveCategory(currentCategory, spendings);
    });
  }

  void _deleteSpending(BudgetCategory category, BudgetSpending spending) {
    final spendings = category.spendings
        .where((item) => item.id != spending.id)
        .toList();
    _saveCategory(category, spendings);
  }

  void _saveCategory(BudgetCategory category, List<BudgetSpending> spendings) {
    final actual = spendings.fold<int>(
      0,
      (total, spending) => total + spending.amount,
    );
    final updated = category.copyWith(spendings: spendings, actual: actual);
    final categories = _budgetCategoriesForTrip(trip);
    final next = categories
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    widget.onSave(
      trip.copyWith(budgetCategories: next, spent: _budgetActual(next)),
    );
  }
}

class _BudgetSummaryPanel extends StatelessWidget {
  const _BudgetSummaryPanel({
    required this.trip,
    required this.categories,
    required this.actual,
    required this.displayCurrency,
  });

  final Trip trip;
  final List<BudgetCategory> categories;
  final int actual;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0, trip.budget - actual);
    final segments = [
      for (final category in categories)
        if (category.effectiveActual > 0)
          _BudgetPieSegment(
            label: category.category,
            amount: category.effectiveActual,
            color: _budgetColor(category.id),
          ),
      if (remaining > 0)
        const _BudgetPieSegment(
          label: 'Unused',
          amount: 0,
          color: Color(0xFFE5E7EB),
        ).copyWith(amount: remaining),
    ];

    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final chart = SizedBox.square(
            dimension: compact ? 128 : 152,
            child: CustomPaint(
              painter: _BudgetDonutPainter(segments: segments),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${trip.budget == 0 ? 0 : (actual / trip.budget * 100).round()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      appText(context, 'Used'),
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                '${_budgetMoney(context, actual, sourceCurrency: trip.currency, displayCurrency: displayCurrency)} of '
                '${_budgetMoney(context, trip.budget, sourceCurrency: trip.currency, displayCurrency: displayCurrency)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _BudgetLegend(
                sourceCurrency: trip.currency,
                displayCurrency: displayCurrency,
                segments: segments,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: chart),
                const SizedBox(height: 16),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              const SizedBox(width: 22),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetLegend extends StatelessWidget {
  const _BudgetLegend({
    required this.sourceCurrency,
    required this.displayCurrency,
    required this.segments,
  });

  final String sourceCurrency;
  final String displayCurrency;
  final List<_BudgetPieSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 10,
      direction: Axis.vertical,
      children: [
        for (final segment in segments)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: segment.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                appText(context, segment.label),
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _budgetMoney(
                  context,
                  segment.amount,
                  sourceCurrency: sourceCurrency,
                  displayCurrency: displayCurrency,
                ),
                style: const TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BudgetCurrencySelector extends StatelessWidget {
  const _BudgetCurrencySelector({
    required this.value,
    required this.originalCurrency,
    required this.localCurrency,
    required this.currencies,
    required this.onChanged,
  });

  final String value;
  final String originalCurrency;
  final String localCurrency;
  final List<CurrencyInfo> currencies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: appText(context, 'Currency'),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: _budgetCurrencyItems(
        context,
        currencies: currencies,
        localCurrency: localCurrency,
        originalCurrency: originalCurrency,
      ),
      onChanged: (selected) {
        if (selected == null || selected == _budgetCurrencyDividerValue) {
          return;
        }
        onChanged(selected);
      },
    );
  }
}

class _BudgetCategoryAccordion extends StatelessWidget {
  const _BudgetCategoryAccordion({
    required this.category,
    required this.sourceCurrency,
    required this.displayCurrency,
    required this.expanded,
    required this.onToggle,
    required this.onSpendingCreate,
    required this.onSpendingEdit,
    required this.onSpendingDelete,
  });

  final BudgetCategory category;
  final String sourceCurrency;
  final String displayCurrency;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onSpendingCreate;
  final ValueChanged<BudgetSpending> onSpendingEdit;
  final ValueChanged<BudgetSpending> onSpendingDelete;

  @override
  Widget build(BuildContext context) {
    final actual = category.effectiveActual;
    final planned = math.max(0, category.planned);
    final percent = planned == 0 ? 0.0 : (actual / planned).clamp(0.0, 1.0);
    final color = _budgetColor(category.id);

    return GlassPanel(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_budgetIcon(category.id), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appText(context, category.category),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${(percent * 100).round()}%',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 7,
                            backgroundColor: color.withValues(alpha: .12),
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_budgetMoney(context, actual, sourceCurrency: sourceCurrency, displayCurrency: displayCurrency)} spent of '
                          '${_budgetMoney(context, planned, sourceCurrency: sourceCurrency, displayCurrency: displayCurrency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _secondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  if (category.spendings.isEmpty)
                    _EmptySpendingPanel(onCreate: onSpendingCreate)
                  else
                    for (final spending in category.spendings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BudgetSpendingCard(
                          key: ValueKey(spending.id),
                          spending: spending,
                          sourceCurrency: sourceCurrency,
                          displayCurrency: displayCurrency,
                          color: color,
                          onEdit: () => onSpendingEdit(spending),
                          onDelete: () => onSpendingDelete(spending),
                        ),
                      ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: onSpendingCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(appText(context, 'Create new spending')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySpendingPanel extends StatelessWidget {
  const _EmptySpendingPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: _secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, 'No spendings yet'),
              style: const TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onCreate, child: Text(appText(context, 'Add'))),
        ],
      ),
    );
  }
}

class _BudgetSpendingCard extends StatefulWidget {
  const _BudgetSpendingCard({
    required this.spending,
    required this.sourceCurrency,
    required this.displayCurrency,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final BudgetSpending spending;
  final String sourceCurrency;
  final String displayCurrency;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_BudgetSpendingCard> createState() => _BudgetSpendingCardState();
}

class _BudgetSpendingCardState extends State<_BudgetSpendingCard> {
  var _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -80) {
          setState(() => _revealed = true);
        } else if (velocity > 80) {
          setState(() => _revealed = false);
        }
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SpendingActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: _secondary,
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 8),
                _SpendingActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: const Color(0xFFE5484D),
                  onTap: widget.onDelete,
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_revealed ? -148 : 0, 0, 0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (_revealed) {
                    setState(() => _revealed = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _primary.withValues(alpha: .08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.payments_rounded,
                          color: widget.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.spending.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (widget.spending.date.isNotEmpty ||
                                widget.spending.note.isNotEmpty)
                              Text(
                                [
                                  if (widget.spending.date.isNotEmpty)
                                    widget.spending.date,
                                  if (widget.spending.note.isNotEmpty)
                                    widget.spending.note,
                                ].join(' / '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _budgetMoney(
                          context,
                          widget.spending.amount,
                          sourceCurrency: widget.sourceCurrency,
                          displayCurrency: widget.displayCurrency,
                        ),
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendingActionButton extends StatelessWidget {
  const _SpendingActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 58,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(
              appText(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetPieSegment {
  const _BudgetPieSegment({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  _BudgetPieSegment copyWith({int? amount}) => _BudgetPieSegment(
    label: label,
    amount: amount ?? this.amount,
    color: color,
  );
}

class _BudgetDonutPainter extends CustomPainter {
  const _BudgetDonutPainter({required this.segments});

  final List<_BudgetPieSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final total = segments.fold<int>(
      0,
      (value, segment) => value + segment.amount,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 18;
    if (total <= 0) {
      paint.color = const Color(0xFFE5E7EB);
      canvas.drawArc(rect.deflate(12), -math.pi / 2, math.pi * 2, false, paint);
      return;
    }

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.amount <= 0) continue;
      final sweep = math.pi * 2 * segment.amount / total;
      paint.color = segment.color;
      canvas.drawArc(rect.deflate(12), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetDonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

Future<BudgetSpending?> _showSpendingDialog(
  BuildContext context, {
  required BudgetCategory category,
  required String sourceCurrency,
  required String displayCurrency,
  BudgetSpending? existing,
}) async {
  final exchangeData = CurrencyScope.maybeOf(context)?.exchangeData;
  final existingAmount = existing == null
      ? ''
      : _budgetConvertedAmount(
          existing.amount,
          sourceCurrency: sourceCurrency,
          displayCurrency: displayCurrency,
          exchangeData: exchangeData,
        ).round().toString();
  final title = TextEditingController(text: existing?.title ?? '');
  final amount = TextEditingController(text: existingAmount);
  final date = TextEditingController(text: existing?.date ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  try {
    return await showDialog<BudgetSpending>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          appText(
            dialogContext,
            existing == null ? 'Create new spending' : 'Edit spending',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: appText(dialogContext, 'Title'),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${appText(dialogContext, 'Amount')} $displayCurrency',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: date,
                decoration: InputDecoration(
                  labelText: appText(dialogContext, 'Date'),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: appText(dialogContext, 'Note'),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appText(dialogContext, 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsedAmount =
                  int.tryParse(amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
              if (parsedAmount <= 0) return;
              final sourceAmount = _budgetSourceAmountFromDisplay(
                parsedAmount,
                sourceCurrency: sourceCurrency,
                displayCurrency: displayCurrency,
                exchangeData: exchangeData,
              );
              Navigator.of(dialogContext).pop(
                BudgetSpending(
                  id:
                      existing?.id ??
                      'spending-${DateTime.now().microsecondsSinceEpoch}',
                  title: title.text.trim().isEmpty
                      ? category.category
                      : title.text.trim(),
                  amount: sourceAmount,
                  date: date.text.trim(),
                  note: note.text.trim(),
                ),
              );
            },
            child: Text(appText(dialogContext, 'Save')),
          ),
        ],
      ),
    );
  } finally {
    title.dispose();
    amount.dispose();
    date.dispose();
    note.dispose();
  }
}

List<BudgetCategory> _budgetCategoriesForTrip(Trip trip) {
  if (trip.budgetCategories.isNotEmpty) return trip.budgetCategories;
  return _defaultBudgetCategories(
    budget: trip.budget,
    actual: trip.spent,
    items: trip.items,
    bookings: trip.bookings,
  );
}

int _budgetActual(List<BudgetCategory> categories) {
  return categories.fold<int>(0, (total, item) => total + item.effectiveActual);
}

const _budgetCurrencyDividerValue = '__budget_currency_divider__';

String _budgetDisplayCurrency({
  required CurrencyScope? scope,
  required String? selectedCurrency,
  required String originalCurrency,
}) {
  final selected = selectedCurrency?.trim().toUpperCase();
  if (selected != null && selected.isNotEmpty) return selected;
  final local = scope?.displayCurrencyCode.trim().toUpperCase();
  if (local != null && local.isNotEmpty) return local;
  final original = originalCurrency.trim().toUpperCase();
  return original.isEmpty ? AppCurrency.fallbackCurrencyCode : original;
}

List<DropdownMenuItem<String>> _budgetCurrencyItems(
  BuildContext context, {
  required List<CurrencyInfo> currencies,
  required String localCurrency,
  required String originalCurrency,
}) {
  final byCode = {
    for (final currency in currencies) currency.code.toUpperCase(): currency,
  };
  final local = localCurrency.trim().toUpperCase();
  final original = originalCurrency.trim().toUpperCase();
  final topCodes = <String>[
    if (local.isNotEmpty) local,
    if (original.isNotEmpty && original != local) original,
  ];
  final allCodes = {
    ...topCodes,
    ...currencies.map((currency) => currency.code.toUpperCase()),
    AppCurrency.fallbackCurrencyCode,
  }.where((code) => code.isNotEmpty).toList()..sort();
  final otherCodes = allCodes
      .where((code) => !topCodes.contains(code))
      .toList(growable: false);

  final items = <DropdownMenuItem<String>>[
    for (final code in topCodes)
      DropdownMenuItem<String>(
        value: code,
        child: _BudgetCurrencyMenuLabel(
          code: code,
          role: code == local && code == original
              ? 'Local / Original'
              : code == local
              ? 'Local'
              : 'Original',
          info: byCode[code],
        ),
      ),
  ];

  if (otherCodes.isNotEmpty) {
    items.add(
      const DropdownMenuItem<String>(
        value: _budgetCurrencyDividerValue,
        enabled: false,
        child: Divider(height: 1),
      ),
    );
    items.addAll(
      otherCodes.map(
        (code) => DropdownMenuItem<String>(
          value: code,
          child: _BudgetCurrencyMenuLabel(code: code, info: byCode[code]),
        ),
      ),
    );
  }

  return items;
}

class _BudgetCurrencyMenuLabel extends StatelessWidget {
  const _BudgetCurrencyMenuLabel({required this.code, this.role, this.info});

  final String code;
  final String? role;
  final CurrencyInfo? info;

  @override
  Widget build(BuildContext context) {
    final label = role == null ? code : '${appText(context, role!)} · $code';
    final name = info?.name ?? code;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (role == null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _secondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _budgetMoney(
  BuildContext context,
  num amount, {
  required String sourceCurrency,
  required String displayCurrency,
}) {
  final exchangeData = CurrencyScope.maybeOf(context)?.exchangeData;
  final converted = _budgetConvertedAmount(
    amount,
    sourceCurrency: sourceCurrency,
    displayCurrency: displayCurrency,
    exchangeData: exchangeData,
  );
  return _formatCurrencyAmount(converted, displayCurrency);
}

double _budgetConvertedAmount(
  num amount, {
  required String sourceCurrency,
  required String displayCurrency,
  required CurrencyExchangeData? exchangeData,
}) {
  final source = sourceCurrency.trim().toUpperCase();
  final display = displayCurrency.trim().toUpperCase();
  if (source == display) return amount.toDouble();
  return exchangeData
          ?.convert(amount: amount, fromCurrency: source, toCurrency: display)
          ?.toDouble() ??
      amount.toDouble();
}

int _budgetSourceAmountFromDisplay(
  num amount, {
  required String sourceCurrency,
  required String displayCurrency,
  required CurrencyExchangeData? exchangeData,
}) {
  final source = sourceCurrency.trim().toUpperCase();
  final display = displayCurrency.trim().toUpperCase();
  if (source == display) return amount.round();
  return (exchangeData
              ?.convert(
                amount: amount,
                fromCurrency: display,
                toCurrency: source,
              )
              ?.round() ??
          amount.round())
      .clamp(0, 1 << 31)
      .toInt();
}

IconData _budgetIcon(String id) {
  switch (id) {
    case 'transport':
      return Icons.train_rounded;
    case 'stay':
      return Icons.hotel_rounded;
    case 'food':
      return Icons.restaurant_rounded;
    case 'activities':
      return Icons.confirmation_number_rounded;
    default:
      return Icons.wallet_rounded;
  }
}
