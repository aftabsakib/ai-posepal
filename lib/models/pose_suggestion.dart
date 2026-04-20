import 'package:flutter/material.dart';
import 'pose_template.dart';

enum CompositionPosition { center, leftThird, rightThird, lowerCenter, lowerLeft, lowerRight }

extension CompositionPositionX on CompositionPosition {
  // Where the body's visual center sits on the canvas (normalized 0–1)
  Offset get anchor {
    switch (this) {
      case CompositionPosition.center:      return const Offset(0.50, 0.50);
      case CompositionPosition.leftThird:   return const Offset(0.28, 0.50);
      case CompositionPosition.rightThird:  return const Offset(0.72, 0.50);
      case CompositionPosition.lowerCenter: return const Offset(0.50, 0.60);
      case CompositionPosition.lowerLeft:   return const Offset(0.28, 0.60);
      case CompositionPosition.lowerRight:  return const Offset(0.72, 0.60);
    }
  }

  // How large the silhouette renders — smaller when off-center to leave negative space
  double get silhouetteScale {
    switch (this) {
      case CompositionPosition.center:      return 0.80;
      case CompositionPosition.leftThird:   return 0.62;
      case CompositionPosition.rightThird:  return 0.62;
      case CompositionPosition.lowerCenter: return 0.72;
      case CompositionPosition.lowerLeft:   return 0.58;
      case CompositionPosition.lowerRight:  return 0.58;
    }
  }

  static CompositionPosition fromString(String s) => CompositionPosition.values.firstWhere(
    (c) => c.name == s,
    orElse: () => CompositionPosition.center,
  );
}

class PoseSuggestion {
  final String title;
  final String instruction;
  final PoseType poseType;
  final CompositionPosition compositionPosition;

  const PoseSuggestion({
    required this.title,
    required this.instruction,
    required this.poseType,
    this.compositionPosition = CompositionPosition.center,
  });

  factory PoseSuggestion.fromJson(Map<String, dynamic> json) {
    return PoseSuggestion(
      title: (json['title'] as String?) ?? '',
      instruction: (json['instruction'] as String?) ?? '',
      poseType: PoseTemplate.fromString(json['pose_type'] as String? ?? 'neutral'),
      compositionPosition: CompositionPositionX.fromString(
          json['composition'] as String? ?? 'center'),
    );
  }
}
