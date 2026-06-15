part of travel_agent_app;

class _BottomNavController {
  const _BottomNavController({required this.tab, required this.onSelect});

  final _NavTab tab;
  final ValueChanged<_NavTab> onSelect;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onSelect});
  final _NavTab tab;
  final ValueChanged<_NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: tab == _NavTab.home,
              onTap: () => onSelect(_NavTab.home),
            ),
          ),
          Expanded(
            child: NavItem(
              icon: Icons.work_rounded,
              label: 'Trips',
              active: tab == _NavTab.trips,
              onTap: () => onSelect(_NavTab.trips),
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: FloatingActionButton(
                  heroTag: 'add-trip',
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: colorScheme.surfaceContainerLow,
                      width: 4,
                    ),
                  ),
                  onPressed: () => onSelect(_NavTab.add),
                  child: const Icon(Icons.add_rounded, size: 34),
                ),
              ),
            ),
          ),
          Expanded(
            child: NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              active: tab == _NavTab.chat,
              onTap: () => onSelect(_NavTab.chat),
            ),
          ),
          Expanded(
            child: NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              active: tab == _NavTab.profile,
              onTap: () => onSelect(_NavTab.profile),
            ),
          ),
        ],
      ),
    );
  }
}
