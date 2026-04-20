import 'package:flutter/material.dart';

enum PoseType { neutral, powerPose, crossedArms, oneArmUp, casualLean, vArms }

class PoseTemplate {
  final PoseType type;
  final String name;
  final String description;
  final Map<String, Offset> landmarks;

  const PoseTemplate({
    required this.type,
    required this.name,
    required this.description,
    required this.landmarks,
  });

  static const Map<PoseType, PoseTemplate> all = {
    PoseType.neutral: PoseTemplate(
      type: PoseType.neutral,
      name: 'Standing Tall',
      description: 'Stand straight, arms relaxed at sides',
      landmarks: {
        'head': Offset(0.50, 0.09), 'neck': Offset(0.50, 0.17),
        'lShoulder': Offset(0.38, 0.23), 'rShoulder': Offset(0.62, 0.23),
        'lElbow': Offset(0.34, 0.38), 'rElbow': Offset(0.66, 0.38),
        'lWrist': Offset(0.35, 0.53), 'rWrist': Offset(0.65, 0.53),
        'lHip': Offset(0.42, 0.56), 'rHip': Offset(0.58, 0.56),
        'lKnee': Offset(0.41, 0.74), 'rKnee': Offset(0.59, 0.74),
        'lAnkle': Offset(0.41, 0.92), 'rAnkle': Offset(0.59, 0.92),
      },
    ),
    PoseType.powerPose: PoseTemplate(
      type: PoseType.powerPose,
      name: 'Power Pose',
      description: 'Hands on hips, chest out, legs shoulder-width apart',
      landmarks: {
        'head': Offset(0.50, 0.09), 'neck': Offset(0.50, 0.17),
        'lShoulder': Offset(0.37, 0.23), 'rShoulder': Offset(0.63, 0.23),
        'lElbow': Offset(0.26, 0.32), 'rElbow': Offset(0.74, 0.32),
        'lWrist': Offset(0.37, 0.45), 'rWrist': Offset(0.63, 0.45),
        'lHip': Offset(0.41, 0.56), 'rHip': Offset(0.59, 0.56),
        'lKnee': Offset(0.39, 0.74), 'rKnee': Offset(0.61, 0.74),
        'lAnkle': Offset(0.38, 0.92), 'rAnkle': Offset(0.62, 0.92),
      },
    ),
    PoseType.crossedArms: PoseTemplate(
      type: PoseType.crossedArms,
      name: 'Crossed Arms',
      description: 'Fold your arms across your chest, stand confident',
      landmarks: {
        'head': Offset(0.50, 0.09), 'neck': Offset(0.50, 0.17),
        'lShoulder': Offset(0.38, 0.23), 'rShoulder': Offset(0.62, 0.23),
        'lElbow': Offset(0.44, 0.34), 'rElbow': Offset(0.56, 0.34),
        'lWrist': Offset(0.60, 0.38), 'rWrist': Offset(0.40, 0.38),
        'lHip': Offset(0.42, 0.56), 'rHip': Offset(0.58, 0.56),
        'lKnee': Offset(0.41, 0.74), 'rKnee': Offset(0.59, 0.74),
        'lAnkle': Offset(0.41, 0.92), 'rAnkle': Offset(0.59, 0.92),
      },
    ),
    PoseType.oneArmUp: PoseTemplate(
      type: PoseType.oneArmUp,
      name: 'One Arm Up',
      description: 'Raise your right arm high, left arm relaxed',
      landmarks: {
        'head': Offset(0.50, 0.09), 'neck': Offset(0.50, 0.17),
        'lShoulder': Offset(0.38, 0.23), 'rShoulder': Offset(0.62, 0.23),
        'lElbow': Offset(0.34, 0.38), 'rElbow': Offset(0.70, 0.10),
        'lWrist': Offset(0.35, 0.52), 'rWrist': Offset(0.66, 0.02),
        'lHip': Offset(0.42, 0.56), 'rHip': Offset(0.58, 0.56),
        'lKnee': Offset(0.41, 0.74), 'rKnee': Offset(0.59, 0.74),
        'lAnkle': Offset(0.41, 0.92), 'rAnkle': Offset(0.59, 0.92),
      },
    ),
    PoseType.casualLean: PoseTemplate(
      type: PoseType.casualLean,
      name: 'Casual Lean',
      description: 'Shift weight to one side, relax your shoulders',
      landmarks: {
        'head': Offset(0.52, 0.09), 'neck': Offset(0.52, 0.17),
        'lShoulder': Offset(0.39, 0.22), 'rShoulder': Offset(0.64, 0.25),
        'lElbow': Offset(0.35, 0.36), 'rElbow': Offset(0.68, 0.40),
        'lWrist': Offset(0.36, 0.51), 'rWrist': Offset(0.64, 0.55),
        'lHip': Offset(0.41, 0.54), 'rHip': Offset(0.59, 0.58),
        'lKnee': Offset(0.38, 0.72), 'rKnee': Offset(0.61, 0.76),
        'lAnkle': Offset(0.36, 0.90), 'rAnkle': Offset(0.63, 0.93),
      },
    ),
    PoseType.vArms: PoseTemplate(
      type: PoseType.vArms,
      name: 'Victory V',
      description: 'Raise both arms into a V shape, smile big',
      landmarks: {
        'head': Offset(0.50, 0.09), 'neck': Offset(0.50, 0.17),
        'lShoulder': Offset(0.38, 0.23), 'rShoulder': Offset(0.62, 0.23),
        'lElbow': Offset(0.27, 0.13), 'rElbow': Offset(0.73, 0.13),
        'lWrist': Offset(0.20, 0.04), 'rWrist': Offset(0.80, 0.04),
        'lHip': Offset(0.42, 0.56), 'rHip': Offset(0.58, 0.56),
        'lKnee': Offset(0.41, 0.74), 'rKnee': Offset(0.59, 0.74),
        'lAnkle': Offset(0.41, 0.92), 'rAnkle': Offset(0.59, 0.92),
      },
    ),
  };

  static PoseType fromString(String s) {
    return PoseType.values.firstWhere(
      (t) => t.name == s,
      orElse: () {
        assert(false, 'Unknown PoseType: "$s" — falling back to neutral');
        return PoseType.neutral;
      },
    );
  }
}
