part of travel_agent_app;

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({required this.trips, required this.onOpen, super.key});
  final List<Trip> trips;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 28, bottom: 112),
        children: [
          Text(
            appText(context, 'Chat'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          ChatPreview(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Travel Agent',
            text: 'Ask for routes, food, bookings, packing, or swaps.',
            onTap: () => onOpen('What should I do next in Kyoto?'),
          ),
          ChatPreview(
            icon: Icons.groups_rounded,
            title: 'Kyoto Group',
            text: 'Vote on lunch and share plan changes with friends.',
            onTap: () => onOpen('Start a group vote for lunch.'),
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    required this.initialQuery,
    required this.onBack,
    super.key,
  });
  final String initialQuery;
  final VoidCallback onBack;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late final List<ChatMessageModel> _messages;
  final _assistant = TravelAssistantService();
  final _input = TextEditingController();
  var _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      const ChatMessageModel(
        false,
        "AI Agent active. I can optimize routes, compare ideas, and turn chat into schedule changes.",
      ),
      if (widget.initialQuery.isNotEmpty)
        ChatMessageModel(true, widget.initialQuery),
    ];
    if (widget.initialQuery.isNotEmpty) {
      unawaited(_sendToAssistant(widget.initialQuery, addUserMessage: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: _responsivePagePadding(context, top: 18, bottom: 8),
            child: TopBar(title: 'AI Travel Agent', onBack: widget.onBack),
          ),
          Expanded(
            child: ListView.builder(
              padding: _responsivePagePadding(context, top: 12, bottom: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  MessageBubble(message: _messages[index]),
            ),
          ),
          Padding(
            padding: _responsivePagePadding(context, top: 8, bottom: 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: appText(
                        context,
                        'Ask about Kyoto, budgets, packing...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(54, 54),
                  ),
                  onPressed: _isSending
                      ? null
                      : () {
                          final text = _input.text.trim();
                          if (text.isEmpty) return;
                          _input.clear();
                          unawaited(_sendToAssistant(text));
                        },
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

  Future<void> _sendToAssistant(
    String text, {
    bool addUserMessage = true,
  }) async {
    setState(() {
      if (addUserMessage) _messages.add(ChatMessageModel(true, text));
      _isSending = true;
    });

    try {
      final reply = await _assistant.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessageModel(
            false,
            reply.isEmpty
                ? 'I could not generate a travel suggestion right now.'
                : reply,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const ChatMessageModel(
            false,
            'AI chat is unavailable right now. Please try again in a moment.',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class ChatMessageModel {
  const ChatMessageModel(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}
