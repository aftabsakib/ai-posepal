import 'dart:math';
import 'package:flutter/material.dart';

class MatchRingPainter extends CustomPainter {
  final double matchScore;
  final Color accentColor;

  const MatchRingPainter({required this.matchScore, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final score = matchScore.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0xFF3A3A2E).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);

    if (score <= 0) return;

    final color = Color.lerp(accentColor.withValues(alpha: 0.4), accentColor, score)!;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * score,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(MatchRingPainter old) =>
      old.matchScore != matchScore || old.accentColor != accentColor;
}
