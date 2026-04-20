class PoseSuggestion {
  final String title;
  final String instruction;

  const PoseSuggestion({required this.title, required this.instruction});

  factory PoseSuggestion.fromJson(Map<String, dynamic> json) {
    return PoseSuggestion(
      title: json['title'] as String,
      instruction: json['instruction'] as String,
    );
  }
}
