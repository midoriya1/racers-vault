class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.country,
    required this.city,
    this.isModerator = false,
    this.bio = '',
    this.avatarUrl,
    this.trustScore = 70,
    this.trustStrikes = 0,
  });

  final String uid;
  final String username;
  final String country;
  final String city;
  final bool isModerator;
  final String bio;
  final String? avatarUrl;
  final int trustScore;
  final int trustStrikes;

  AppUser copyWith({
    String? uid,
    String? username,
    String? country,
    String? city,
    bool? isModerator,
    String? bio,
    String? avatarUrl,
    int? trustScore,
    int? trustStrikes,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      country: country ?? this.country,
      city: city ?? this.city,
      isModerator: isModerator ?? this.isModerator,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trustScore: trustScore ?? this.trustScore,
      trustStrikes: trustStrikes ?? this.trustStrikes,
    );
  }
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
