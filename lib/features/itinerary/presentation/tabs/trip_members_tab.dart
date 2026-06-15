part of travel_agent_app;

class TripMembersTab extends StatefulWidget {
  const TripMembersTab({
    required this.trip,
    required this.accountId,
    required this.repository,
    required this.onLeftTrip,
    super.key,
  });

  final Trip trip;
  final String accountId;
  final TravelDataRepository repository;
  final VoidCallback onLeftTrip;

  @override
  State<TripMembersTab> createState() => _TripMembersTabState();
}

class _TripMembersTabState extends State<TripMembersTab> {
  String? _busyMemberId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripMember>>(
      stream: widget.repository.watchTripMembers(widget.trip.id),
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <TripMember>[];
        return ListView(
          padding: _responsivePagePadding(context, top: 16, bottom: 112),
          children: [
            GlassPanel(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appText(context, 'Trip members'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appText(
                          context,
                          widget.trip.isOwner
                              ? 'You can remove members from this trip.'
                              : 'You have view-only access to this trip.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                  final count = SmallPill(
                    label: members.length == 1
                        ? '1 member'
                        : '${members.length} members',
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [details, const SizedBox(height: 12), count],
                    );
                  }
                  return Row(
                    children: [
                      const IconBadge(icon: Icons.groups_rounded, size: 52),
                      const SizedBox(width: 14),
                      Expanded(child: details),
                      count,
                    ],
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              FormNotice(message: _error!),
            ],
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (members.isEmpty)
              GlassPanel(
                child: Text(
                  appText(context, 'No trip members found.'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              for (final member in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripMemberCard(
                    member: member,
                    isCurrentUser: member.uid == widget.accountId,
                    canRemove:
                        widget.trip.isOwner &&
                        member.uid != widget.accountId &&
                        !member.isOwner,
                    busy: _busyMemberId == member.uid,
                    onRemove: () => _removeMember(member),
                  ),
                ),
            if (!widget.trip.isOwner) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busyMemberId == null ? _leaveTrip : null,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: Text(appText(context, 'Leave trip')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _removeMember(TripMember member) async {
    if (_busyMemberId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Remove trip member?')),
        content: Text(
          '${member.displayNameSnapshot} ${appText(context, 'will lose access to this trip but will remain in the group chat.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyMemberId = member.uid;
      _error = null;
    });
    try {
      await widget.repository.removeTripMember(
        tripId: widget.trip.id,
        memberId: member.uid,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }

  Future<void> _leaveTrip() async {
    if (_busyMemberId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Leave trip?')),
        content: Text(
          appText(
            context,
            'You will lose access to this trip but will remain in the group chat.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyMemberId = widget.accountId;
      _error = null;
    });
    try {
      await widget.repository.leaveTrip(widget.trip.id);
      if (mounted) widget.onLeftTrip();
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }
}

class _TripMemberCard extends StatelessWidget {
  const _TripMemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.canRemove,
    required this.busy,
    required this.onRemove,
  });

  final TripMember member;
  final bool isCurrentUser;
  final bool canRemove;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ChatAvatar(
            name: member.displayNameSnapshot,
            photoUrl: member.photoUrlSnapshot,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser
                      ? '${member.displayNameSnapshot} (${appText(context, 'You')})'
                      : member.displayNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  appText(context, member.isOwner ? 'Trip owner' : 'Viewer'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (canRemove)
            IconButton(
              tooltip: appText(context, 'Remove member'),
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_rounded),
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
    );
  }
}
