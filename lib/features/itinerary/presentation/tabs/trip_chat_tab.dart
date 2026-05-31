part of travel_agent_app;

class TripChatTab extends StatelessWidget {
  const TripChatTab({required this.trip, required this.onOpenChat, super.key});
  final Trip trip;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16),
      children: [
        GlassPanel(
          child: Column(
            children: [
              const IconBadge(icon: Icons.chat_bubble_rounded, size: 54),
              const SizedBox(height: 12),
              Text(
                '${trip.destination} AI',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  'Ask for route changes, cheaper options, packing help, or booking reminders.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Open chat',
                icon: Icons.arrow_forward_rounded,
                onPressed: onOpenChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
