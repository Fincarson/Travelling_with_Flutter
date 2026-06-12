part of travel_agent_app;

enum _ArchiveSection {
  trips('Trips', Icons.luggage_rounded),
  chats('Group chats', Icons.forum_rounded),
  notifications('Notifications', Icons.notifications_rounded);

  const _ArchiveSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ArchivedItemsScreen extends StatefulWidget {
  const ArchivedItemsScreen({
    required this.tripMemories,
    required this.archivedNotificationIds,
    required this.onRestoreNotification,
    required this.onBack,
    super.key,
  });

  final List<TripMemory> tripMemories;
  final Set<String> archivedNotificationIds;
  final ValueChanged<String> onRestoreNotification;
  final VoidCallback onBack;

  @override
  State<ArchivedItemsScreen> createState() => _ArchivedItemsScreenState();
}

class _ArchivedItemsScreenState extends State<ArchivedItemsScreen> {
  var _section = _ArchiveSection.trips;

  @override
  Widget build(BuildContext context) {
    final archivedNotifications = _sampleNotifications
        .where(
          (notification) =>
              widget.archivedNotificationIds.contains(notification.id),
        )
        .toList(growable: false);

    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: _responsivePagePadding(context, top: 18, bottom: 40),
            children: [
              TopBar(title: 'Archived', onBack: widget.onBack),
              const SizedBox(height: 18),
              GlassPanel(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final section in _ArchiveSection.values)
                      ChoiceChip(
                        avatar: Icon(section.icon, size: 18),
                        label: Text(
                          appText(
                            context,
                            '${section.label} ${_countFor(section, archivedNotifications.length)}',
                          ),
                        ),
                        selected: _section == section,
                        selectedColor: _accent.withValues(alpha: .45),
                        backgroundColor: const Color(0xFFF7F9FA),
                        side: const BorderSide(color: Color(0xFFE4E9EC)),
                        labelStyle: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) => setState(() => _section = section),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              switch (_section) {
                _ArchiveSection.trips => _ArchivedTrips(
                  memories: widget.tripMemories,
                ),
                _ArchiveSection.chats => const _ArchiveEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No archived group chats',
                  message:
                      'Group chats you archive later will appear here for this session.',
                ),
                _ArchiveSection.notifications =>
                  archivedNotifications.isEmpty
                      ? const _ArchiveEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No archived notifications',
                          message:
                              'Swipe right on a notification to move it here.',
                        )
                      : Column(
                          children: [
                            for (final notification
                                in archivedNotifications) ...[
                              _NotificationCard(
                                notification: notification,
                                archived: true,
                                onRestore: () => widget.onRestoreNotification(
                                  notification.id,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
              },
            ],
          ),
        ),
      ),
    );
  }

  int _countFor(_ArchiveSection section, int notificationCount) {
    return switch (section) {
      _ArchiveSection.trips => widget.tripMemories.length,
      _ArchiveSection.chats => 0,
      _ArchiveSection.notifications => notificationCount,
    };
  }
}

class _ArchivedTrips extends StatelessWidget {
  const _ArchivedTrips({required this.memories});

  final List<TripMemory> memories;

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return const _ArchiveEmptyState(
        icon: Icons.luggage_outlined,
        title: 'No archived trips',
        message: 'Completed trip memories will appear here.',
      );
    }

    return Column(
      children: [
        for (final memory in memories) ...[
          _TripMemoryCard(memory: memory),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
      child: Column(
        children: [
          IconBadge(icon: icon, size: 54),
          const SizedBox(height: 14),
          Text(
            appText(context, title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appText(context, message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
