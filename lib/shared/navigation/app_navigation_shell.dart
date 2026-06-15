part of travel_agent_app;

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onSelect});
  final _NavTab tab;
  final ValueChanged<_NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFF3F6))),
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
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white, width: 4),
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
      ),
    );
  }
}
