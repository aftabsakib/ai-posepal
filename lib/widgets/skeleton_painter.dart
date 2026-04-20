import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  SkeletonPainter({required this.poses, required this.imageSize, required this.isFrontCamera});

  static const _connections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    [PoseLandmarkType.nose, PoseLandmarkType.leftShoulder],
    [PoseLandmarkType.nose, PoseLandmarkType.rightShoulder],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      for (final conn in _connections) {
        final a = pose.landmarks[conn[0]];
        final b = pose.landmarks[conn[1]];
        if (a == null || b == null) continue;
        final confidence = ((a.likelihood + b.likelihood) / 2).clamp(0.0, 1.0);
        if (confidence < 0.5) continue;

        final p1 = _translate(a.x, a.y, size);
        final p2 = _translate(b.x, b.y, size);

        canvas.drawLine(p1, p2, Paint()
          ..color = const Color(0xFF6C63FF).withOpacity(0.25 * confidence)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

        canvas.drawLine(p1, p2, Paint()
          ..color = Color.lerp(const Color(0xFF03DAC6), const Color(0xFF6C63FF), confidence)!
              .withOpacity(0.85 * confidence)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);
      }

      for (final lm in pose.landmarks.values) {
        if (lm.likelihood < 0.6) continue;
        final p = _translate(lm.x, lm.y, size);
        canvas.drawCircle(p, 5.5, Paint()
          ..color = Colors.white.withOpacity(0.9 * lm.likelihood));
        canvas.drawCircle(p, 3.5, Paint()
          ..color = const Color(0xFF03DAC6).withOpacity(lm.likelihood));
      }
    }
  }

  Offset _translate(double x, double y, Size canvas) {
    final scaleX = canvas.width / imageSize.width;
    final scaleY = canvas.height / imageSize.height;
    final dx = isFrontCamera ? canvas.width - x * scaleX : x * scaleX;
    return Offset(dx, y * scaleY);
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => true;
}
