/// The community split for a single question's binary (TAK / NIE) vote, plus the
/// caller's own choice.
///
/// Returned by the `cast_daily_vote` and `get_daily_vote_state` RPCs. The counts
/// are aggregated server-side (a user never reads other users' vote rows). When
/// [myChoice] is null the user hasn't voted yet, so the UI shows the vote
/// buttons; otherwise it shows the result bars.
class VoteResult {
  const VoteResult({
    required this.yesCount,
    required this.noCount,
    this.myChoice,
  });

  /// 1 = TAK, 2 = NIE — matches the `choice` column / RPC contract.
  static const int yes = 1;
  static const int no = 2;

  final int yesCount;
  final int noCount;

  /// The caller's vote (1 = TAK, 2 = NIE), or null if they haven't voted.
  final int? myChoice;

  int get total => yesCount + noCount;

  bool get hasVoted => myChoice != null;

  /// Share of TAK votes in 0..1 (0 when there are no votes yet).
  double get yesFraction => total == 0 ? 0 : yesCount / total;

  /// Share of NIE votes in 0..1 (0 when there are no votes yet).
  double get noFraction => total == 0 ? 0 : noCount / total;

  /// TAK percentage as a rounded whole number (0..100).
  int get yesPct => (yesFraction * 100).round();

  /// NIE percentage; derived from [yesPct] so the two always sum to 100.
  int get noPct => total == 0 ? 0 : 100 - yesPct;

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return VoteResult(
      yesCount: asInt(json['yes_count']),
      noCount: asInt(json['no_count']),
      myChoice: json['my_choice'] == null ? null : asInt(json['my_choice']),
    );
  }

  static const VoteResult empty = VoteResult(yesCount: 0, noCount: 0);
}
