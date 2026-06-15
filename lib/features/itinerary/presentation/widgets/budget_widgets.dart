part of travel_agent_app;

class BudgetBar extends StatelessWidget {
  const BudgetBar({
    required this.name,
    required this.planned,
    required this.actual,
    required this.currency,
    required this.color,
    super.key,
  });
  final String name;
  final int planned;
  final int actual;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Category names may be custom user data; translate only
                  // known app labels.
                  appText(context, name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Flexible(
                child: Text(
                  '${_displayMoney(context, actual, currency)} / '
                  '${_displayMoney(context, planned, currency)}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: planned == 0 ? 0 : (actual / planned).clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: color.withValues(alpha: .18),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 28),
          const SizedBox(height: 4),
          Text(
            appText(context, label).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _secondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniAction extends StatelessWidget {
  const MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        child: Column(
          children: [
            Icon(icon, color: _primary),
            const SizedBox(height: 6),
            Text(
              appText(context, label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
