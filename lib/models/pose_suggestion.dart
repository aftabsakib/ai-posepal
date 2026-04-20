import 'pose_template.dart';

class PoseSuggestion {
  final String title;
  final String instruction;
  final PoseType poseType;

  const PoseSuggestion({
    required this.title,
    required this.instruction,
    required this.poseType,
  });

  factory PoseSuggestion.fromJson(Map<String, dynamic> json) {
    return PoseSuggestion(
      title: (json['title'] as String?) ?? '',
      instruction: (json['instruction'] as String?) ?? '',
      poseType: PoseTemplate.fromString(json['pose_type'] as String? ?? 'neutral'),
    );
  }
}
