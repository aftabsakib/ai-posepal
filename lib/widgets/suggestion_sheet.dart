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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (_) => SuggestionSheet(suggestions: suggestions, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF4A4A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Choose a pose',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF5F0E8),
              letterSpacing: -0.5,
            )),
          const SizedBox(height: 4),
          const Text('Step into the silhouette on screen',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A7A6A))),
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
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PoseSuggestion suggestion;
  final int index;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.index, required this.onTap});

  static const _accents = [
    Color(0xFFC8F04A),
    Color(0xFFFFD166),
    Color(0xFFFF8FA3),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    final template = PoseTemplate.all[suggestion.poseType] ?? PoseTemplate.all[PoseType.neutral]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF242418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: 72, height: 88,
                child: CustomPaint(
                  painter: PoseSilhouettePainter(
                    template: template,
                    matchScore: 0,
                    opacity: 1,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: accent,
                      )),
                    const SizedBox(height: 4),
                    Text(suggestion.instruction,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9A9A8A),
                        height: 1.4,
                      )),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.arrow_forward_ios_rounded,
                color: accent.withValues(alpha: 0.6), size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
