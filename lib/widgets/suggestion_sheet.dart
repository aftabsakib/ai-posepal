import 'package:flutter/material.dart';
import '../models/pose_suggestion.dart';

class SuggestionSheet extends StatelessWidget {
  final List<PoseSuggestion> suggestions;
  final ValueChanged<PoseSuggestion> onSelected;

  const SuggestionSheet({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PoseSuggestion> suggestions,
    required ValueChanged<PoseSuggestion> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestionSheet(suggestions: suggestions, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Pose Suggestions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap one to use it as your guide',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          ...suggestions.map((s) => _SuggestionCard(suggestion: s, onTap: () {
            Navigator.pop(context);
            onSelected(s);
          })),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PoseSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.instruction,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
