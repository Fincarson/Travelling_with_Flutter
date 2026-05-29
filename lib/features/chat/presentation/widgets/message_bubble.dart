part of travel_agent_app;

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      360.0,
      MediaQuery.sizeOf(context).width * 0.82,
    );
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.fromUser ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: message.fromUser
              ? null
              : Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Text(
          message.fromUser ? message.text : appText(context, message.text),
          style: TextStyle(
            color: message.fromUser ? Colors.white : _primary,
            fontWeight: FontWeight.w700,
            height: 1.35,
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
