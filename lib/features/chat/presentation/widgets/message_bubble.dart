part of travel_agent_app;

class GroupMessageBubble extends StatelessWidget {
  const GroupMessageBubble({
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.pollVotes,
    this.onPollVote,
    super.key,
  });

  final GroupChatMessage message;
  final bool isMine;
  final String currentUserId;
  final Stream<Map<String, int>>? pollVotes;
  final Future<void> Function(int optionIndex)? onPollVote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (message.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              appText(context, message.text),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    final maxBubbleWidth = math.min(
      360.0,
      MediaQuery.sizeOf(context).width * 0.72,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            ChatAvatar(
              name: message.senderNameSnapshot,
              photoUrl: message.senderPhotoUrlSnapshot,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        message.senderNameSnapshot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Container(
                    key: ValueKey('chat-message-bubble-${message.id}'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isMine
                          ? colors.primary
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 6),
                        bottomRight: Radius.circular(isMine ? 6 : 20),
                      ),
                      border: isMine
                          ? null
                          : Border.all(color: colors.outlineVariant),
                    ),
                    child: message.poll == null
                        ? ChatMessageContent(
                            message: message,
                            foregroundColor: isMine
                                ? colors.onPrimary
                                : colors.onSurface,
                          )
                        : ChatPollCard(
                            poll: message.poll!,
                            currentUserId: currentUserId,
                            votes:
                                pollVotes ??
                                Stream.value(const <String, int>{}),
                            foregroundColor: isMine
                                ? colors.onPrimary
                                : colors.onSurface,
                            onVote: onPollVote,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      _chatTimeLabel(message.createdAt),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            ChatAvatar(
              name: message.senderNameSnapshot,
              photoUrl: message.senderPhotoUrlSnapshot,
            ),
          ],
        ],
      ),
    );
  }
}

class ChatPollCard extends StatefulWidget {
  const ChatPollCard({
    required this.poll,
    required this.currentUserId,
    required this.votes,
    required this.foregroundColor,
    required this.onVote,
    super.key,
  });

  final ChatPoll poll;
  final String currentUserId;
  final Stream<Map<String, int>> votes;
  final Color foregroundColor;
  final Future<void> Function(int optionIndex)? onVote;

  @override
  State<ChatPollCard> createState() => _ChatPollCardState();
}

class _ChatPollCardState extends State<ChatPollCard> {
  var _isVoting = false;

  Future<void> _vote(int optionIndex) async {
    final onVote = widget.onVote;
    if (_isVoting || onVote == null) return;
    setState(() => _isVoting = true);
    try {
      await onVote(optionIndex);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: widget.votes,
      builder: (context, snapshot) {
        final votes = snapshot.data ?? const <String, int>{};
        final selectedOption = votes[widget.currentUserId];
        final counts = List<int>.filled(widget.poll.options.length, 0);
        for (final optionIndex in votes.values) {
          if (optionIndex >= 0 && optionIndex < counts.length) {
            counts[optionIndex]++;
          }
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.poll_rounded,
                    color: widget.foregroundColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.poll.question,
                      style: TextStyle(
                        color: widget.foregroundColor,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (
                var optionIndex = 0;
                optionIndex < widget.poll.options.length;
                optionIndex++
              ) ...[
                _PollOptionTile(
                  label: widget.poll.options[optionIndex],
                  votes: counts[optionIndex],
                  selected: selectedOption == optionIndex,
                  enabled: !_isVoting && widget.onVote != null,
                  foregroundColor: widget.foregroundColor,
                  onTap: () => _vote(optionIndex),
                ),
                if (optionIndex < widget.poll.options.length - 1)
                  const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              Text(
                appText(
                  context,
                  votes.length == 1 ? '1 vote' : '${votes.length} votes',
                ),
                style: TextStyle(
                  color: widget.foregroundColor.withValues(alpha: .8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.label,
    required this.votes,
    required this.selected,
    required this.enabled,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final int votes;
  final bool selected;
  final bool enabled;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $votes ${votes == 1 ? 'vote' : 'votes'}',
      child: Material(
        color: foregroundColor.withValues(alpha: selected ? .2 : .1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: foregroundColor,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    softWrap: true,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$votes',
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({required this.name, required this.photoUrl, super.key});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    final url = photoUrl?.trim();
    return ClipOval(
      child: SizedBox.square(
        dimension: 34,
        child: url == null || url.isEmpty
            ? _ChatAvatarFallback(name: name)
            : Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: settings.filterQuality,
                errorBuilder: (_, __, ___) => _ChatAvatarFallback(name: name),
              ),
      ),
    );
  }
}

class _ChatAvatarFallback extends StatelessWidget {
  const _ChatAvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.primaryContainer),
      child: Center(
        child: Text(
          _avatarInitial(name),
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _avatarInitial(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '?';
  return String.fromCharCodes([clean.runes.first]).toUpperCase();
}

class GroupChatPreview extends StatelessWidget {
  const GroupChatPreview({
    required this.membership,
    required this.onTap,
    super.key,
  });

  final GroupChatMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = membership.lastMessageText.trim().isEmpty
        ? appText(context, 'No messages yet')
        : membership.lastMessageText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            children: [
              const IconBadge(icon: Icons.groups_rounded, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            membership.titleSnapshot,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _chatTimeLabel(membership.lastMessageAt),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatPreview extends StatelessWidget {
  const ChatPreview({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            children: [
              IconBadge(icon: icon, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      appText(context, text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _chatTimeLabel(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final local = timestamp.toDate().toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
