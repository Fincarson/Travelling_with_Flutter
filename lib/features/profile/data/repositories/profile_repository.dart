import '../../../auth/domain/entities/user_profile.dart';

class ProfileRepository {
  Future<UserProfile> loadCurrentProfile() async {
    await Future.delayed(const Duration(milliseconds: 350));

    return const UserProfile(
      displayName: 'User123',
      bio: '',
    );
  }
}
