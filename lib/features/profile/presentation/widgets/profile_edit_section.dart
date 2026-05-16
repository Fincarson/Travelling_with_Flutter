import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_extension.dart';
import '../../../auth/domain/entities/user_profile.dart';
import 'profile_photo_button.dart';

class ProfileEditSection extends StatelessWidget {
  const ProfileEditSection({
    super.key,
    required this.profile,
    required this.displayNameController,
    required this.bioController,
    required this.onPhotoPressed,
  });

  final UserProfile profile;
  final TextEditingController displayNameController;
  final TextEditingController bioController;
  final VoidCallback onPhotoPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePhotoButton.editing(
          photoUrl: profile.photoUrl,
          onPressed: onPhotoPressed,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: displayNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.displayName,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.bio,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
