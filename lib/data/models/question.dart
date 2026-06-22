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

  /// Whether the current user may NOT read this question's text yet.
  ///
  /// The deck is built from the full catalog, so locked questions still appear
  /// — but with [questionText] withheld by the server (empty). The UI renders a
  /// locked placeholder + unlock prompt for these. The free daily and anything
  /// the user has unlocked / premium come back unlocked.
  final bool? isLocked;

  /// The first couple of words of the question, returned even when [isLocked].
  ///
  /// The server derives this from the full text (it can, being SECURITY DEFINER)
  /// so a locked question can show a "Czy miliarderzy…" tease above the unlock
  /// CTA instead of a generic "locked" label. Null/empty when there is no text
  /// to tease (the UI then falls back to the plain locked message).
  final String? teaser;

  /// Whether the current user has already seen this question.
  ///
  /// Returned by `get_questions` from the per-user `question_seen` log (daily
  /// views, reveals and premium catalog views all record there). Only meaningful
  /// for the premium deck, which puts UNSEEN questions first so fresh content
  /// surfaces before the archive. Absent from the daily / reveal shapes, where it
  /// defaults to false.
  final bool seen;

  const Question({
    required this.id,
    required this.category,
    required this.questionText,
    this.isPremium = false,
    this.isLocked = false,
    this.teaser,
    this.seen = false,
  });

  /// Builds a [Question] from a Supabase/JSON row.
  ///
  /// Column names mirror the `get_questions` RPC / `questions` table. Adjust
  /// here if the schema changes rather than scattering key strings across the
  /// app. `locked` is absent from the daily-question shape, so it defaults to
  /// false (the daily is always readable).
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'].toString(),
      category: json['category'] as String? ?? 'general',
      questionText: json['question_text'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      isLocked: json['locked'] as bool? ?? false,
      teaser: json['teaser'] as String?,
      seen: json['seen'] as bool? ?? false,
    );
  }

  Question copyWith({
    String? id,
    String? category,
    String? questionText,
    bool? isPremium,
    bool? isLocked,
    String? teaser,
    bool? seen,
  }) => Question(
    id: id ?? this.id,
    category: category ?? this.category,
    questionText: questionText ?? this.questionText,
    isPremium: isPremium ?? this.isPremium,
    isLocked: isLocked ?? this.isLocked,
    teaser: teaser ?? this.teaser,
    seen: seen ?? this.seen,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'question_text': questionText,
    'is_premium': isPremium,
    'locked': isLocked,
    'teaser': teaser,
    'seen': seen,
  };

  // Value equality across ALL rendered fields, not just id. The SAME question
  // appears first locked (text withheld, isLocked true) and then, after a
  // rewarded-ad unlock, with its text present (isLocked false) under the same
  // id. If equality were id-only, Riverpod would treat the unlocked value as
  // unchanged and never notify currentQuestionProvider — so the reveal would
  // never reach the screen and the teaser would stay put.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          questionText == other.questionText &&
          isPremium == other.isPremium &&
          isLocked == other.isLocked &&
          teaser == other.teaser &&
          seen == other.seen;

  @override
  int get hashCode =>
      Object.hash(id, category, questionText, isPremium, isLocked, teaser, seen);
}
