import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pose_suggestion.dart';
import '../models/pose_template.dart';
import 'pose_silhouette_painter.dart';

class SuggestionSheet extends StatelessWidget {
  final List<PoseSuggestion> suggestions;
  final ValueChanged<PoseSuggestion> onSelected;

  const SuggestionSheet({super.key, required this.suggestions, required this.onSelected});

  static Future<void> show(BuildContext context, {
    required List<PoseSuggestion> suggestions,
    required ValueChanged<PoseSuggestion> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) => SuggestionSheet(suggestions: suggestions, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Choose a Pose',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text('Step into the guide silhouette on screen',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55))),
              const SizedBox(height: 20),
              ...suggestions.asMap().entries.map((e) => _SuggestionCard(
                suggestion: e.value,
                index: e.key,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  onSelected(e.value);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PoseSuggestion suggestion;
  final int index;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.index, required this.onTap});

  static const _gradients = [
    [Color(0xFF6C63FF), Color(0xFF3D35B5)],
    [Color(0xFF03DAC6), Color(0xFF018786)],
    [Color(0xFFFF6584), Color(0xFFB5173A)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final template = PoseTemplate.all[suggestion.poseType] ?? PoseTemplate.all[PoseType.neutral]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [colors[0].withValues(alpha: 0.15), colors[1].withValues(alpha: 0.08)]),
          border: Border.all(color: colors[0].withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 72, height: 88,
                child: CustomPaint(
                  painter: PoseSilhouettePainter(
                    template: template,
                    matchScore: 0,
                    opacity: 1,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors[0].withValues(alpha: 0.2), Colors.transparent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colors[0])),
                    const SizedBox(height: 4),
                    Text(suggestion.instruction,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.arrow_forward_ios_rounded, color: colors[0].withValues(alpha: 0.7), size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
