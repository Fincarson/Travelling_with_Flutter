part of travel_agent_app;

class CreateOptionCard extends StatefulWidget {
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
  State<CreateOptionCard> createState() => _CreateOptionCardState();
}

class _CreateOptionCardState extends State<CreateOptionCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final interactiveMotion =
        settings.animationsEnabled && settings.heavyVisualEffects;
    return MouseRegion(
      onEnter: (_) {
        if (interactiveMotion) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: settings.transitionDuration,
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: GlassPanel(
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  IconBadge(icon: widget.icon, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, widget.title),
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appText(context, widget.text),
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
                  AnimatedSlide(
                    offset: _hovered ? const Offset(.14, 0) : Offset.zero,
                    duration: settings.transitionDuration,
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: _secondary,
                    ),
                  ),
                ],
              ),
            ),
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
    this.selectedCurrency,
    this.currencyOptions = const [],
    this.onCurrencyChanged,
    this.budgetOptions = const [],
    super.key,
  });

  final CreateTripChatMessage message;
  final ValueChanged<String> onSelect;
  final String? selectedCurrency;
  final List<String> currencyOptions;
  final ValueChanged<String>? onCurrencyChanged;
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
    this.selectedCurrency,
    this.currencyOptions = const [],
    this.onCurrencyChanged,
    this.budgetOptions = const [],
    super.key,
  });

  final CreateTripChoiceWidget widget;
  final ValueChanged<String> onSelect;
  final String? selectedCurrency;
  final List<String> currencyOptions;
  final ValueChanged<String>? onCurrencyChanged;
  final List<CreateTripChoiceOption> budgetOptions;

  @override
  Widget build(BuildContext context) {
    final isBudgetChoice = widget.title.toLowerCase().contains('budget');
    final options = isBudgetChoice && budgetOptions.isNotEmpty
        ? budgetOptions
        : widget.options;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, widget.title),
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isBudgetChoice &&
              selectedCurrency != null &&
              currencyOptions.isNotEmpty &&
              onCurrencyChanged != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final currency in currencyOptions)
                  ChoiceChip(
                    label: Text(currency),
                    selected: currency == selectedCurrency,
                    onSelected: (_) => onCurrencyChanged!(currency),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(option.value),
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
}

class CreateTripDraftCard extends StatelessWidget {
  const CreateTripDraftCard({
    required this.draft,
    required this.confirmed,
    required this.onChange,
    this.onUse,
    super.key,
  });

  final CreateTripDraft draft;
  final bool confirmed;
  final ValueChanged<String> onChange;
  final VoidCallback? onUse;

  String get _lengthLabel {
    final start = draft.startDate;
    final end = draft.endDate;
    if (start == null || end == null) return 'TBD';
    final days = end.difference(start).inDays + 1;
    return days <= 1 ? '1 day' : '$days days';
  }

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
              DraftStat(label: 'Trip length', value: _lengthLabel),
              DraftStat(
                label: 'Budget',
                value: draft.budget == null
                    ? 'TBD'
                    : '${draft.currency ?? 'USD'} ${_formatAmountText(draft.budget!)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ResponsiveSplit(
            children: [
              DraftStat(
                label: 'Travelers',
                value: draft.numOfTravelers == null
                    ? 'TBD'
                    : _travelerCountLabel(draft.numOfTravelers!),
              ),
              DraftStat(
                label: 'Group',
                value: (draft.groupType?.trim().isNotEmpty ?? false)
                    ? draft.groupType!
                    : 'TBD',
              ),
              DraftStat(
                label: 'Trip type',
                value: draft.preferences.isEmpty
                    ? 'TBD'
                    : '${draft.preferences.length} selected',
              ),
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
          FilledButton.icon(
            onPressed: onUse,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.map_rounded),
            label: Text(
              appText(context, 'Preview Itinerary'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
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

class GeneratingTripPanel extends StatefulWidget {
  const GeneratingTripPanel({super.key});

  @override
  State<GeneratingTripPanel> createState() => _GeneratingTripPanelState();
}

class _GeneratingTripPanelState extends State<GeneratingTripPanel> {
  static const _steps = [
    (icon: Icons.travel_explore, text: 'Connecting to AI travel agent...'),
    (icon: Icons.location_on_outlined, text: 'Researching destination and local highlights...'),
    (icon: Icons.calendar_today_outlined, text: 'Planning daily activities...'),
    (icon: Icons.attach_money_outlined, text: 'Finding best prices and budgeting...'),
    (icon: Icons.hotel_outlined, text: 'Building accommodation and booking suggestions...'),
    (icon: Icons.directions_outlined, text: 'Mapping transportation routes...'),
    (icon: Icons.checklist_outlined, text: 'Creating your packing checklist...'),
    (icon: Icons.place_outlined, text: 'Searching for venue details and addresses...'),
    (icon: Icons.photo_library_outlined, text: 'Finding photos for each stop...'),
    (icon: Icons.auto_awesome_outlined, text: 'Finalizing your itinerary...'),
  ];

  static const _delaysMs = [0, 4000, 10000, 18000, 26000, 35000, 44000, 55000, 68000, 82000];

  final List<bool> _visible = List.filled(_steps.length, false);
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _steps.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: _delaysMs[i]), () {
          if (mounted) setState(() => _visible[i] = true);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastVisible = _visible.lastIndexWhere((v) => v);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  appText(context, 'Generating schedule...'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          for (var i = 0; i < _steps.length; i++)
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: _visible[i]
                  ? _GeneratingStep(
                      icon: _steps[i].icon,
                      text: _steps[i].text,
                      isActive: i == lastVisible,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _GeneratingStep extends StatefulWidget {
  const _GeneratingStep({
    required this.icon,
    required this.text,
    required this.isActive,
  });

  final IconData icon;
  final String text;
  final bool isActive;

  @override
  State<_GeneratingStep> createState() => _GeneratingStepState();
}

class _GeneratingStepState extends State<_GeneratingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.isActive
                    ? Theme.of(context).colorScheme.primary
                    : _secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appText(context, widget.text),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isActive
                        ? Theme.of(context).colorScheme.primary
                        : _secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
