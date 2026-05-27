class ModerationCaseDraft {
  const ModerationCaseDraft({
    required this.type,
    required this.reason,
    required this.priority,
    this.details = '',
    this.suggestedCarName = '',
  });

  final String type;
  final String reason;
  final String priority;
  final String details;
  final String suggestedCarName;

  factory ModerationCaseDraft.report({
    required String reason,
    String details = '',
  }) {
    return ModerationCaseDraft(
      type: _typeForReason(reason),
      reason: reason,
      details: details,
      priority: _priorityForReason(reason),
    );
  }

  factory ModerationCaseDraft.correction({
    required String suggestedCarName,
    String details = '',
  }) {
    return ModerationCaseDraft(
      type: 'correction',
      reason: 'Wrong car',
      details: details,
      suggestedCarName: suggestedCarName,
      priority: 'medium',
    );
  }

  static String _typeForReason(String reason) {
    return switch (reason) {
      'Stolen photo' => 'stolen_photo',
      'Fake location' => 'fake_location',
      'Wrong car' => 'correction',
      'Unsafe content' => 'unsafe_content',
      _ => 'other',
    };
  }

  static String _priorityForReason(String reason) {
    return switch (reason) {
      'Unsafe content' => 'high',
      'Stolen photo' => 'high',
      'Fake location' => 'medium',
      'Wrong car' => 'medium',
      _ => 'low',
    };
  }
}
