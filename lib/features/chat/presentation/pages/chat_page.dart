part of travel_agent_app;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    required this.account,
    required this.user,
    this.onRoomOpenChanged,
    this.onOpenChat,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final ValueChanged<bool>? onRoomOpenChanged;
  final ValueChanged<String>? onOpenChat;

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
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user ||
        oldWidget.account.uid != widget.account.uid) {
      unawaited(_syncPublicUser());
    }
  }

  @override
  void dispose() {
    widget.onRoomOpenChanged?.call(false);
    super.dispose();
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
        padding: _responsivePagePadding(context, top: 28, bottom: 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appText(context, 'Chat'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: appText(context, 'Accept invite'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primary,
                ),
                onPressed: _reviewInviteCode,
                icon: const Icon(Icons.link_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: appText(context, 'Create chat'),
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showCreateChatSheet,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                        style: const TextStyle(
                          color: _secondary,
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
                        labelText: appText(context, 'Invite link or code'),
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          Navigator.of(context).pop(controller.text),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Review invite',
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
      final invite = await _repository.loadInvite(code);
      if (!mounted) return;
      await _showInviteReview(invite);
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

class RoutedGroupChatRoomScreen extends StatefulWidget {
  const RoutedGroupChatRoomScreen({
    required this.chatId,
    required this.account,
    required this.user,
    required this.onBack,
    this.onRoomOpenChanged,
    super.key,
  });

  final String chatId;
  final AuthenticatedAccount account;
  final UserProfile user;
  final VoidCallback onBack;
  final ValueChanged<bool>? onRoomOpenChanged;

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
    widget.onRoomOpenChanged?.call(true);
    _room = _loadRoom();
  }

  @override
  void didUpdateWidget(covariant RoutedGroupChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.account.uid != widget.account.uid) {
      _room = _loadRoom();
    }
  }

  @override
  void dispose() {
    widget.onRoomOpenChanged?.call(false);
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
  var _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_refreshComposer);
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
              title: widget.chat.title,
              onBack: widget.onBack,
              action: Icons.person_add_alt_1_rounded,
              onAction: _showInviteSheet,
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
                                style: const TextStyle(
                                  color: _secondary,
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
                  itemBuilder: (context, index) => GroupMessageBubble(
                    message: messages[index],
                    isMine: messages[index].senderId == widget.account.uid,
                  ),
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
                        color: _secondary.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(54, 54),
                  ),
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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

  Future<void> _showInviteSheet() async {
    final controller = TextEditingController();
    String? sheetError;
    var isInviting = false;
    var isSharing = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> inviteUser() async {
              if (isInviting || isSharing) return;
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
              if (isInviting || isSharing) return;
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

            return PopScope(
              canPop: !isInviting && !isSharing,
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
                                  onPressed: isInviting || isSharing
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
                              onPressed: isInviting || isSharing
                                  ? null
                                  : () => unawaited(inviteUser()),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: isInviting || isSharing
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
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firebase blocked this action. Refresh the app and try again.';
  }
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('[cloud_firestore/permission-denied] ', '')
      .trim();
}
