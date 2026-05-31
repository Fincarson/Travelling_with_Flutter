part of travel_agent_app;

class GroupMessageBubble extends StatelessWidget {
  const GroupMessageBubble({
    required this.message,
    required this.isMine,
    super.key,
  });

  final GroupChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
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
                        style: const TextStyle(
                          color: _secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isMine ? _primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 6),
                        bottomRight: Radius.circular(isMine ? 6 : 20),
                      ),
                      border: isMine
                          ? null
                          : Border.all(color: const Color(0xFFEFF3F6)),
                    ),
                    child: Text(
                      message.text,
                      softWrap: true,
                      style: TextStyle(
                        color: isMine ? Colors.white : _primary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      _chatTimeLabel(message.createdAt),
                      style: const TextStyle(
                        color: _secondary,
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
    return DecoratedBox(
      decoration: BoxDecoration(color: _accent.withValues(alpha: .35)),
      child: Center(
        child: Text(
          _avatarInitial(name),
          style: const TextStyle(
            color: _primary,
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
                          style: const TextStyle(
                            color: _secondary,
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
                      style: const TextStyle(
                        color: _secondary,
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
                      style: const TextStyle(
                        color: _secondary,
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
