import 'vote_result.dart';

/// One voted question in the PRO "question history".
///
/// Every question the user votes on shows its community split once — then the
/// feed moves on and that result is no longer reachable from the home screen.
/// The history is the user's voting record: for premium users it surfaces every
/// question they ever voted on, with the question text, when they voted, and the
/// live community split (with the caller's own choice). Returned by the
/// `get_vote_history` RPC, newest vote first.
class VoteHistoryEntry {
  const VoteHistoryEntry({
    required this.questionId,
    required this.category,
    required this.questionText,
    required this.votedAt,
    required this.votes,
  });

  final String questionId;
  final String category;
  final String questionText;

  /// When the caller cast (or last changed) their vote on this question. Comes
  /// back as a UTC timestamp; render via `toLocal()`.
  final DateTime votedAt;

  /// The community TAK/NIE split plus the caller's own choice for this question.
  final VoteResult votes;

  /// The RPC row carries `yes_count` / `no_count` / `my_choice` under the same
  /// keys [VoteResult.fromJson] reads, so the split is built straight from it.
  factory VoteHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VoteHistoryEntry(
      questionId: json['question_id'].toString(),
      category: json['category'] as String? ?? 'general',
      questionText: json['question_text'] as String? ?? '',
      votedAt: DateTime.parse(json['voted_at'].toString()),
      votes: VoteResult.fromJson(json),
    );
  }
}
