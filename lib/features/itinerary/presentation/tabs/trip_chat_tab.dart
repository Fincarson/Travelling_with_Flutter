part of travel_agent_app;

class TripChatTab extends StatefulWidget {
  const TripChatTab({
    required this.trip,
    required this.accountId,
    required this.user,
    required this.onOpenChat,
    required this.onLinkedChatChanged,
    this.initialPrompt,
    super.key,
  });

  final Trip trip;
  final String accountId;
  final UserProfile user;
  final ValueChanged<String> onOpenChat;
  final ValueChanged<GroupChat> onLinkedChatChanged;
  final String? initialPrompt;

  @override
  State<TripChatTab> createState() => _TripChatTabState();
}

class _TripChatTabState extends State<TripChatTab> {
  final _repository = GroupChatRepository(FirebaseFirestore.instance);
  GroupChat? _linkedChat;
  var _busy = false;
  var _lookupInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncLinkedChatFromTrip();
  }

  @override
  void didUpdateWidget(covariant TripChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.linkedChatId != widget.trip.linkedChatId ||
        oldWidget.trip.linkedChatTitle != widget.trip.linkedChatTitle ||
        oldWidget.accountId != widget.accountId) {
      _syncLinkedChatFromTrip();
    }
  }

  void _syncLinkedChatFromTrip() {
    final linkedChatId = widget.trip.linkedChatId?.trim();
    if (linkedChatId != null && linkedChatId.isNotEmpty) {
      final linkedChatTitle = widget.trip.linkedChatTitle?.trim();
      _linkedChat = GroupChat(
        id: linkedChatId,
        title: linkedChatTitle != null && linkedChatTitle.isNotEmpty
            ? linkedChatTitle
            : _linkedChat?.id == linkedChatId
            ? _linkedChat!.title
            : 'Trip group chat',
        ownerId: '',
        memberIds: const [],
        roles: const {},
        linkedTripId: widget.trip.id,
      );
      return;
    }
    if (_linkedChat?.linkedTripId != widget.trip.id) {
      _linkedChat = null;
    }
    unawaited(_loadLinkedChatFromMemberships());
  }

  Future<void> _loadLinkedChatFromMemberships() async {
    if (_lookupInFlight ||
        widget.trip.linkedChatId?.trim().isNotEmpty == true) {
      return;
    }
    final tripId = widget.trip.id;
    _lookupInFlight = true;
    try {
      final chat = await _repository.loadLinkedChatForTrip(
        accountId: widget.accountId,
        tripId: tripId,
      );
      if (!mounted || widget.trip.id != tripId || chat == null) return;
      await _rememberLinkedChat(chat, persistTripSnapshot: true);
    } catch (_) {
      // The primary trip document remains the source of truth. This lookup only
      // recovers older chat-side-only links, so a failed lookup should stay quiet.
    } finally {
      if (mounted) setState(() => _lookupInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedChat = _linkedChat;
    final linkedChatId = linkedChat?.id ?? widget.trip.linkedChatId?.trim();
    final linkedChatTitle = linkedChat?.title ?? widget.trip.linkedChatTitle;
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        if (_error != null) ...[
          FormNotice(message: _error!),
          const SizedBox(height: 12),
        ],
        if (linkedChatId != null && linkedChatId.isNotEmpty)
          _LinkedTripChatCard(
            title: linkedChatTitle,
            busy: _busy,
            onOpen: () => widget.onOpenChat(linkedChatId),
          )
        else
          _NoLinkedTripChatCard(
            canManage: widget.trip.isOwner,
            busy: _busy,
            onCreate: () => unawaited(_createNewGroupChat()),
            onAttach: () => unawaited(_attachExistingGroup()),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _createNewGroupChat() async {
    if (_busy || !widget.trip.isOwner) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final title = widget.trip.title.trim().isEmpty
          ? '${widget.trip.destination} group chat'
          : '${widget.trip.title} group chat';
      final chat = await _repository.createChat(
        accountId: widget.accountId,
        profile: widget.user,
        title: title,
      );
      await _repository.setLinkedTrip(
        chatId: chat.id,
        accountId: widget.accountId,
        tripId: widget.trip.id,
      );
      await _rememberLinkedChat(chat, persistTripSnapshot: true);
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachExistingGroup() async {
    if (_busy || !widget.trip.isOwner) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final chats = await _repository.loadOwnedAttachableChats(
        accountId: widget.accountId,
        tripId: widget.trip.id,
      );
      if (!mounted) return;
      if (chats.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(appText(context, 'No available groups')),
            content: Text(
              appText(
                context,
                'Create a group or detach one from another trip first.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appText(context, 'OK')),
              ),
            ],
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<GroupChat>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                shrinkWrap: true,
                padding: _responsivePagePadding(context, top: 4, bottom: 24),
                children: [
                  Text(
                    appText(context, 'Attach existing group'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final chat in chats)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const IconBadge(
                        icon: Icons.forum_rounded,
                        size: 44,
                      ),
                      title: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        appText(context, 'Group chat'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(chat),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (selected == null) return;

      await _repository.setLinkedTrip(
        chatId: selected.id,
        accountId: widget.accountId,
        tripId: widget.trip.id,
      );
      await _rememberLinkedChat(selected, persistTripSnapshot: true);
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rememberLinkedChat(
    GroupChat chat, {
    required bool persistTripSnapshot,
  }) async {
    if (!mounted) return;
    setState(() {
      _linkedChat = chat;
      _error = null;
    });
    widget.onLinkedChatChanged(chat);
    if (!persistTripSnapshot) return;
    try {
      await _repository.setTripLinkedChatSnapshot(
        tripId: widget.trip.id,
        chat: chat,
      );
    } catch (_) {
      // The callable should already keep Firestore linked. This direct owner
      // snapshot write only helps when the app is talking to older functions.
    }
  }
}

class _LinkedTripChatCard extends StatelessWidget {
  const _LinkedTripChatCard({
    required this.title,
    required this.busy,
    required this.onOpen,
  });

  final String? title;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title?.trim();
    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cleanTitle == null || cleanTitle.isEmpty
                    ? 'Trip group chat'
                    : cleanTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                appText(context, 'Open the group chat attached to this trip.'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: busy ? null : onOpen,
            icon: const Icon(Icons.forum_rounded),
            label: Text(appText(context, 'Open group chat')),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IconBadge(icon: Icons.chat_bubble_rounded, size: 52),
                const SizedBox(height: 12),
                details,
                const SizedBox(height: 16),
                button,
              ],
            );
          }

          return Row(
            children: [
              const IconBadge(icon: Icons.chat_bubble_rounded, size: 52),
              const SizedBox(width: 14),
              Expanded(child: details),
              const SizedBox(width: 14),
              Flexible(child: button),
            ],
          );
        },
      ),
    );
  }
}

class _NoLinkedTripChatCard extends StatelessWidget {
  const _NoLinkedTripChatCard({
    required this.canManage,
    required this.busy,
    required this.onCreate,
    required this.onAttach,
  });

  final bool canManage;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This trip doesn't have a group chat attached yet.",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (!canManage) ...[
                const SizedBox(height: 6),
                Text(
                  appText(
                    context,
                    'Only the trip owner can attach a group chat.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: canManage && !busy ? onCreate : null,
                  icon: Icon(
                    busy ? Icons.hourglass_top_rounded : Icons.add_rounded,
                  ),
                  label: Text(
                    appText(
                      context,
                      busy ? 'Creating...' : 'CREATE NEW GROUP CHAT',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: canManage && !busy ? onAttach : null,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(
                    appText(context, 'ATTACH EXISTING GROUP CHAT'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
          final header = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const IconBadge(icon: Icons.forum_outlined, size: 52),
                    const SizedBox(height: 12),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const IconBadge(icon: Icons.forum_outlined, size: 52),
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, const SizedBox(height: 16), actions],
          );
        },
      ),
    );
  }
}
