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

  final _glowPaint = Paint()
    ..strokeWidth = 28
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final _linePaint = Paint()
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final _dotPaint = Paint()..style = PaintingStyle.fill;
  final _headGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

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
    final score = matchScore.clamp(0.0, 1.0);

    final color = Color.lerp(
      const Color(0xFFF5F0E8).withValues(alpha: 0.4 * opacity),
      const Color(0xFFC8F04A).withValues(alpha: 0.9 * opacity),
      score,
    )!;

    _glowPaint
      ..color = color.withValues(alpha: 0.15 * score * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    _linePaint.color = color;
    _dotPaint.color = color;

    final lm = template.landmarks;

    for (final conn in _connections) {
      final a = lm[conn[0]];
      final b = lm[conn[1]];
      if (a == null || b == null) continue;
      final p1 = Offset(a.dx * size.width, a.dy * size.height);
      final p2 = Offset(b.dx * size.width, b.dy * size.height);
      if (score > 0.3) canvas.drawLine(p1, p2, _glowPaint);
      canvas.drawLine(p1, p2, _linePaint);
    }

    final headPos = lm['head'];
    if (headPos != null) {
      final center = Offset(headPos.dx * size.width, headPos.dy * size.height);
      final radius = size.width * 0.055;
      if (score > 0.3) {
        _headGlowPaint.color = color.withValues(alpha: 0.15 * opacity);
        canvas.drawCircle(center, radius + 4, _headGlowPaint);
      }
      canvas.drawCircle(center, radius, _dotPaint);
    }

    for (final key in ['lShoulder', 'rShoulder', 'lHip', 'rHip', 'lKnee', 'rKnee']) {
      final p = lm[key];
      if (p == null) continue;
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 5, _dotPaint);
    }
  }

  @override
  bool shouldRepaint(PoseSilhouettePainter old) =>
      old.matchScore != matchScore || old.opacity != opacity || old.template != template;
}
