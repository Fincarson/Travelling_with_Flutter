part of travel_agent_app;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.account,
    required this.user,
    this.trips = const [],
    this.memories = const [],
    this.onOpenTrip,
    this.onToggleFavoriteTrip,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final List<Trip> trips;
  final List<TripMemory> memories;
  final ValueChanged<Trip>? onOpenTrip;
  final ValueChanged<Trip>? onToggleFavoriteTrip;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl?.trim().isNotEmpty == true
        ? user.photoUrl
        : account.photoUrl;
    final displayName = user.name.trim().isNotEmpty ? user.name : account.name;
    final favoriteTrips = trips
        .where((trip) => user.favoriteTripIds.contains(trip.id))
        .toList();
    final favoriteMemories = memories
        .where((memory) => user.favoriteTripIds.contains(memory.id))
        .toList();

    return ScreenScaffold(
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
          const SizedBox(height: 18),
          _ProfileCollection(
            title: 'Favorite places',
            icon: Icons.favorite_rounded,
            emptyMessage: 'Places you like will appear here.',
            children: [
              for (final place in user.favoritePlaces)
                _FavoritePlaceTile(place: place),
            ],
          ),
          const SizedBox(height: 18),
          _ProfileCollection(
            title: 'Favorite trips',
            icon: Icons.luggage_rounded,
            emptyMessage: 'Favorite an upcoming or past trip to keep it here.',
            children: [
              for (final trip in favoriteTrips)
                _FavoriteTripTile(
                  title: trip.destination,
                  subtitle: '${trip.startDate} to ${trip.endDate}',
                  imageUrl: trip.images.isEmpty
                      ? destinations.first.image
                      : trip.images.first,
                  onTap: onOpenTrip == null ? null : () => onOpenTrip!(trip),
                  onRemove: onToggleFavoriteTrip == null
                      ? null
                      : () => onToggleFavoriteTrip!(trip),
                ),
              for (final memory in favoriteMemories)
                _FavoriteTripTile(
                  title: memory.title,
                  subtitle: memory.rating == null
                      ? 'Past trip'
                      : 'Past trip · ${memory.rating}/5 stars',
                  imageUrl: memory.imageUrls.isEmpty
                      ? destinations.first.image
                      : memory.imageUrls.first,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCollection extends StatelessWidget {
  const _ProfileCollection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _FavoritePlaceTile extends StatelessWidget {
  const _FavoritePlaceTile({required this.place});

  final FavoritePlace place;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          place.imageUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFFE6F1F8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.place_rounded, color: _primary),
            ),
          ),
        ),
      ),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        place.tags.take(2).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FavoriteTripTile extends StatelessWidget {
  const _FavoriteTripTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.onTap,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFFE6F1F8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.luggage_rounded, color: _primary),
            ),
          ),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove from favorites',
              onPressed: onRemove,
              icon: const Icon(Icons.favorite_rounded, color: _primary),
            ),
    );
  }
}
