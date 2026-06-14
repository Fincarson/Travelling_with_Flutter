part of travel_agent_app;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.account, required this.user, super.key});

  final AuthenticatedAccount account;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl?.trim().isNotEmpty == true
        ? user.photoUrl
        : account.photoUrl;
    final displayName = user.name.trim().isNotEmpty ? user.name : account.name;

    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: _responsivePagePadding(context, top: 22, bottom: 112),
        children: [
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final avatar = CircleAvatar(
                radius: 46,
                backgroundColor: _accent.withValues(alpha: .35),
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: _primary,
                      )
                    : null,
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    account.contactLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [avatar, const SizedBox(height: 16), details],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: 18),
                  Expanded(child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'Travel interests'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (user.interests.isEmpty)
                  Text(
                    appText(context, 'No interests added yet.'),
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final interest in user.interests)
                        Chip(
                          label: Text(appText(context, interest)),
                          avatar: const Icon(Icons.explore_rounded, size: 18),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
