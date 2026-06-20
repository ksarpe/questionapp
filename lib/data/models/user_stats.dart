/// The user's engagement state shown by the two top icons (streak + free
/// unlocks) and the rank sheet.
///
/// Produced server-side by the `sync_user_state` RPC, which also performs the
/// once-per-day free-credit top-up as a side effect. Everything here is the
/// SERVER's view — the client never computes streak or credits itself, so the
/// phone clock can't be used to game them.
class UserStats {
  const UserStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.freeUnlockCredits,
    required this.rankTier,
    required this.rankName,
    this.nextRankStreak,
    this.isPremium = false,
  });

  /// Consecutive days the user voted on the daily, already "broken" to 0 by the
  /// server when a day was missed.
  final int currentStreak;

  /// Best streak ever reached — shown as a secondary stat in the rank sheet.
  final int longestStreak;

  /// Free unlock credits in the bank (0 or 1). Always 0 for premium users, who
  /// don't use the credit system at all (everything is already readable).
  final int freeUnlockCredits;

  /// Index of the current rank in the ladder (0 = the entry rank).
  final int rankTier;

  /// Localised name of the current rank (e.g. "Prowokator").
  final String rankName;

  /// Streak needed to reach the next rank, or null when already at the top.
  final int? nextRankStreak;

  final bool isPremium;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    return UserStats(
      currentStreak: asInt(json['current_streak']),
      longestStreak: asInt(json['longest_streak']),
      freeUnlockCredits: asInt(json['free_unlock_credits']),
      rankTier: asInt(json['rank_tier']),
      rankName: json['rank_name'] as String? ?? '',
      nextRankStreak: json['next_rank_streak'] == null
          ? null
          : asInt(json['next_rank_streak']),
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  /// A zeroed state used as the offline/mock baseline and before the first sync.
  static const UserStats empty = UserStats(
    currentStreak: 0,
    longestStreak: 0,
    freeUnlockCredits: 0,
    rankTier: 0,
    rankName: '',
    nextRankStreak: null,
  );
}
