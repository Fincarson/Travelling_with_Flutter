import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/refreshable_page.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../data/repositories/profile_repository.dart';
import '../widgets/profile_edit_section.dart';
import '../widgets/profile_view_section.dart';

enum ProfileMode {
  viewing,
  editing,
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repository = ProfileRepository();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  ProfileMode _mode = ProfileMode.viewing;
  UserProfile _profile = const UserProfile(displayName: 'User123', bio: '');
  bool _isLoading = true;
  bool _isSyncingControllers = false;

  bool get _isEditing => _mode == ProfileMode.editing;

  bool get _hasChanges {
    return _displayNameController.text.trim() != _profile.displayName ||
        _bioController.text.trim() != _profile.bio;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _displayNameController.addListener(_handleProfileDraftChanged);
    _bioController.addListener(_handleProfileDraftChanged);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _repository.loadCurrentProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _isLoading = false;
      _syncControllersWithProfile();
    });
  }

  Future<void> _refreshProfile() async {
    final profile = await _repository.loadCurrentProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _mode = ProfileMode.viewing;
      _syncControllersWithProfile();
    });
  }

  void _syncControllersWithProfile() {
    _isSyncingControllers = true;
    _displayNameController.text = _profile.displayName;
    _bioController.text = _profile.bio;
    _isSyncingControllers = false;
  }

  void _handleProfileDraftChanged() {
    if (_isEditing && !_isSyncingControllers) {
      setState(() {});
    }
  }

  void _startEditing() {
    setState(() {
      _syncControllersWithProfile();
      _mode = ProfileMode.editing;
    });
  }

  Future<void> _handleBackFromEdit() async {
    if (!_hasChanges) {
      _discardChanges();
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;

        return AlertDialog(
          title: Text(l10n.saveChangesQuestion),
          content: Text(l10n.saveProfileChangesMessage),
          actions: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: l10n.yes,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.outlined(
                    text: l10n.no,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      _saveChanges();
    } else if (shouldSave == false) {
      _discardChanges();
    }
  }

  void _discardChanges() {
    setState(() {
      _mode = ProfileMode.viewing;
      _syncControllersWithProfile();
    });
  }

  void _saveChanges() {
    setState(() {
      _profile = _profile.copyWith(
        displayName: _displayNameController.text.trim().isEmpty
            ? 'User123'
            : _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      _mode = ProfileMode.viewing;
      _syncControllersWithProfile();
    });
  }

  void _showProfilePhoto() {
    final photoUrl = _profile.photoUrl;
    if (photoUrl == null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(32),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: CircleAvatar(
              radius: 132,
              backgroundImage: NetworkImage(photoUrl),
            ),
          ),
        );
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).pushNamed(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return RefreshablePage(
      onRefresh: _refreshProfile,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_isEditing)
                      IconButton(
                        tooltip: l10n.back,
                        onPressed: _handleBackFromEdit,
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const Spacer(),
                    if (!_isEditing)
                      IconButton(
                        tooltip: l10n.settings,
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isEditing)
                  ProfileEditSection(
                    profile: _profile,
                    displayNameController: _displayNameController,
                    bioController: _bioController,
                    onPhotoPressed: _showProfilePhoto,
                  )
                else
                  ProfileViewSection(
                    profile: _profile,
                    onPhotoPressed: _showProfilePhoto,
                  ),
                const SizedBox(height: 28),
                if (_isEditing)
                  AppButton(
                    text: l10n.confirm,
                    onPressed: _hasChanges ? _saveChanges : null,
                  )
                else
                  AppButton.outlined(
                    text: l10n.editProfile,
                    onPressed: _startEditing,
                  ),
              ],
            ),
    );
  }
}
