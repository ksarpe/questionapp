/// A single thought-provoking question shown on screen.
///
/// Questions are intentionally lightweight value objects — they hold only the
/// text and the metadata needed to decide whether to gate the question behind a
/// premium subscription.
class Question {
  final String id;
  final String category;
  final String questionText;
  final bool isPremium;

  const Question({
    required this.id,
    required this.category,
    required this.questionText,
    this.isPremium = false,
  });

  /// Builds a [Question] from a Supabase/JSON row.
  ///
  /// Column names mirror the `questions` table in Supabase. Adjust here if the
  /// schema changes rather than scattering key strings across the app.
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'].toString(),
      category: json['category'] as String? ?? 'general',
      questionText: json['question_text'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'question_text': questionText,
        'is_premium': isPremium,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
