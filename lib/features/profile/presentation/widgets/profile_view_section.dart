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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePhotoButton.viewing(
          photoUrl: profile.photoUrl,
          onPressed: onPhotoPressed,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.bio,
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
