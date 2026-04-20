import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  SkeletonPainter({
    required this.poses,
    required this.imageSize,
    required this.isFrontCamera,
  });

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

  final _linePaint = Paint()
    ..color = const Color(0xFF6C63FF)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  final _dotPaint = Paint()
    ..color = const Color(0xFF03DAC6)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      for (final connection in _connections) {
        final start = pose.landmarks[connection[0]];
        final end = pose.landmarks[connection[1]];
        if (start != null && end != null) {
          canvas.drawLine(
            _translatePoint(start.x, start.y, size),
            _translatePoint(end.x, end.y, size),
            _linePaint,
          );
        }
      }
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          _translatePoint(landmark.x, landmark.y, size),
          5.0,
          _dotPaint,
        );
      }
    }
  }

  Offset _translatePoint(double x, double y, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    final dx = isFrontCamera ? canvasSize.width - x * scaleX : x * scaleX;
    return Offset(dx, y * scaleY);
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) => true;
}
