import 'vote_result.dart';

/// One past daily question in the PRO "question history".
///
/// Once a day rolls over, its question stops being the daily and melts back into
/// the general pool — so the community vote it gathered is no longer visible from
/// the home screen. The history surfaces those past days for premium users: the
/// question text, the date it ran, and how people voted (with the caller's own
/// choice). Returned by the `get_daily_history` RPC, newest first.
class DailyHistoryEntry {
  const DailyHistoryEntry({
    required this.questionId,
    required this.category,
    required this.questionText,
    required this.publishDate,
    required this.votes,
  });

  final String questionId;
  final String category;
  final String questionText;

  /// The date this question was the daily (date-only, parsed as local midnight).
  final DateTime publishDate;

  /// The community TAK/NIE split plus the caller's own choice for this question.
  final VoteResult votes;

  /// The RPC row carries `yes_count` / `no_count` / `my_choice` under the same
  /// keys [VoteResult.fromJson] reads, so the split is built straight from it.
  factory DailyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DailyHistoryEntry(
      questionId: json['question_id'].toString(),
      category: json['category'] as String? ?? 'general',
      questionText: json['question_text'] as String? ?? '',
      publishDate: DateTime.parse(json['publish_date'].toString()),
      votes: VoteResult.fromJson(json),
    );
  }
}
