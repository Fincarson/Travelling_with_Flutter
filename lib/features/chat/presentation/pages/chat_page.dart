part of travel_agent_app;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    required this.account,
    required this.user,
    this.onRoomOpenChanged,
    this.onOpenChat,
    this.onAppBarActionsChanged,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final ValueChanged<bool>? onRoomOpenChanged;
  final ValueChanged<String>? onOpenChat;
  final ValueChanged<ChatListAppBarActions?>? onAppBarActionsChanged;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _repository = GroupChatRepository(FirebaseFirestore.instance);
  GroupChat? _activeChat;
  GroupChatMembership? _activeMembership;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_syncPublicUser());
    _publishAppBarActions();
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user ||
        oldWidget.account.uid != widget.account.uid) {
      unawaited(_syncPublicUser());
    }
    if (oldWidget.onAppBarActionsChanged != widget.onAppBarActionsChanged) {
      _publishAppBarActions();
    }
  }

  @override
  void dispose() {
    widget.onAppBarActionsChanged?.call(null);
    super.dispose();
  }

  void _publishAppBarActions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAppBarActionsChanged?.call(
        ChatListAppBarActions(
          onReviewInvite: _reviewInviteCode,
          onCreateChat: _showCreateChatSheet,
        ),
      );
    });
  }

  Future<void> _syncPublicUser() async {
    try {
      await _repository.upsertPublicUser(
        account: widget.account,
        profile: widget.user,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not sync chat profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _activeChat;
    final membership = _activeMembership;
    if (chat != null && membership != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _closeActiveChat();
        },
        child: GroupChatRoomScreen(
          chat: chat,
          membership: membership,
          account: widget.account,
          user: widget.user,
          repository: _repository,
          onBack: _closeActiveChat,
        ),
      );
    }

    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 12, bottom: 112),
        children: [
          if (_error != null) ...[
            FormNotice(message: _error!),
            const SizedBox(height: 12),
          ],
          _PendingInvites(
            accountId: widget.account.uid,
            repository: _repository,
            onAccept: _acceptInvite,
            onDecline: _declineInvite,
          ),
          StreamBuilder<List<GroupChatMembership>>(
            stream: _repository.watchMemberships(widget.account.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final memberships =
                  snapshot.data?.where((item) => item.isActive).toList() ??
                  const <GroupChatMembership>[];
              if (memberships.isEmpty) {
                return GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(icon: Icons.forum_rounded, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        appText(context, 'No chats yet'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appText(context, 'Create a group to start messaging.'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final membership in memberships)
                    GroupChatPreview(
                      membership: membership,
                      onTap: () => _openChat(membership),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateChatSheet() async {
    final controller = TextEditingController();
    String? sheetError;
    var isCreating = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              if (isCreating) return;
              final navigator = Navigator.of(sheetContext);
              setSheetState(() {
                isCreating = true;
                sheetError = null;
              });
              try {
                final chat = await _repository.createChat(
                  accountId: widget.account.uid,
                  profile: widget.user,
                  title: controller.text,
                );
                if (!mounted) return;
                navigator.pop();
                _showChat(
                  chat,
                  GroupChatMembership(
                    chatId: chat.id,
                    role: GroupChatRole.owner.name,
                    status: GroupChatMemberStatus.active.name,
                    titleSnapshot: chat.title,
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                setSheetState(() {
                  isCreating = false;
                  sheetError = _chatErrorMessage(error);
                });
              }
            }

            return PopScope(
              canPop: !isCreating,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _responsiveHorizontalPadding(sheetContext),
                        8,
                        _responsiveHorizontalPadding(sheetContext),
                        MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    appText(sheetContext, 'Create chat'),
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                IconButton(
                                  tooltip: appText(sheetContext, 'Cancel'),
                                  onPressed: isCreating
                                      ? null
                                      : () => Navigator.of(sheetContext).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: appText(sheetContext, 'Group name'),
                                prefixIcon: const Icon(Icons.groups_rounded),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => unawaited(submit()),
                            ),
                            if (sheetError != null) ...[
                              const SizedBox(height: 12),
                              FormNotice(message: sheetError!),
                            ],
                            const SizedBox(height: 18),
                            PrimaryButton(
                              label: isCreating ? 'Creating...' : 'Create chat',
                              icon: isCreating
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_rounded,
                              onPressed: isCreating
                                  ? null
                                  : () => unawaited(submit()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openChat(GroupChatMembership membership) async {
    try {
      final chat = await _repository.loadChat(membership.chatId);
      if (!mounted) return;
      if (chat == null) {
        setState(() => _error = 'Chat was not found.');
        return;
      }
      _showChat(chat, membership);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    }
  }

  Future<void> _reviewInviteCode() async {
    final controller = TextEditingController();
    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _responsiveHorizontalPadding(context),
                  8,
                  _responsiveHorizontalPadding(context),
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appText(context, 'Accept invite'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: appText(context, 'Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: appText(
                          context,
                          'Invite link or group code',
                        ),
                        prefixIcon: const Icon(Icons.key_rounded),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          Navigator.of(context).pop(controller.text),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Continue',
                      icon: Icons.search_rounded,
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (code == null || code.trim().isEmpty) return;
      try {
        final result = await _repository.joinGroupByCode(code);
        if (!mounted) return;
        await _openJoinedGroup(result);
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'not-found' && error.code != 'invalid-argument') {
          rethrow;
        }
        final invite = await _repository.loadInvite(code);
        if (!mounted) return;
        await _showInviteReview(invite);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showInviteReview(GroupChatInvite invite) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Chat invite')),
        content: Text(
          '${invite.inviterNameSnapshot.isEmpty ? 'Someone' : invite.inviterNameSnapshot} invites you to "${invite.titleSnapshot}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Accept')),
          ),
        ],
      ),
    );
    if (accepted == true) await _acceptInvite(invite);
  }

  Future<void> _acceptInvite(GroupChatInvite invite) async {
    try {
      final chatId = await _repository.acceptInvite(
        inviteCode: invite.code,
        accountId: widget.account.uid,
        profile: widget.user,
      );
      final chat = await _repository.loadChat(chatId);
      if (!mounted) return;
      if (chat == null) {
        setState(() => _error = 'Chat was not found.');
        return;
      }
      _showChat(
        chat,
        GroupChatMembership(
          chatId: chatId,
          role: invite.role,
          status: GroupChatMemberStatus.active.name,
          titleSnapshot: chat.title,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    }
  }

  Future<void> _openJoinedGroup(GroupChatJoinResult result) async {
    final chat = await _repository.loadChat(result.chatId);
    if (!mounted) return;
    if (chat == null) {
      setState(() => _error = 'Chat was not found.');
      return;
    }
    _showChat(
      chat,
      GroupChatMembership(
        chatId: result.chatId,
        role: result.role,
        status: GroupChatMemberStatus.active.name,
        titleSnapshot: result.title,
      ),
    );
  }

  Future<void> _declineInvite(GroupChatInvite invite) async {
    try {
      await _repository.declineInvite(
        inviteCode: invite.code,
        accountId: widget.account.uid,
      );
      if (!mounted) return;
      setState(() => _error = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    }
  }

  void _showChat(GroupChat chat, GroupChatMembership membership) {
    final onOpenChat = widget.onOpenChat;
    if (onOpenChat != null) {
      onOpenChat(chat.id);
      return;
    }

    setState(() {
      _activeChat = chat;
      _activeMembership = membership;
      _error = null;
    });
    widget.onRoomOpenChanged?.call(true);
  }

  void _closeActiveChat() {
    setState(() {
      _activeChat = null;
      _activeMembership = null;
    });
    widget.onRoomOpenChanged?.call(false);
  }
}

class ChatListAppBarActions {
  const ChatListAppBarActions({
    required this.onReviewInvite,
    required this.onCreateChat,
  });

  final VoidCallback onReviewInvite;
  final VoidCallback onCreateChat;
}

class RoutedGroupChatRoomScreen extends StatefulWidget {
  const RoutedGroupChatRoomScreen({
    required this.chatId,
    required this.account,
    required this.user,
    required this.onBack,
    required this.onVisibilityChanged,
    super.key,
  });

  final String chatId;
  final AuthenticatedAccount account;
  final UserProfile user;
  final VoidCallback onBack;
  final ValueChanged<String?> onVisibilityChanged;

  @override
  State<RoutedGroupChatRoomScreen> createState() =>
      _RoutedGroupChatRoomScreenState();
}

class _RoutedGroupChatRoomScreenState extends State<RoutedGroupChatRoomScreen> {
  final _repository = GroupChatRepository(FirebaseFirestore.instance);
  late Future<_LoadedGroupChatRoom> _room;

  @override
  void initState() {
    super.initState();
    _room = _loadRoom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibilityChanged(widget.chatId);
    });
  }

  @override
  void didUpdateWidget(covariant RoutedGroupChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.account.uid != widget.account.uid) {
      _room = _loadRoom();
    }
    if (oldWidget.chatId != widget.chatId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVisibilityChanged(widget.chatId);
      });
    }
  }

  @override
  void dispose() {
    widget.onVisibilityChanged(null);
    super.dispose();
  }

  Future<_LoadedGroupChatRoom> _loadRoom() async {
    final chat = await _repository.loadChat(widget.chatId);
    if (chat == null) throw StateError('Chat was not found.');

    final membership = await _repository.loadMembership(
      accountId: widget.account.uid,
      chatId: widget.chatId,
    );
    if (membership == null || !membership.isActive) {
      throw StateError('You are not an active member of this chat.');
    }

    return _LoadedGroupChatRoom(chat: chat, membership: membership);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onBack();
      },
      child: FutureBuilder<_LoadedGroupChatRoom>(
        future: _room,
        builder: (context, snapshot) {
          final room = snapshot.data;
          if (room != null) {
            return GroupChatRoomScreen(
              chat: room.chat,
              membership: room.membership,
              account: widget.account,
              user: widget.user,
              repository: _repository,
              onBack: widget.onBack,
            );
          }

          if (snapshot.hasError) {
            return SimpleToolScreen(
              title: 'Chat',
              onBack: widget.onBack,
              children: [
                FormNotice(
                  message: _chatErrorMessage(
                    snapshot.error ?? 'Could not load chat.',
                  ),
                ),
              ],
            );
          }

          return const ScreenScaffold(
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

class _LoadedGroupChatRoom {
  const _LoadedGroupChatRoom({required this.chat, required this.membership});

  final GroupChat chat;
  final GroupChatMembership membership;
}

class GroupChatRoomScreen extends StatefulWidget {
  const GroupChatRoomScreen({
    required this.chat,
    required this.membership,
    required this.account,
    required this.user,
    required this.repository,
    required this.onBack,
    super.key,
  });

  final GroupChat chat;
  final GroupChatMembership membership;
  final AuthenticatedAccount account;
  final UserProfile user;
  final GroupChatRepository repository;
  final VoidCallback onBack;

  @override
  State<GroupChatRoomScreen> createState() => _GroupChatRoomScreenState();
}

class _GroupChatRoomScreenState extends State<GroupChatRoomScreen> {
  final _input = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _attachmentService = ChatAttachmentService();
  late String _chatTitle;
  late GroupChatMembership _membership;
  var _isSending = false;
  var _isSendingAttachment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.chat.title;
    _membership = widget.membership;
    _inputFocusNode.addListener(_refreshComposer);
  }

  @override
  void didUpdateWidget(covariant GroupChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _chatTitle = widget.chat.title;
      _membership = widget.membership;
    }
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_refreshComposer);
    _input.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshComposer() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: _responsivePagePadding(context, top: 18, bottom: 8),
            child: TopBar(
              title: _chatTitle,
              onBack: widget.onBack,
              action: Icons.more_vert_rounded,
              onAction: _showGroupMenu,
            ),
          ),
          if (_error != null)
            Padding(
              padding: _responsivePagePadding(context, top: 0, bottom: 8),
              child: FormNotice(message: _error!),
            ),
          Expanded(
            child: StreamBuilder<List<GroupChatMessage>>(
              stream: widget.repository.watchMessages(widget.chat.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <GroupChatMessage>[];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (!_scrollController.hasClients) return;
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                  );
                });
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: _responsivePagePadding(context),
                      child: GlassPanel(
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.chat_bubble_outline_rounded,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                appText(context, 'Start the conversation.'),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: _responsivePagePadding(context, top: 12, bottom: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return GroupMessageBubble(
                      message: message,
                      isMine: message.senderId == widget.account.uid,
                      currentUserId: widget.account.uid,
                      pollVotes: message.poll == null
                          ? null
                          : widget.repository.watchPollVotes(
                              chatId: widget.chat.id,
                              messageId: message.id,
                            ),
                      onPollVote: message.poll == null
                          ? null
                          : (optionIndex) => widget.repository.voteInPoll(
                              chatId: widget.chat.id,
                              messageId: message.id,
                              accountId: widget.account.uid,
                              profile: widget.user,
                              optionIndex: optionIndex,
                            ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(context),
              8,
              _responsiveHorizontalPadding(context),
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: appText(context, 'Attach'),
                  onPressed: _isSending || _isSendingAttachment
                      ? null
                      : _showAttachmentMenu,
                  icon: _isSendingAttachment
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _inputFocusNode.hasFocus
                          ? null
                          : appText(context, 'Message'),
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    fixedSize: const Size(54, 54),
                  ),
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    _input.clear();
    try {
      await widget.repository.sendMessage(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
        profile: widget.user,
        senderPhotoUrl: widget.user.photoUrl ?? widget.account.photoUrl,
        text: text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showGroupMenu() async {
    final action = await showModalBottomSheet<_GroupChatMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: Text(appText(context, 'Add members')),
                onTap: () =>
                    Navigator.of(context).pop(_GroupChatMenuAction.addMembers),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(appText(context, 'Group info')),
                onTap: () =>
                    Navigator.of(context).pop(_GroupChatMenuAction.info),
              ),
              ListTile(
                leading: const Icon(Icons.perm_media_outlined),
                title: Text(appText(context, 'Group media')),
                onTap: () =>
                    Navigator.of(context).pop(_GroupChatMenuAction.media),
              ),
              ListTile(
                leading: Icon(
                  _membership.isMuted
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_outlined,
                ),
                title: Text(appText(context, 'Notifications')),
                subtitle: _membership.isMuted
                    ? Text(appText(context, 'Muted'))
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).pop(_GroupChatMenuAction.notifications),
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz_rounded),
                title: Text(appText(context, 'More')),
                onTap: () =>
                    Navigator.of(context).pop(_GroupChatMenuAction.more),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _GroupChatMenuAction.addMembers:
        await _showInviteSheet();
      case _GroupChatMenuAction.info:
        await _showGroupInfo();
      case _GroupChatMenuAction.media:
        await _showGroupMedia();
      case _GroupChatMenuAction.notifications:
        await _showNotificationOptions();
      case _GroupChatMenuAction.more:
        await _showMoreOptions();
    }
  }

  Future<void> _showGroupInfo() async {
    await _showFullHeightChatSheet(
      GroupChatInfoPanel(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
        repository: widget.repository,
        onAddMembers: () {
          Navigator.of(context).pop();
          Future<void>.delayed(Duration.zero, _showInviteSheet);
        },
        onOpenMedia: () {
          Navigator.of(context).pop();
          Future<void>.delayed(Duration.zero, _showGroupMedia);
        },
      ),
    );
    final chat = await widget.repository.loadChat(widget.chat.id);
    if (mounted && chat != null) {
      setState(() => _chatTitle = chat.title);
    }
  }

  Future<void> _showGroupMedia() {
    return _showFullHeightChatSheet(
      GroupChatMediaPanel(
        chatId: widget.chat.id,
        repository: widget.repository,
      ),
    );
  }

  Future<void> _showFullHeightChatSheet(Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: MediaQuery.sizeOf(context).height < 700 ? 1 : .92,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationOptions() async {
    final selected = await showModalBottomSheet<_ChatMuteChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: Text(appText(context, 'Unmute notifications')),
                onTap: () => Navigator.of(context).pop(_ChatMuteChoice.unmuted),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(appText(context, 'Mute for 30 minutes')),
                onTap: () =>
                    Navigator.of(context).pop(_ChatMuteChoice.thirtyMinutes),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(appText(context, 'Mute for 1 hour')),
                onTap: () => Navigator.of(context).pop(_ChatMuteChoice.oneHour),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(appText(context, 'Mute for 24 hours')),
                onTap: () => Navigator.of(context).pop(_ChatMuteChoice.oneDay),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_rounded),
                title: Text(appText(context, 'Mute forever')),
                onTap: () => Navigator.of(context).pop(_ChatMuteChoice.forever),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    try {
      final now = DateTime.now();
      final until = switch (selected) {
        _ChatMuteChoice.thirtyMinutes => now.add(const Duration(minutes: 30)),
        _ChatMuteChoice.oneHour => now.add(const Duration(hours: 1)),
        _ChatMuteChoice.oneDay => now.add(const Duration(days: 1)),
        _ => null,
      };
      await widget.repository.setMute(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
        until: until,
        forever: selected == _ChatMuteChoice.forever,
      );
      final membership = await widget.repository.loadMembership(
        accountId: widget.account.uid,
        chatId: widget.chat.id,
      );
      if (!mounted) return;
      if (membership != null) {
        setState(() => _membership = membership);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              selected == _ChatMuteChoice.unmuted
                  ? 'Chat notifications are on.'
                  : 'Chat notifications are muted.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    }
  }

  Future<void> _showMoreOptions() async {
    final action = await showModalBottomSheet<_ChatMoreAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(appText(context, 'Report')),
                onTap: () => Navigator.of(context).pop(_ChatMoreAction.report),
              ),
              ListTile(
                leading: Icon(
                  Icons.exit_to_app_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  appText(context, 'Exit chat'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop(_ChatMoreAction.exit),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ChatMoreAction.report) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(context, 'Report received. No data was submitted.'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Exit chat?')),
        content: Text(
          appText(
            context,
            'You will lose access until another member invites you again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appText(context, 'Exit')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.leaveChat(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
      );
      if (mounted) widget.onBack();
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    }
  }

  Future<void> _showAttachmentMenu() async {
    final action = await showModalBottomSheet<_ChatComposerAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _AttachmentSourceButton(
                icon: Icons.photo_camera_rounded,
                label: 'Camera',
                enabled: _attachmentService.cameraAvailable,
                onTap: () =>
                    Navigator.of(context).pop(_ChatComposerAction.camera),
              ),
              _AttachmentSourceButton(
                icon: Icons.photo_library_rounded,
                label: 'Photos',
                onTap: () =>
                    Navigator.of(context).pop(_ChatComposerAction.photos),
              ),
              _AttachmentSourceButton(
                icon: Icons.video_library_rounded,
                label: 'Videos',
                onTap: () =>
                    Navigator.of(context).pop(_ChatComposerAction.videos),
              ),
              _AttachmentSourceButton(
                icon: Icons.attach_file_rounded,
                label: 'Files',
                onTap: () =>
                    Navigator.of(context).pop(_ChatComposerAction.files),
              ),
              _AttachmentSourceButton(
                icon: Icons.poll_rounded,
                label: 'Poll',
                onTap: () =>
                    Navigator.of(context).pop(_ChatComposerAction.poll),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ChatComposerAction.poll) {
      await _showCreatePollSheet();
      return;
    }
    final source = switch (action) {
      _ChatComposerAction.camera => ChatAttachmentSource.camera,
      _ChatComposerAction.photos => ChatAttachmentSource.photos,
      _ChatComposerAction.videos => ChatAttachmentSource.videos,
      _ChatComposerAction.files => ChatAttachmentSource.files,
      _ChatComposerAction.poll => throw StateError(
        'Poll is not an attachment.',
      ),
    };
    setState(() {
      _isSendingAttachment = true;
      _error = null;
    });
    try {
      final settings = PerformanceScope.maybeSettingsOf(context);
      final attachment = await _attachmentService.pick(
        source: source,
        imageQuality: settings.imageQuality,
      );
      if (attachment == null) return;
      await widget.repository.sendAttachment(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
        profile: widget.user,
        senderPhotoUrl: widget.user.photoUrl ?? widget.account.photoUrl,
        attachment: attachment,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  Future<void> _showCreatePollSheet() async {
    final draft = await showModalBottomSheet<ChatPollDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CreatePollSheet(),
    );
    if (!mounted || draft == null) return;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.repository.sendPoll(
        chatId: widget.chat.id,
        accountId: widget.account.uid,
        profile: widget.user,
        senderPhotoUrl: widget.user.photoUrl ?? widget.account.photoUrl,
        draft: draft,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showInviteSheet() async {
    final controller = TextEditingController();
    String? sheetError;
    var isInviting = false;
    var isSharing = false;
    var isChangingCode = false;
    var codeFuture = widget.repository.getGroupJoinCode(chatId: widget.chat.id);
    final canChangeCode =
        _membership.role == GroupChatRole.owner.name ||
        _membership.role == GroupChatRole.admin.name;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> inviteUser() async {
              if (isInviting || isSharing || isChangingCode) return;
              final navigator = Navigator.of(sheetContext);
              setSheetState(() {
                isInviting = true;
                sheetError = null;
              });
              try {
                final invite = await widget.repository.inviteByUserInput(
                  chatId: widget.chat.id,
                  inviterId: widget.account.uid,
                  inviter: widget.user,
                  input: controller.text,
                );
                if (!mounted) return;
                navigator.pop();
                await _showShareInviteDialog(invite);
              } catch (error) {
                if (!mounted) return;
                setSheetState(() {
                  isInviting = false;
                  sheetError = _chatErrorMessage(error);
                });
              }
            }

            Future<void> shareLink() async {
              if (isInviting || isSharing || isChangingCode) return;
              final navigator = Navigator.of(sheetContext);
              setSheetState(() {
                isSharing = true;
                sheetError = null;
              });
              try {
                final invite = await widget.repository.createShareInvite(
                  chatId: widget.chat.id,
                  inviterId: widget.account.uid,
                  inviter: widget.user,
                );
                if (!mounted) return;
                navigator.pop();
                await _showShareInviteDialog(invite);
              } catch (error) {
                if (!mounted) return;
                setSheetState(() {
                  isSharing = false;
                  sheetError = _chatErrorMessage(error);
                });
              }
            }

            Future<void> changeCode() async {
              if (!canChangeCode || isInviting || isSharing || isChangingCode) {
                return;
              }
              final confirmed = await showDialog<bool>(
                context: sheetContext,
                builder: (dialogContext) => AlertDialog(
                  title: Text(appText(dialogContext, 'Change group code?')),
                  content: Text(
                    appText(
                      dialogContext,
                      'The current code will stop working immediately.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(appText(dialogContext, 'Cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(appText(dialogContext, 'Change code')),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !sheetContext.mounted) return;
              setSheetState(() {
                isChangingCode = true;
                sheetError = null;
              });
              try {
                final code = await widget.repository.getGroupJoinCode(
                  chatId: widget.chat.id,
                  regenerate: true,
                );
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  codeFuture = Future.value(code);
                  isChangingCode = false;
                });
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isChangingCode = false;
                  sheetError = _chatErrorMessage(error);
                });
              }
            }

            return PopScope(
              canPop: !isInviting && !isSharing && !isChangingCode,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _responsiveHorizontalPadding(sheetContext),
                        8,
                        _responsiveHorizontalPadding(sheetContext),
                        MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    appText(sheetContext, 'Invite'),
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                IconButton(
                                  tooltip: appText(sheetContext, 'Cancel'),
                                  onPressed:
                                      isInviting || isSharing || isChangingCode
                                      ? null
                                      : () => Navigator.of(sheetContext).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GlassPanel(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.key_rounded),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          appText(sheetContext, 'Group code'),
                                          style: Theme.of(sheetContext)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    appText(
                                      sheetContext,
                                      'Anyone signed in with this code can join as a member.',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(
                                        sheetContext,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FutureBuilder<String>(
                                    future: codeFuture,
                                    builder: (context, snapshot) {
                                      final code = snapshot.data;
                                      if (snapshot.hasError) {
                                        return FormNotice(
                                          message: _chatErrorMessage(
                                            snapshot.error ??
                                                'Could not load group code.',
                                          ),
                                        );
                                      }
                                      if (code == null) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SelectableText(
                                            code,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(sheetContext)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 2,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: isChangingCode
                                                    ? null
                                                    : () async {
                                                        await Clipboard.setData(
                                                          ClipboardData(
                                                            text: code,
                                                          ),
                                                        );
                                                        if (!sheetContext
                                                            .mounted) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger.of(
                                                          sheetContext,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              appText(
                                                                sheetContext,
                                                                'Code copied.',
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.copy_rounded,
                                                ),
                                                label: Text(
                                                  appText(
                                                    sheetContext,
                                                    'Copy code',
                                                  ),
                                                ),
                                              ),
                                              if (canChangeCode)
                                                OutlinedButton.icon(
                                                  onPressed: isChangingCode
                                                      ? null
                                                      : () => unawaited(
                                                          changeCode(),
                                                        ),
                                                  icon: isChangingCode
                                                      ? const SizedBox.square(
                                                          dimension: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons.refresh_rounded,
                                                        ),
                                                  label: Text(
                                                    appText(
                                                      sheetContext,
                                                      'Change code',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: appText(
                                  sheetContext,
                                  'User ID or email',
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_search_rounded,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => unawaited(inviteUser()),
                            ),
                            if (sheetError != null) ...[
                              const SizedBox(height: 12),
                              FormNotice(message: sheetError!),
                            ],
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: isInviting ? 'Inviting...' : 'Invite user',
                              icon: isInviting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.person_add_rounded,
                              onPressed:
                                  isInviting || isSharing || isChangingCode
                                  ? null
                                  : () => unawaited(inviteUser()),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  isInviting || isSharing || isChangingCode
                                  ? null
                                  : () => unawaited(shareLink()),
                              icon: isSharing
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.ios_share_rounded),
                              label: Text(
                                appText(
                                  sheetContext,
                                  isSharing ? 'Creating link...' : 'Share link',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showShareInviteDialog(GroupChatInvite invite) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Invite link')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(invite.link),
            const SizedBox(height: 10),
            SelectableText('${appText(context, 'Code')}: ${invite.code}'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.link));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(appText(context, 'Invite copied.'))),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(appText(context, 'Copy')),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: 'Join ${invite.titleSnapshot}: ${invite.link}',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(appText(context, 'Invite copied.'))),
              );
            },
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(appText(context, 'Share')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appText(context, 'Done')),
          ),
        ],
      ),
    );
  }
}

enum _GroupChatMenuAction { addMembers, info, media, notifications, more }

enum _ChatMuteChoice { unmuted, thirtyMinutes, oneHour, oneDay, forever }

enum _ChatMoreAction { report, exit }

enum _ChatComposerAction { camera, photos, videos, files, poll }

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    final controller = _options.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  void _createPoll() {
    final question = _question.text.trim();
    final options = _options
        .map((controller) => controller.text.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    if (question.isEmpty) {
      setState(() => _error = 'Enter a poll question.');
      return;
    }
    if (options.length < 2) {
      setState(() => _error = 'Enter at least two poll options.');
      return;
    }
    if (options.toSet().length != options.length) {
      setState(() => _error = 'Poll options must be different.');
      return;
    }
    Navigator.of(
      context,
    ).pop(ChatPollDraft(question: question, options: options));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  appText(context, 'Create poll'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _question,
                  autofocus: true,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Question'),
                  ),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < _options.length; index++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _options[index],
                          maxLength: 120,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText:
                                '${appText(context, 'Option')} ${index + 1}',
                          ),
                        ),
                      ),
                      if (_options.length > 2) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: appText(context, 'Remove option'),
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (_options.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(appText(context, 'Add option')),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  FormNotice(message: _error!),
                ],
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(appText(context, 'Cancel')),
                    ),
                    FilledButton.icon(
                      onPressed: _createPoll,
                      icon: const Icon(Icons.poll_rounded),
                      label: Text(appText(context, 'Create poll')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentSourceButton extends StatelessWidget {
  const _AttachmentSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 8),
              Text(
                appText(context, label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: enabled ? null : Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingInvites extends StatelessWidget {
  const _PendingInvites({
    required this.accountId,
    required this.repository,
    required this.onAccept,
    required this.onDecline,
  });

  final String accountId;
  final GroupChatRepository repository;
  final ValueChanged<GroupChatInvite> onAccept;
  final ValueChanged<GroupChatInvite> onDecline;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupChatInvite>>(
      stream: repository.watchPendingInvites(accountId),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const <GroupChatInvite>[];
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final invite in invites)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(
                            icon: Icons.mark_email_unread_rounded,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '"${invite.titleSnapshot}"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ResponsiveSplit(
                        breakpoint: 430,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => onDecline(invite),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(appText(context, 'Cancel')),
                          ),
                          FilledButton.icon(
                            onPressed: () => onAccept(invite),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(appText(context, 'Accept')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _chatErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthorized'
          when error.plugin == 'firebase_storage' =>
        'Firebase Storage denied the file upload. Reopen the chat and try again.',
      'permission-denied' || 'unauthorized' =>
        'Firebase denied the chat update. Refresh the chat and try again.',
      'object-not-found' => 'The uploaded file could not be found.',
      'canceled' => 'The upload was canceled.',
      'retry-limit-exceeded' =>
        'The upload timed out. Check your connection and try again.',
      'network-request-failed' || 'unavailable' =>
        'The network is unavailable. Check your connection and try again.',
      _ =>
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Firebase could not complete this action.',
    };
  }
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('[cloud_firestore/permission-denied] ', '')
      .trim();
}
