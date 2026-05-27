class SpotIntegrity {
  const SpotIntegrity({
    required this.imageHash,
    required this.perceptualHash,
    required this.captureSource,
    required this.trustScore,
    required this.verificationStatus,
  });

  final String imageHash;
  final String perceptualHash;
  final String captureSource;
  final int trustScore;
  final String verificationStatus;
}
