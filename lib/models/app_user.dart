class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.country,
    required this.city,
  });

  final String uid;
  final String username;
  final String country;
  final String city;
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
