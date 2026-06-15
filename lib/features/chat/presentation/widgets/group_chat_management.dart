part of travel_agent_app;

class GroupChatInfoPanel extends StatefulWidget {
  const GroupChatInfoPanel({
    required this.chatId,
    required this.accountId,
    required this.repository,
    required this.onAddMembers,
    required this.onOpenMedia,
    required this.onOpenTrip,
    super.key,
  });

  final String chatId;
  final String accountId;
  final GroupChatRepository repository;
  final VoidCallback onAddMembers;
  final VoidCallback onOpenMedia;
  final ValueChanged<String> onOpenTrip;

  @override
  State<GroupChatInfoPanel> createState() => _GroupChatInfoPanelState();
}

class _GroupChatInfoPanelState extends State<GroupChatInfoPanel> {
  String? _error;
  String? _busyMemberId;
  var _busyTrip = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupChat?>(
      stream: widget.repository.watchChat(widget.chatId),
      builder: (context, chatSnapshot) {
        final chat = chatSnapshot.data;
        if (chat == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final currentRole = chat.roles[widget.accountId];
        final canManage =
            currentRole == GroupChatRole.owner.name ||
            currentRole == GroupChatRole.admin.name;
        final isOwner = chat.ownerId == widget.accountId;
        return StreamBuilder<List<GroupChatMember>>(
          stream: widget.repository.watchMembers(widget.chatId),
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? const <GroupChatMember>[];
            return Column(
              children: [
                _SheetHeader(
                  title: 'Group info',
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: _responsivePagePadding(
                      context,
                      top: 8,
                      bottom: 28,
                    ),
                    children: [
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const IconBadge(
                                  icon: Icons.groups_rounded,
                                  size: 62,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chat.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      if (chat.description.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            chat.description,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _groupCreatedLabel(
                                          context,
                                          chat.createdAt,
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canManage)
                                  IconButton(
                                    tooltip: appText(
                                      context,
                                      'Edit group details',
                                    ),
                                    onPressed: () => _editGroupDetails(chat),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: widget.onAddMembers,
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                  ),
                                  label: Text(appText(context, 'Add members')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: widget.onOpenMedia,
                                  icon: const Icon(Icons.perm_media_outlined),
                                  label: Text(appText(context, 'Group media')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildAttachedTrip(chat, isOwner: isOwner),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        FormNotice(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: SectionHeader(title: 'Members'),
                          ),
                          Text(
                            '${members.length}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final member in members)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GroupMemberTile(
                            member: member,
                            canManage: canManage && !member.isOwner,
                            busy: _busyMemberId == member.uid,
                            onRoleSelected: (role) => _updateRole(member, role),
                            onRemove: () => _removeMember(member),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAttachedTrip(GroupChat chat, {required bool isOwner}) {
    final tripId = chat.linkedTripId?.trim();
    if (tripId == null || tripId.isEmpty) {
      return GlassPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'No trip attached'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  appText(
                    context,
                    'The group owner can attach one of their trips.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
            final attachButton = FilledButton.icon(
              onPressed: _busyTrip ? null : () => _chooseTrip(chat),
              icon: const Icon(Icons.add_link_rounded),
              label: Text(appText(context, 'Attach trip')),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  if (isOwner) ...[const SizedBox(height: 12), attachButton],
                ],
              );
            }
            return Row(
              children: [
                const IconBadge(icon: Icons.luggage_rounded, size: 50),
                const SizedBox(width: 12),
                Expanded(child: details),
                if (isOwner) ...[const SizedBox(width: 12), attachButton],
              ],
            );
          },
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: widget.repository.watchTripMembership(
        accountId: widget.accountId,
        tripId: tripId,
      ),
      builder: (context, snapshot) {
        final joined = snapshot.data == true;
        return GlassPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, 'Attached trip'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.linkedTripTitle?.trim().isNotEmpty == true
                        ? chat.linkedTripTitle!
                        : chat.linkedTripDestination ?? 'Trip',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (chat.linkedTripDestination?.trim().isNotEmpty == true)
                    Text(
                      chat.linkedTripDestination!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (joined)
                    FilledButton.icon(
                      onPressed: _busyTrip
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onOpenTrip(tripId);
                            },
                      icon: const Icon(Icons.visibility_rounded),
                      label: Text(appText(context, 'View trip')),
                    )
                  else
                    FilledButton.icon(
                      onPressed:
                          _busyTrip ||
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                          ? null
                          : () => _joinTrip(chat),
                      icon: const Icon(Icons.group_add_rounded),
                      label: Text(appText(context, 'Join trip')),
                    ),
                  if (isOwner)
                    OutlinedButton.icon(
                      onPressed: _busyTrip ? null : () => _chooseTrip(chat),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(appText(context, 'Replace trip')),
                    ),
                  if (isOwner)
                    OutlinedButton.icon(
                      onPressed: _busyTrip ? null : () => _detachTrip(chat),
                      icon: const Icon(Icons.link_off_rounded),
                      label: Text(appText(context, 'Detach trip')),
                    ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 14), actions],
                );
              }
              return Row(
                children: [
                  const IconBadge(icon: Icons.luggage_rounded, size: 54),
                  const SizedBox(width: 14),
                  Expanded(child: details),
                  const SizedBox(width: 14),
                  Flexible(child: actions),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _chooseTrip(GroupChat chat) async {
    if (_busyTrip) return;
    setState(() {
      _busyTrip = true;
      _error = null;
    });
    try {
      final trips = await widget.repository.loadOwnedTrips(widget.accountId);
      if (!mounted) return;
      if (trips.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(appText(context, 'No owned trips')),
            content: Text(
              appText(
                context,
                'Create or own a trip before attaching it to this group.',
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
      final selected = await showModalBottomSheet<ChatTripSummary>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              shrinkWrap: true,
              padding: _responsivePagePadding(context, top: 4, bottom: 24),
              children: [
                Text(
                  appText(
                    context,
                    chat.linkedTripId == null
                        ? 'Attach a trip'
                        : 'Replace attached trip',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                for (final trip in trips)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const IconBadge(
                      icon: Icons.flight_takeoff_rounded,
                      size: 44,
                    ),
                    title: Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      trip.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: chat.linkedTripId == trip.id
                        ? const Icon(Icons.check_circle_rounded)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(trip),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || selected.id == chat.linkedTripId) return;
      await widget.repository.setLinkedTrip(
        chatId: widget.chatId,
        accountId: widget.accountId,
        tripId: selected.id,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyTrip = false);
    }
  }

  Future<void> _detachTrip(GroupChat chat) async {
    if (_busyTrip || chat.linkedTripId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Detach trip?')),
        content: Text(
          appText(
            context,
            'Existing trip members will keep their access to the trip.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Detach')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyTrip = true;
      _error = null;
    });
    try {
      await widget.repository.setLinkedTrip(
        chatId: widget.chatId,
        accountId: widget.accountId,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyTrip = false);
    }
  }

  Future<void> _joinTrip(GroupChat chat) async {
    if (_busyTrip || chat.linkedTripId == null) return;
    setState(() {
      _busyTrip = true;
      _error = null;
    });
    try {
      await widget.repository.joinLinkedTrip(
        chatId: widget.chatId,
        accountId: widget.accountId,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyTrip = false);
    }
  }

  Future<void> _editGroupDetails(GroupChat chat) async {
    final title = TextEditingController(text: chat.title);
    final description = TextEditingController(text: chat.description);
    var saving = false;
    String? dialogError;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              if (saving) return;
              setDialogState(() {
                saving = true;
                dialogError = null;
              });
              try {
                await widget.repository.updateChatDetails(
                  chatId: widget.chatId,
                  actorId: widget.accountId,
                  title: title.text,
                  description: description.text,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                  dialogError = _chatErrorMessage(error);
                });
              }
            }

            return AlertDialog(
              title: Text(appText(dialogContext, 'Edit group details')),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: appText(dialogContext, 'Group title'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: description,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: appText(
                            dialogContext,
                            'Group description',
                          ),
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        FormNotice(message: dialogError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(appText(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(
                    appText(dialogContext, saving ? 'Saving...' : 'Save'),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      title.dispose();
      description.dispose();
    }
  }

  Future<void> _updateRole(GroupChatMember member, GroupChatRole role) async {
    if (_busyMemberId != null || member.role == role.name) return;
    setState(() {
      _busyMemberId = member.uid;
      _error = null;
    });
    try {
      await widget.repository.updateMemberRole(
        chatId: widget.chatId,
        actorId: widget.accountId,
        memberId: member.uid,
        role: role,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }

  Future<void> _removeMember(GroupChatMember member) async {
    if (_busyMemberId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Remove member?')),
        content: Text(
          '${member.displayNameSnapshot} ${appText(context, 'will no longer have access to this chat.')}',
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
      await widget.repository.removeMember(
        chatId: widget.chatId,
        actorId: widget.accountId,
        memberId: member.uid,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }
}

class GroupChatMediaPanel extends StatelessWidget {
  const GroupChatMediaPanel({
    required this.chatId,
    required this.repository,
    super.key,
  });

  final String chatId;
  final GroupChatRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupChatMessage>>(
      stream: repository.watchSharedContent(chatId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <GroupChatMessage>[];
        final media = <Map<String, dynamic>>[];
        final documents = <Map<String, dynamic>>[];
        final links = <Uri>[];
        for (final message in messages) {
          for (final attachment in message.attachments) {
            final type = attachment['type'];
            if (type == 'image' || type == 'gif' || type == 'video') {
              media.add(attachment);
            } else {
              documents.add(attachment);
            }
          }
          final link = _firstUrlIn(message.text);
          if (link != null) links.add(link);
        }

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _SheetHeader(
                title: 'Group media',
                onClose: () => Navigator.of(context).pop(),
              ),
              TabBar(
                tabs: [
                  Tab(text: appText(context, 'Media')),
                  Tab(text: appText(context, 'Files')),
                  Tab(text: appText(context, 'Links')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AttachmentCollection(
                      attachments: media,
                      emptyMessage: 'No photos, videos, or GIFs yet.',
                    ),
                    _AttachmentCollection(
                      attachments: documents,
                      emptyMessage: 'No files yet.',
                    ),
                    _LinkCollection(links: links),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttachmentCollection extends StatelessWidget {
  const _AttachmentCollection({
    required this.attachments,
    required this.emptyMessage,
  });

  final List<Map<String, dynamic>> attachments;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return _EmptyChatCollection(message: emptyMessage);
    }
    return ListView.separated(
      padding: _responsivePagePadding(context, top: 16, bottom: 28),
      itemCount: attachments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => GlassPanel(
        child: ChatAttachmentPreview(
          attachment: attachments[index],
          compact: true,
        ),
      ),
    );
  }
}

class _LinkCollection extends StatelessWidget {
  const _LinkCollection({required this.links});

  final List<Uri> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _EmptyChatCollection(message: 'No links yet.');
    }
    return ListView.separated(
      padding: _responsivePagePadding(context, top: 16, bottom: 28),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ChatLinkCard(uri: links[index]),
    );
  }
}

class _EmptyChatCollection extends StatelessWidget {
  const _EmptyChatCollection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: _responsivePagePadding(context),
        child: Text(
          appText(context, message),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GroupMemberTile extends StatelessWidget {
  const _GroupMemberTile({
    required this.member,
    required this.canManage,
    required this.busy,
    required this.onRoleSelected,
    required this.onRemove,
  });

  final GroupChatMember member;
  final bool canManage;
  final bool busy;
  final ValueChanged<GroupChatRole> onRoleSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                  member.displayNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  appText(context, _roleLabel(member.role)),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
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
          else if (canManage)
            PopupMenuButton<String>(
              tooltip: appText(context, 'Manage member'),
              onSelected: (value) {
                switch (value) {
                  case 'admin':
                    onRoleSelected(GroupChatRole.admin);
                  case 'member':
                    onRoleSelected(GroupChatRole.member);
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'admin',
                  enabled: member.role != GroupChatRole.admin.name,
                  child: Text(appText(context, 'Make admin')),
                ),
                PopupMenuItem(
                  value: 'member',
                  enabled: member.role != GroupChatRole.member.name,
                  child: Text(appText(context, 'Make member')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    appText(context, 'Remove member'),
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _responsiveHorizontalPadding(context),
          12,
          _responsiveHorizontalPadding(context),
          8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appText(context, title),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: appText(context, 'Close'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'owner' => 'Owner',
    'admin' => 'Admin',
    _ => 'Member',
  };
}

String _groupCreatedLabel(BuildContext context, Timestamp? createdAt) {
  if (createdAt == null) return appText(context, 'Creation date unavailable');
  final formatted = DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(createdAt.toDate().toLocal());
  return '${appText(context, 'Created')} $formatted';
}
