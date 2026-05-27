class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.country,
    required this.city,
    this.isModerator = false,
  });

  final String uid;
  final String username;
  final String country;
  final String city;
  final bool isModerator;
}

class ProfileDraft {
  const ProfileDraft({
    required this.username,
    required this.country,
    required this.city,
  });

  final String username;
  final String country;
  final String city;
}
