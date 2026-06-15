import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_extension.dart';

class ProfilePhotoButton extends StatelessWidget {
  const ProfilePhotoButton.viewing({
    super.key,
    required this.photoUrl,
    required this.onPressed,
  }) : isEditing = false;

  const ProfilePhotoButton.editing({
    super.key,
    required this.photoUrl,
    required this.onPressed,
  }) : isEditing = true;

  final String? photoUrl;
  final bool isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final hasPhoto = photoUrl != null;

    return Semantics(
      button: true,
      label: isEditing ? l10n.editProfilePhoto : l10n.viewProfilePhoto,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: hasPhoto || isEditing ? onPressed : null,
        child: CircleAvatar(
          radius: 42,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!hasPhoto && !isEditing)
                Icon(
                  Icons.person,
                  color: colorScheme.onSurfaceVariant,
                  size: 44,
                ),
              if (hasPhoto && isEditing)
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                ),
              if (isEditing)
                Icon(
                  Icons.edit,
                  color: hasPhoto ? Colors.white : colorScheme.primary,
                  size: 30,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
