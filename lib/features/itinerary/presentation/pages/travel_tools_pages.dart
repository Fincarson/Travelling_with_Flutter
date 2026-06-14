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
          for (final item in trip.items.take(4))
            ScheduleTile(item: item, currency: trip.currency),
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
    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: _responsivePagePadding(context, top: 18, bottom: 40),
            children: [
              TopBar(title: 'Travel Info', onBack: onBack),
              const SizedBox(height: 18),
              const _TravelReadinessBanner(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Important notices',
                subtitle: 'Review before departure and again before entry.',
              ),
              const SizedBox(height: 12),
              const _TravelNoticeGrid(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Emergency contacts',
                subtitle: 'Japan example for the current Kyoto trip.',
              ),
              const SizedBox(height: 12),
              const _EmergencyContactsPanel(),
              const SizedBox(height: 24),
              const _InfoSectionTitle(
                title: 'Useful local details',
                subtitle: 'Practical reminders for the day.',
              ),
              const SizedBox(height: 12),
              const _LocalDetailsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelReadinessBanner extends StatelessWidget {
  const _TravelReadinessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0C979)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5AD),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.gpp_maybe_rounded,
              color: Color(0xFF8A5A00),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Check official requirements'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF684600),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(
                    context,
                    'Entry, visa, customs, and health rules can change. Confirm them with official authorities for your passport and travel dates.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF795B20),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _InfoSectionTitle extends StatelessWidget {
  const _InfoSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText(context, title),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          appText(context, subtitle),
          style: const TextStyle(
            color: _secondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TravelNoticeGrid extends StatelessWidget {
  const _TravelNoticeGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 680;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.badge_outlined,
                title: 'Entry and immigration',
                text:
                    'Verify passport validity, visa or visa-free eligibility, and permitted stay for your nationality.',
                tone: _NoticeTone.important,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.assignment_rounded,
                title: 'Arrival and customs',
                text:
                    'Keep accommodation and onward travel details available. Complete declarations and report controlled goods when required.',
                tone: _NoticeTone.warning,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.medical_services_outlined,
                title: 'Health and medication',
                text:
                    'Carry insurance details and prescriptions. Check destination rules before bringing medication across a border.',
                tone: _NoticeTone.neutral,
              ),
            ),
            SizedBox(
              width: width,
              child: const _TravelNoticeCard(
                icon: Icons.account_balance_rounded,
                title: 'Embassy or consulate',
                text:
                    'Save your nearest embassy or consulate contact before departure in case your passport is lost or stolen.',
                tone: _NoticeTone.neutral,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _NoticeTone { important, warning, neutral }

class _TravelNoticeCard extends StatelessWidget {
  const _TravelNoticeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (tone) {
      _NoticeTone.important => (
        const Color(0xFFFFF1F1),
        const Color(0xFFF1B5B5),
        const Color(0xFF9B3030),
      ),
      _NoticeTone.warning => (
        const Color(0xFFFFF8E8),
        const Color(0xFFF0D08E),
        const Color(0xFF8A5A00),
      ),
      _NoticeTone.neutral => (Colors.white, const Color(0xFFE4E9EC), _primary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: foreground, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, title),
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  appText(context, text),
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _EmergencyContactsPanel extends StatelessWidget {
  const _EmergencyContactsPanel();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _EmergencyContactRow(
            icon: Icons.local_police_outlined,
            label: 'Police',
            value: '110',
            detail: 'Emergency police assistance in Japan',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.local_fire_department_outlined,
            label: 'Fire and ambulance',
            value: '119',
            detail: 'Fire or urgent medical assistance in Japan',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.account_balance_outlined,
            label: 'Your embassy',
            value: 'Add contact',
            detail: 'Save the correct office for your nationality',
          ),
          Divider(height: 24, color: Color(0xFFE7EDF1)),
          _EmergencyContactRow(
            icon: Icons.health_and_safety_outlined,
            label: 'Travel insurer',
            value: 'Add policy',
            detail: 'Keep your assistance number and policy ID offline',
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appText(context, label),
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appText(context, detail),
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          appText(context, value),
          textAlign: TextAlign.end,
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _LocalDetailsGrid extends StatelessWidget {
  const _LocalDetailsGrid();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveSplit(
      breakpoint: 620,
      children: [
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
          text: 'Cash is still useful for markets and smaller local venues.',
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
      (total, item) => total + item.effectiveActual,
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
                '${_displayMoney(context, actual, trip.currency)} of '
                '${_displayMoney(context, trip.budget, trip.currency)}',
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
            actual: category.effectiveActual,
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
                  Builder(
                    builder: (context) {
                      final isAiAdded = _isAiChecklistItem(item);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item == group.items.first,
                        onChanged: (_) {},
                        activeColor: _primary,
                        title: Text(
                          appText(context, _checklistDisplayText(item)),
                          style: TextStyle(
                            color: isAiAdded ? const Color(0xFFB7791F) : null,
                            fontWeight: isAiAdded
                                ? FontWeight.w900
                                : FontWeight.w700,
                            backgroundColor: isAiAdded
                                ? const Color(0xFFFFF3BF)
                                : null,
                          ),
                        ),
                      );
                    },
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
