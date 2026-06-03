part of travel_agent_app;

class TripChatTab extends StatefulWidget {
  const TripChatTab({
    required this.trip,
    required this.onOpenChat,
    this.initialPrompt,
    super.key,
  });
  final Trip trip;
  final VoidCallback onOpenChat;
  final String? initialPrompt;

  @override
  State<TripChatTab> createState() => _TripChatTabState();
}

class _TripChatTabState extends State<TripChatTab> {
  final _assistant = TravelAssistantService();
  final _input = TextEditingController();
  final _messages = <_TripAiMessage>[];
  var _isSending = false;
  String? _error;
  String? _sentInitialPrompt;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _TripAiMessage(
        fromUser: false,
        text:
            'I can help run this trip day by day using your schedule, current time, and location when available.',
      ),
    );
    _sendInitialPrompt();
  }

  @override
  void didUpdateWidget(covariant TripChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrompt != widget.initialPrompt) {
      _sendInitialPrompt();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _sendInitialPrompt() {
    final prompt = widget.initialPrompt?.trim();
    if (prompt == null || prompt.isEmpty || prompt == _sentInitialPrompt) {
      return;
    }
    _sentInitialPrompt = prompt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_send(prompt));
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _tripRuntimePlan(widget.trip);
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(child: _RuntimeAssistantHeader(runtime: runtime)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Run today'),
              onPressed: _isSending
                  ? null
                  : () => unawaited(_send('Help me run today.')),
            ),
            ActionChip(
              avatar: const Icon(Icons.route_rounded, size: 18),
              label: const Text('Next step'),
              onPressed: _isSending
                  ? null
                  : () => unawaited(_send('What should I do next?')),
            ),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Adjust plan'),
              onPressed: _isSending
                  ? null
                  : () => unawaited(
                      _send('Suggest a realistic adjustment for today.'),
                    ),
            ),
            ActionChip(
              avatar: const Icon(Icons.groups_rounded, size: 18),
              label: const Text('Group chat'),
              onPressed: widget.onOpenChat,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          FormNotice(message: _error!),
          const SizedBox(height: 12),
        ],
        for (final message in _messages) ...[
          _TripAiBubble(message: message),
          const SizedBox(height: 10),
        ],
        if (_isSending) ...[
          const _TripAiThinkingBubble(),
          const SizedBox(height: 10),
        ],
        GlassPanel(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: appText(context, 'Ask about this trip'),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => unawaited(_send()),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSending ? null : () => unawaited(_send()),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _send([String? quickPrompt]) async {
    final text = (quickPrompt ?? _input.text).trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
      _messages.add(_TripAiMessage(fromUser: true, text: text));
    });
    _input.clear();
    try {
      final reply = await _assistant.sendMessage(_tripAwarePrompt(text));
      if (!mounted) return;
      setState(() {
        _messages.add(
          _TripAiMessage(
            fromUser: false,
            text: reply.isEmpty ? 'I could not generate a reply.' : reply,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _assistantErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _tripAwarePrompt(String userRequest) {
    final trip = widget.trip;
    final runtime = _tripRuntimePlan(trip);
    final todayItems = runtime.todaysItems
        .map((item) => '${item.time} ${item.activity}')
        .join('; ');
    final next = runtime.nextItem;
    return [
      'You are the live during-trip assistant for this itinerary.',
      'Use current local date, current local time, timezone, and location if available.',
      'Do not re-plan the whole trip unless asked; focus on what to do today and next.',
      'Destination: ${trip.destination}.',
      'Trip dates: ${trip.startDate} to ${trip.endDate}.',
      'Trip status: ${trip.status.name}.',
      'Runtime day: ${runtime.currentDay} of ${runtime.totalDays}.',
      'Today schedule: ${todayItems.isEmpty ? 'none' : todayItems}.',
      'Next scheduled activity: ${next == null ? 'none' : '${next.time} ${next.activity}'}.',
      'User request: $userRequest',
    ].join('\n');
  }
}

class _RuntimeAssistantHeader extends StatelessWidget {
  const _RuntimeAssistantHeader({required this.runtime});

  final _TripRuntimePlan runtime;

  @override
  Widget build(BuildContext context) {
    final next = runtime.nextItem;
    return Row(
      children: [
        const IconBadge(icon: Icons.auto_awesome_rounded, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${runtime.currentDay} assistant',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                next == null
                    ? 'No scheduled next stop right now.'
                    : 'Next: ${next.activity} at ${next.time}',
                style: const TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripAiBubble extends StatelessWidget {
  const _TripAiBubble({required this.message});

  final _TripAiMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * .78, 620),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: message.fromUser ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.fromUser ? Colors.white : _primary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripAiThinkingBubble extends StatelessWidget {
  const _TripAiThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: GlassPanel(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          'Thinking...',
          style: TextStyle(color: _primary, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _TripAiMessage {
  const _TripAiMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

String _assistantErrorMessage(Object error) {
  final text = error.toString();
  if (text.contains('timeout')) {
    return 'AI took too long to answer. Try again with a shorter request.';
  }
  return 'AI is unavailable right now.';
}
