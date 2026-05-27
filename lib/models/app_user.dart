class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.country,
    required this.city,
    this.isModerator = false,
    this.bio = '',
    this.avatarUrl,
  });

  final String uid;
  final String username;
  final String country;
  final String city;
  final bool isModerator;
  final String bio;
  final String? avatarUrl;
}

class ProfileDraft {
  const ProfileDraft({
    required this.username,
    required this.country,
    required this.city,
    this.bio = '',
    this.avatarUrl,
    this.avatarLocalPath,
  });

  final String username;
  final String country;
  final String city;
  final String bio;
  final String? avatarUrl;
  final String? avatarLocalPath;
}
