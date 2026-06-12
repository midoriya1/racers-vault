class SpotIntegrity {
  const SpotIntegrity({
    required this.imageHash,
    required this.perceptualHash,
    required this.captureSource,
    required this.trustScore,
    required this.verificationStatus,
    this.capturedAt,
    this.hasGpsMetadata = false,
    this.metadataStatus = 'unknown',
    this.metadataNotes = '',
  });

  final String imageHash;
  final String perceptualHash;
  final String captureSource;
  final int trustScore;
  final String verificationStatus;
  final DateTime? capturedAt;
  final bool hasGpsMetadata;
  final String metadataStatus;
  final String metadataNotes;
}
