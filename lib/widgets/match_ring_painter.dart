import 'dart:math';
import 'package:flutter/material.dart';

class MatchRingPainter extends CustomPainter {
  final double matchScore; // 0.0 – 1.0

  const MatchRingPainter({required this.matchScore});

  @override
  void paint(Canvas canvas, Size size) {
    final score = matchScore.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);

    if (score <= 0) return;

    final color = Color.lerp(const Color(0xFF6C63FF), const Color(0xFF03DAC6), score)!;
    final sweepAngle = 2 * pi * score;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(MatchRingPainter old) => old.matchScore != matchScore;
}
