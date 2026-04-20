import 'package:flutter/material.dart';
import '../models/pose_template.dart';

class PoseSilhouettePainter extends CustomPainter {
  final PoseTemplate template;
  final double matchScore; // 0.0 – 1.0
  final double opacity;    // for fade animation

  PoseSilhouettePainter({
    required this.template,
    required this.matchScore,
    required this.opacity,
  });

  static const _connections = [
    ['head', 'neck'],
    ['neck', 'lShoulder'], ['neck', 'rShoulder'],
    ['lShoulder', 'lElbow'], ['lElbow', 'lWrist'],
    ['rShoulder', 'rElbow'], ['rElbow', 'rWrist'],
    ['lShoulder', 'lHip'], ['rShoulder', 'rHip'],
    ['lHip', 'rHip'],
    ['lHip', 'lKnee'], ['lKnee', 'lAnkle'],
    ['rHip', 'rKnee'], ['rKnee', 'rAnkle'],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final color = Color.lerp(
      Colors.white.withOpacity(0.35 * opacity),
      const Color(0xFF03DAC6).withOpacity(0.85 * opacity),
      matchScore,
    )!;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.15 * matchScore * opacity)
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final lm = template.landmarks;

    for (final conn in _connections) {
      final a = lm[conn[0]];
      final b = lm[conn[1]];
      if (a == null || b == null) continue;
      final p1 = Offset(a.dx * size.width, a.dy * size.height);
      final p2 = Offset(b.dx * size.width, b.dy * size.height);
      if (matchScore > 0.3) canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, linePaint);
    }

    final headPos = lm['head'];
    if (headPos != null) {
      final center = Offset(headPos.dx * size.width, headPos.dy * size.height);
      final radius = size.width * 0.055;
      if (matchScore > 0.3) {
        canvas.drawCircle(center, radius + 4,
            Paint()
              ..color = color.withOpacity(0.15 * opacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
      canvas.drawCircle(center, radius, dotPaint);
    }

    for (final key in ['lShoulder', 'rShoulder', 'lHip', 'rHip', 'lKnee', 'rKnee']) {
      final p = lm[key];
      if (p == null) continue;
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(PoseSilhouettePainter old) =>
      old.matchScore != matchScore || old.opacity != opacity || old.template != template;
}
