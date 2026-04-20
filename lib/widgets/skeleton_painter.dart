import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  SkeletonPainter({required this.poses, required this.imageSize, required this.isFrontCamera});

  final _glowPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 14;
  final _linePaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3.5;
  final _dotOuterPaint = Paint();
  final _dotInnerPaint = Paint();

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

        _glowPaint
          ..color = const Color(0xFF6C63FF).withValues(alpha: 0.25 * confidence)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawLine(p1, p2, _glowPaint);

        _linePaint.color = Color.lerp(const Color(0xFF03DAC6), const Color(0xFF6C63FF), confidence)!
            .withValues(alpha: 0.85 * confidence);
        canvas.drawLine(p1, p2, _linePaint);
      }

      for (final lm in pose.landmarks.values) {
        if (lm.likelihood < 0.6) continue;
        final p = _translate(lm.x, lm.y, size);
        _dotOuterPaint.color = Colors.white.withValues(alpha: 0.9 * lm.likelihood);
        _dotInnerPaint.color = const Color(0xFF03DAC6).withValues(alpha: lm.likelihood);
        canvas.drawCircle(p, 5.5, _dotOuterPaint);
        canvas.drawCircle(p, 3.5, _dotInnerPaint);
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
  bool shouldRepaint(SkeletonPainter old) =>
      old.poses != poses || old.imageSize != imageSize || old.isFrontCamera != isFrontCamera;
}
