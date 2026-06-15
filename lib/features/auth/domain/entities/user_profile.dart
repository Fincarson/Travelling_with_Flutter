class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.bio,
    this.photoUrl,
  });

  final String displayName;
  final String bio;
  final String? photoUrl;

  UserProfile copyWith({String? displayName, String? bio, String? photoUrl}) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
