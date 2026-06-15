part of travel_agent_app;

class CreateOptionCard extends StatelessWidget {
  const CreateOptionCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassPanel(
        child: SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              IconBadge(icon: icon, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, title),
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 16,
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
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: _secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class FullTapDropdownField extends StatelessWidget {
  const FullTapDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            child: Text(appText(context, option)),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: appText(context, label),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appText(context, value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateTripChatTurn extends StatelessWidget {
  const CreateTripChatTurn({
    required this.message,
    required this.onSelect,
    required this.selectedCurrency,
    required this.currencyOptions,
    required this.onCurrencyChanged,
    required this.budgetOptions,
    super.key,
  });

  final CreateTripChatMessage message;
  final ValueChanged<String> onSelect;
  final String selectedCurrency;
  final List<String> currencyOptions;
  final ValueChanged<String> onCurrencyChanged;
  final List<CreateTripChoiceOption> budgetOptions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.fromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        CreateTripChatBubble(message: message),
        if (!message.fromUser && message.widget != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CreateTripChoicePanel(
              widget: message.widget!,
              onSelect: onSelect,
              selectedCurrency: selectedCurrency,
              currencyOptions: currencyOptions,
              onCurrencyChanged: onCurrencyChanged,
              budgetOptions: budgetOptions,
            ),
          ),
      ],
    );
  }
}

class CreateTripChatBubble extends StatelessWidget {
  const CreateTripChatBubble({required this.message, super.key});
  final CreateTripChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      360.0,
      MediaQuery.sizeOf(context).width * 0.82,
    );
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: message.fromUser ? _primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(message.fromUser ? 22 : 6),
            topRight: Radius.circular(message.fromUser ? 6 : 22),
            bottomLeft: const Radius.circular(22),
            bottomRight: const Radius.circular(22),
          ),
          border: message.fromUser
              ? null
              : Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Text(
          message.fromUser ? message.text : appText(context, message.text),
          style: TextStyle(
            color: message.fromUser ? Colors.white : _primary,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class CreateTripThinkingBubble extends StatelessWidget {
  const CreateTripThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              appText(context, 'Thinking...'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateTripChoicePanel extends StatelessWidget {
  const CreateTripChoicePanel({
    required this.widget,
    required this.onSelect,
    required this.selectedCurrency,
    required this.currencyOptions,
    required this.onCurrencyChanged,
    required this.budgetOptions,
    super.key,
  });

  final CreateTripChoiceWidget widget;
  final ValueChanged<String> onSelect;
  final String selectedCurrency;
  final List<String> currencyOptions;
  final ValueChanged<String> onCurrencyChanged;
  final List<CreateTripChoiceOption> budgetOptions;

  @override
  Widget build(BuildContext context) {
    final isBudgetPanel = _isBudgetChoicePanel(widget);
    final options = isBudgetPanel ? budgetOptions : widget.options;

    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appText(context, widget.title),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isBudgetPanel)
                _BudgetCurrencyMenu(
                  currency: selectedCurrency,
                  options: currencyOptions,
                  onChanged: onCurrencyChanged,
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => option.value == _customBudgetValue
                    ? _showCustomBudgetDialog(context)
                    : onSelect(option.value),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFF3F6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appText(context, option.label),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (option.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                appText(context, option.description),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCustomBudgetDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final amount = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(appText(context, 'Custom budget')),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: appText(context, 'Total budget'),
              prefixText: '$selectedCurrency ',
            ),
            onSubmitted: (_) {
              final parsed = int.tryParse(
                controller.text.replaceAll(RegExp(r'\D'), ''),
              );
              Navigator.of(context).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appText(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(
                  controller.text.replaceAll(RegExp(r'\D'), ''),
                );
                Navigator.of(context).pop(parsed);
              },
              child: Text(appText(context, 'Use budget')),
            ),
          ],
        ),
      );
      if (amount == null || amount <= 0) return;
      onSelect('budget $amount $selectedCurrency');
    } finally {
      controller.dispose();
    }
  }
}

const _customBudgetValue = '__custom_budget__';

bool _isBudgetChoicePanel(CreateTripChoiceWidget widget) {
  final title = widget.title.toLowerCase();
  if (title.contains('budget')) return true;
  return widget.options.any((option) {
    final label = option.label.toLowerCase();
    return label.contains('budget') ||
        label.contains('mid-range') ||
        label.contains('premium');
  });
}

class _BudgetCurrencyMenu extends StatelessWidget {
  const _BudgetCurrencyMenu({
    required this.currency,
    required this.options,
    required this.onChanged,
  });

  final String currency;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: appText(context, 'Currency'),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, child: Text(option)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency,
              style: const TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: _primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class CreateTripDraftCard extends StatelessWidget {
  const CreateTripDraftCard({
    required this.draft,
    required this.confirmed,
    required this.onConfirm,
    required this.onChange,
    required this.onEdit,
    this.onUse,
    super.key,
  });

  final CreateTripDraft draft;
  final bool confirmed;
  final VoidCallback onConfirm;
  final ValueChanged<String> onChange;
  final VoidCallback onEdit;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.auto_awesome_rounded, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelText('AI Prepared'),
                    Text(
                      appText(context, draft.destination ?? 'New trip'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SmallPill(label: confirmed ? 'Confirmed' : 'Review'),
            ],
          ),
          const SizedBox(height: 14),
          ResponsiveSplit(
            children: [
              DraftStat(
                label: 'Dates',
                value: draft.startDate == null || draft.endDate == null
                    ? 'TBD'
                    : '${_dateKey(draft.startDate!)} / ${_dateKey(draft.endDate!)}',
              ),
              DraftStat(
                label: 'Budget',
                value: draft.budget == null
                    ? 'TBD'
                    : '${draft.currency ?? 'USD'} ${_formatAmountText(draft.budget!)}',
              ),
              DraftStat(label: 'Party', value: draft.groupType ?? 'TBD'),
            ],
          ),
          if (draft.preferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: draft.preferences
                  .map((item) => SmallPill(label: item))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                CreateTripPromptChip(
                  label: 'Cheaper',
                  prompt: 'Make it cheaper',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'More food',
                  prompt: 'Add more food',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'Slower',
                  prompt: 'Slow the pace',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'Nature',
                  prompt: 'More nature',
                  onTap: onChange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ResponsiveSplit(
            children: [
              FilledButton(
                onPressed: onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  appText(context, 'CUSTOMIZE'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: confirmed ? _accent : _primary,
                  foregroundColor: confirmed ? _primary : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  appText(context, confirmed ? 'CONFIRMED' : 'CONFIRM'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onUse,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFEFF3F6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              appText(context, 'PREVIEW ITINERARY'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DraftEditButton extends StatelessWidget {
  const DraftEditButton({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appText(context, label).toUpperCase(),
              style: const TextStyle(
                color: _secondary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DraftStat extends StatelessWidget {
  const DraftStat({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, label).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _secondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appText(context, value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTripPromptChip extends StatelessWidget {
  const CreateTripPromptChip({
    required this.label,
    required this.prompt,
    required this.onTap,
    super.key,
  });

  final String label;
  final String prompt;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(appText(context, label)),
        onPressed: () => onTap(prompt),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        backgroundColor: const Color(0xFFF8FAFC),
        side: const BorderSide(color: Color(0xFFEFF3F6)),
      ),
    );
  }
}

class DateRangeCard extends StatelessWidget {
  const DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onPickRange,
    required this.onPickStart,
    required this.onPickEnd,
    super.key,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickRange;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPickRange,
      child: GlassPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Trip dates'),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateKey(startDate)} / ${_dateKey(endDate)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            );

            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(
                        icon: Icons.calendar_month_rounded,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: content),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: appText(context, 'Start date'),
                        onPressed: onPickStart,
                        icon: const Icon(Icons.today_rounded),
                      ),
                      IconButton(
                        tooltip: appText(context, 'End date'),
                        onPressed: onPickEnd,
                        icon: const Icon(Icons.event_available_rounded),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                const IconBadge(icon: Icons.calendar_month_rounded, size: 46),
                const SizedBox(width: 12),
                Expanded(child: content),
                IconButton(
                  tooltip: appText(context, 'Start date'),
                  onPressed: onPickStart,
                  icon: const Icon(Icons.today_rounded),
                ),
                IconButton(
                  tooltip: appText(context, 'End date'),
                  onPressed: onPickEnd,
                  icon: const Icon(Icons.event_available_rounded),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GeneratingTripPanel extends StatelessWidget {
  const GeneratingTripPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Generating schedule...'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  appText(
                    context,
                    'AI is shaping the route, bookings, budget, and packing list.',
                  ),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
