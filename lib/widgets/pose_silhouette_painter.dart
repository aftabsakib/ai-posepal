import 'package:flutter/material.dart';
import '../models/pose_template.dart';

class PoseSilhouettePainter extends CustomPainter {
  final PoseTemplate template;
  final double matchScore;
  final double opacity;
  final Color accentColor;
  // Where the body's visual center sits on the canvas (0–1 normalized)
  final Offset anchor;
  // Scale relative to full-canvas-spanning (1.0 = fills height, 0.6 = smaller)
  final double compositionScale;

  PoseSilhouettePainter({
    required this.template,
    required this.matchScore,
    required this.opacity,
    required this.accentColor,
    this.anchor = const Offset(0.5, 0.5),
    this.compositionScale = 0.80,
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

  // Body's visual center in template space (hip level)
  static const _bodyCenter = Offset(0.50, 0.56);

  // Map a template landmark (0–1 space) to canvas pixels,
  // respecting the composition anchor and scale.
  Offset _toCanvas(double lx, double ly, Size canvas) {
    // Scale around body center
    final sx = _bodyCenter.dx + (lx - _bodyCenter.dx) * compositionScale;
    final sy = _bodyCenter.dy + (ly - _bodyCenter.dy) * compositionScale;
    // Translate body center to the composition anchor
    final fx = anchor.dx + (sx - _bodyCenter.dx);
    final fy = anchor.dy + (sy - _bodyCenter.dy);
    return Offset(fx * canvas.width, fy * canvas.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final score = matchScore.clamp(0.0, 1.0);

    final color = Color.lerp(
      const Color(0xFFF5F0E8).withValues(alpha: 0.4 * opacity),
      accentColor.withValues(alpha: 0.9 * opacity),
      score,
    )!;

    _glowPaint
      ..color = color.withValues(alpha: 0.18 * score * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    _linePaint.color = color;
    _dotPaint.color = color;

    final lm = template.landmarks;

    for (final conn in _connections) {
      final a = lm[conn[0]];
      final b = lm[conn[1]];
      if (a == null || b == null) continue;
      final p1 = _toCanvas(a.dx, a.dy, size);
      final p2 = _toCanvas(b.dx, b.dy, size);
      if (score > 0.3) canvas.drawLine(p1, p2, _glowPaint);
      canvas.drawLine(p1, p2, _linePaint);
    }

    final headPos = lm['head'];
    if (headPos != null) {
      final center = _toCanvas(headPos.dx, headPos.dy, size);
      final radius = size.width * 0.055 * compositionScale;
      if (score > 0.3) {
        _headGlowPaint.color = color.withValues(alpha: 0.18 * opacity);
        canvas.drawCircle(center, radius + 4, _headGlowPaint);
      }
      canvas.drawCircle(center, radius, _dotPaint);
    }

    for (final key in ['lShoulder', 'rShoulder', 'lHip', 'rHip', 'lKnee', 'rKnee']) {
      final p = lm[key];
      if (p == null) continue;
      canvas.drawCircle(_toCanvas(p.dx, p.dy, size), 5 * compositionScale, _dotPaint);
    }
  }

  @override
  bool shouldRepaint(PoseSilhouettePainter old) =>
      old.matchScore != matchScore || old.opacity != opacity ||
      old.template != template || old.accentColor != accentColor ||
      old.anchor != anchor || old.compositionScale != compositionScale;
}
