import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user_profile.dart';
import 'profile_photo_button.dart';

class ProfileViewSection extends StatelessWidget {
  const ProfileViewSection({
    super.key,
    required this.profile,
    required this.onPhotoPressed,
  });

  final UserProfile profile;
  final VoidCallback onPhotoPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final photo = ProfilePhotoButton.viewing(
          photoUrl: profile.photoUrl,
          onPressed: onPhotoPressed,
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                profile.bio,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ],
          ],
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [photo, const SizedBox(height: 16), details],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photo,
            const SizedBox(width: 16),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}
