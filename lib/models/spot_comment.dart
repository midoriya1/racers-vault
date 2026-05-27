class SpotComment {
  const SpotComment({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.username,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String spotId;
  final String userId;
  final String username;
  final String body;
  final DateTime createdAt;
}
