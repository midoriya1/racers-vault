class RecognitionResult {
  const RecognitionResult({
    required this.carName,
    required this.category,
    required this.confidence,
    required this.suggestedRarity,
    required this.reason,
    this.make = '',
    this.model = '',
    this.generation = '',
    this.yearRange = '',
    this.bodyType = '',
    this.licensePlateVisible = false,
    this.faceVisible = false,
    this.syntheticImageRisk = 0,
    this.manipulationRisk = 0,
    this.securityNote = '',
    this.blurStatus = 'not_needed',
    this.processedImageBase64 = '',
    this.processedMimeType = '',
  });

  final String carName;
  final String category;
  final double confidence;
  final String suggestedRarity;
  final String reason;
  final String make;
  final String model;
  final String generation;
  final String yearRange;
  final String bodyType;
  final bool licensePlateVisible;
  final bool faceVisible;
  final double syntheticImageRisk;
  final double manipulationRisk;
  final String securityNote;
  final String blurStatus;
  final String processedImageBase64;
  final String processedMimeType;
}
