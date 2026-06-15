part of travel_agent_app;

enum _NotificationFilter {
  all('All notifications', Icons.inbox_rounded),
  important('Important only', Icons.priority_high_rounded),
  trips('Trips', Icons.luggage_rounded),
  itinerary('Itinerary', Icons.route_rounded),
  bookings('Bookings', Icons.confirmation_number_rounded),
  budget('Budget', Icons.account_balance_wallet_rounded),
  chat('Group chats', Icons.forum_rounded),
  checklist('Checklist', Icons.checklist_rounded),
  ai('Travel assistant', Icons.auto_awesome_rounded);

  const _NotificationFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _TravelNotificationType {
  trip(
    filter: _NotificationFilter.trips,
    label: 'Trip',
    icon: Icons.luggage_rounded,
    color: Color(0xFF4F6D8A),
  ),
  itinerary(
    filter: _NotificationFilter.itinerary,
    label: 'Itinerary',
    icon: Icons.route_rounded,
    color: Color(0xFF397B73),
  ),
  booking(
    filter: _NotificationFilter.bookings,
    label: 'Booking',
    icon: Icons.confirmation_number_rounded,
    color: Color(0xFF7C5B9D),
  ),
  budget(
    filter: _NotificationFilter.budget,
    label: 'Budget',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFFB0782D),
  ),
  chat(
    filter: _NotificationFilter.chat,
    label: 'Group chat',
    icon: Icons.forum_rounded,
    color: Color(0xFF3977A8),
  ),
  checklist(
    filter: _NotificationFilter.checklist,
    label: 'Checklist',
    icon: Icons.checklist_rounded,
    color: Color(0xFF5F7B45),
  ),
  ai(
    filter: _NotificationFilter.ai,
    label: 'Travel assistant',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF855F9E),
  );

  const _TravelNotificationType({
    required this.filter,
    required this.label,
    required this.icon,
    required this.color,
  });

  final _NotificationFilter filter;
  final String label;
  final IconData icon;
  final Color color;
}

class _TravelNotification {
  const _TravelNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.important = false,
    this.unread = false,
  });

  final String id;
  final String title;
  final String message;
  final String time;
  final _TravelNotificationType type;
  final bool important;
  final bool unread;
}

const _sampleNotifications = <_TravelNotification>[
  _TravelNotification(
    id: 'flight-gate-change',
    title: 'Your flight gate changed',
    message: 'JAL 402 now boards at Gate A7. Boarding begins in 35 minutes.',
    time: 'Just now',
    type: _TravelNotificationType.booking,
    important: true,
    unread: true,
  ),
  _TravelNotification(
    id: 'passport-check',
    title: 'Passport check before departure',
    message: 'Confirm your passport and travel documents are in your carry-on.',
    time: '12 min ago',
    type: _TravelNotificationType.checklist,
    important: true,
    unread: true,
  ),
  _TravelNotification(
    id: 'itinerary-time-update',
    title: 'Itinerary time updated',
    message: 'Fushimi Inari was moved to 8:30 AM to avoid the busiest period.',
    time: '40 min ago',
    type: _TravelNotificationType.itinerary,
    unread: true,
  ),
  _TravelNotification(
    id: 'maya-message',
    title: 'New message from Maya',
    message: 'Maya mentioned you in the Kyoto group chat.',
    time: '1 hr ago',
    type: _TravelNotificationType.chat,
    unread: true,
  ),
  _TravelNotification(
    id: 'booking-confirmed',
    title: 'Booking confirmed',
    message: 'Your stay at Sakura Terrace is confirmed for October 18.',
    time: '3 hrs ago',
    type: _TravelNotificationType.booking,
  ),
  _TravelNotification(
    id: 'daily-budget',
    title: 'Daily budget check',
    message: 'You have 8,400 JPY remaining in today\'s spending plan.',
    time: 'Yesterday',
    type: _TravelNotificationType.budget,
  ),
  _TravelNotification(
    id: 'packing-reminder',
    title: 'Packing list reminder',
    message: 'Three items are still unchecked for your upcoming trip.',
    time: 'Yesterday',
    type: _TravelNotificationType.checklist,
  ),
  _TravelNotification(
    id: 'smarter-route',
    title: 'A smarter route is ready',
    message: 'Your travel assistant found a shorter route for day two.',
    time: '2 days ago',
    type: _TravelNotificationType.ai,
  ),
  _TravelNotification(
    id: 'trip-starting',
    title: 'Kyoto trip starts soon',
    message: 'Your trip begins in three days. Review the latest plan.',
    time: '3 days ago',
    type: _TravelNotificationType.trip,
  ),
];

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.archivedNotificationIds,
    required this.onArchive,
    required this.onRestore,
    required this.onBack,
    super.key,
  });

  final Set<String> archivedNotificationIds;
  final ValueChanged<String> onArchive;
  final ValueChanged<String> onRestore;
  final VoidCallback onBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _filter = _NotificationFilter.all;
  var _filtersExpanded = false;
  var _showArchived = false;

  bool _matchesFilter(_TravelNotification notification) {
    return switch (_filter) {
      _NotificationFilter.all => true,
      _NotificationFilter.important => notification.important,
      _ => notification.type.filter == _filter,
    };
  }

  void _archive(_TravelNotification notification) {
    widget.onArchive(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appText(context, 'Notification archived')),
        action: SnackBarAction(
          label: appText(context, 'Undo'),
          onPressed: () => widget.onRestore(notification.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeNotifications = _sampleNotifications
        .where(
          (notification) =>
              !widget.archivedNotificationIds.contains(notification.id) &&
              _matchesFilter(notification),
        )
        .toList(growable: false);
    final archivedNotifications = _showArchived
        ? _sampleNotifications
              .where(
                (notification) =>
                    widget.archivedNotificationIds.contains(notification.id) &&
                    _matchesFilter(notification),
              )
              .toList(growable: false)
        : const <_TravelNotification>[];
    final important = activeNotifications
        .where((notification) => notification.important)
        .toList(growable: false);
    final routine = activeNotifications
        .where((notification) => !notification.important)
        .toList(growable: false);
    final visibleCount =
        activeNotifications.length + archivedNotifications.length;
    final unreadCount = activeNotifications
        .where((notification) => notification.unread)
        .length;

    return ScreenScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: _responsivePagePadding(context, top: 18, bottom: 40),
            children: [
              TopBar(title: 'Notifications', onBack: widget.onBack),
              const SizedBox(height: 18),
              _NotificationSummary(
                unreadCount: unreadCount,
                archivedCount: widget.archivedNotificationIds.length,
              ),
              const SizedBox(height: 12),
              _NotificationFilters(
                expanded: _filtersExpanded,
                selected: _filter,
                showArchived: _showArchived,
                visibleCount: visibleCount,
                onToggleExpanded: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                onSelected: (filter) => setState(() => _filter = filter),
                onShowArchivedChanged: (value) =>
                    setState(() => _showArchived = value),
              ),
              const SizedBox(height: 24),
              if (visibleCount == 0)
                _EmptyNotifications(showingArchived: _showArchived)
              else ...[
                if (important.isNotEmpty) ...[
                  const _NotificationSectionTitle(
                    title: 'Important',
                    subtitle: 'Time-sensitive updates',
                  ),
                  const SizedBox(height: 10),
                  for (final notification in important) ...[
                    _SwipeToArchive(
                      notification: notification,
                      onArchive: () => _archive(notification),
                      child: _NotificationCard(notification: notification),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (routine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const _NotificationSectionTitle(
                    title: 'Updates',
                    subtitle: 'Swipe right to archive',
                  ),
                  const SizedBox(height: 10),
                  for (final notification in routine) ...[
                    _SwipeToArchive(
                      notification: notification,
                      onArchive: () => _archive(notification),
                      child: _NotificationCard(notification: notification),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (archivedNotifications.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _NotificationSectionTitle(
                    title: 'Archived',
                    subtitle: 'Stored for this session',
                  ),
                  const SizedBox(height: 10),
                  for (final notification in archivedNotifications) ...[
                    _NotificationCard(
                      notification: notification,
                      archived: true,
                      onRestore: () => widget.onRestore(notification.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.archivedCount,
  });

  final int unreadCount;
  final int archivedCount;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const IconBadge(icon: Icons.notifications_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, '$unreadCount unread'),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appText(
                    context,
                    archivedCount == 0
                        ? 'Keep travel changes in one place.'
                        : '$archivedCount archived for this session',
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

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
    required this.expanded,
    required this.selected,
    required this.showArchived,
    required this.visibleCount,
    required this.onToggleExpanded,
    required this.onSelected,
    required this.onShowArchivedChanged,
  });

  final bool expanded;
  final _NotificationFilter selected;
  final bool showArchived;
  final int visibleCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_NotificationFilter> onSelected;
  final ValueChanged<bool> onShowArchivedChanged;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appText(context, 'Filter'),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            appText(context, selected.label),
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
                    Text(
                      appText(context, '$visibleCount shown'),
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: settings.transitionDuration,
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: expanded ? 1 : 0,
              duration: settings.transitionDuration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: settings.transitionDuration,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(height: 1, color: Color(0xFFE7EDF1)),
                      const SizedBox(height: 14),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: appText(context, 'Notification type'),
                          prefixIcon: Icon(selected.icon),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_NotificationFilter>(
                            key: const ValueKey('notification-filter-dropdown'),
                            value: selected,
                            isExpanded: true,
                            items: [
                              for (final filter in _NotificationFilter.values)
                                DropdownMenuItem(
                                  value: filter,
                                  child: Text(appText(context, filter.label)),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) onSelected(value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile.adaptive(
                          key: const ValueKey('show-archived-toggle'),
                          contentPadding: EdgeInsets.zero,
                          value: showArchived,
                          onChanged: onShowArchivedChanged,
                          secondary: const Icon(
                            Icons.inventory_2_outlined,
                            color: _primary,
                          ),
                          title: Text(
                            appText(context, 'Show archived notifications'),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            appText(
                              context,
                              'Include archived items in this notification list.',
                            ),
                            style: const TextStyle(
                              color: _secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

class _NotificationSectionTitle extends StatelessWidget {
  const _NotificationSectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          appText(context, title),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            appText(context, subtitle),
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
    );
  }
}

class _SwipeToArchive extends StatelessWidget {
  const _SwipeToArchive({
    required this.notification,
    required this.onArchive,
    required this.child,
  });

  final _TravelNotification notification;
  final VoidCallback onArchive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('notification-${notification.id}'),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onArchive(),
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_rounded, color: Color(0xFF35634B)),
            const SizedBox(width: 8),
            Text(
              appText(context, 'Archive'),
              style: const TextStyle(
                color: Color(0xFF35634B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.notification,
    this.archived = false,
    this.onRestore,
  });

  final _TravelNotification notification;
  final bool archived;
  final VoidCallback? onRestore;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final settings = PerformanceScope.maybeSettingsOf(context);
    final fullHover =
        _hovered &&
        notification.important &&
        settings.motionLevel == MotionLevel.full;
    final subtleHover =
        _hovered &&
        notification.important &&
        settings.motionLevel == MotionLevel.reduced;
    const importantColor = Color(0xFFFFF7DF);
    const importantBorder = Color(0xFFE5B94F);

    return MouseRegion(
      onEnter: (_) {
        if (settings.animationsEnabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: settings.transitionDuration,
        curve: Curves.easeOutCubic,
        transform: fullHover
            ? Matrix4.translationValues(0, -3, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.important
              ? (subtleHover ? const Color(0xFFFFF2C8) : importantColor)
              : widget.archived
              ? const Color(0xFFF4F6F7)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.important
                ? importantBorder
                : const Color(0xFFE4E9EC),
            width: notification.important ? 1.5 : 1,
          ),
          boxShadow: [
            if (fullHover)
              BoxShadow(
                color: importantBorder.withValues(alpha: .24),
                blurRadius: 20,
                offset: const Offset(0, 9),
              )
            else
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: notification.important
                    ? const Color(0xFFFFE7A3)
                    : notification.type.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                notification.type.icon,
                color: notification.important
                    ? const Color(0xFF8B6415)
                    : notification.type.color,
                size: 23,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appText(context, notification.type.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: notification.important
                                ? const Color(0xFF8B6415)
                                : notification.type.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (notification.important)
                        const _ImportantLabel()
                      else if (notification.unread && !widget.archived)
                        const _UnreadDot(),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    appText(context, notification.title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    appText(context, notification.message),
                    style: TextStyle(
                      color: widget.archived
                          ? _secondary.withValues(alpha: .78)
                          : _secondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: _secondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          appText(context, notification.time),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.archived && widget.onRestore != null)
                        TextButton.icon(
                          onPressed: widget.onRestore,
                          icon: const Icon(Icons.unarchive_rounded, size: 18),
                          label: Text(appText(context, 'Restore')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportantLabel extends StatelessWidget {
  const _ImportantLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7A3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        appText(context, 'Important').toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF76520A),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: appText(context, 'Unread'),
      child: const SizedBox.square(
        dimension: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _secondary, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.showingArchived});

  final bool showingArchived;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      child: Column(
        children: [
          const IconBadge(icon: Icons.notifications_off_outlined, size: 54),
          const SizedBox(height: 14),
          Text(
            appText(
              context,
              showingArchived
                  ? 'No notifications match this filter'
                  : 'You are all caught up',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            appText(
              context,
              'Open the filter panel to change what appears here.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
