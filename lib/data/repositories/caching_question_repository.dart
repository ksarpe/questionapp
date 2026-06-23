import '../../core/network/network_error.dart';
import '../../services/question_cache.dart';
import '../models/daily_history_entry.dart';
import '../models/question.dart';
import '../models/rank.dart';
import '../models/smaczek.dart';
import '../models/user_stats.dart';
import '../models/vote_result.dart';
import 'question_repository.dart';

/// Wraps another [QuestionRepository] with an on-device cache so the catalog,
/// daily, smaczki, favorites, stats and ranks stay readable when the network
/// drops — and so premium users get their whole (legitimately-accessible)
/// catalog offline.
///
/// Strategy: every READ is "network-first, cache-fallback". On a successful
/// fetch we refresh the cache and return the fresh data; on a TRANSPORT error
/// (see [isOfflineError]) we serve the cache when present, otherwise rethrow so
/// the existing "you're offline, retry" screen still shows. A real server error
/// (4xx/5xx) is never masked by cache — it rethrows.
///
/// WRITES (vote, reveal, favorite toggle, mark-seen) are pass-through: they
/// inherently need the server, so offline they throw and the UI surfaces a
/// "you're offline" message rather than queueing.
///
/// SECURITY: question text is server-gated, so the cache only ever holds what
/// the server returned for THIS identity. The catalog is tagged with
/// [QuestionCache.cachedAsPremium]; if premium lapses we refuse to serve that
/// premium-text cache and wipe it (defence-in-depth on top of the explicit clear
/// the session does on a lapse), so a downgrade can never read the full pool.
class CachingQuestionRepository implements QuestionRepository {
  CachingQuestionRepository({
    required this.inner,
    required this.cache,
    required this.locale,
    required this.isPremium,
  });

  final QuestionRepository inner;
  final QuestionCache cache;
  final String locale;
  final bool isPremium;

  @override
  Future<List<Question>> fetchQuestions() async {
    try {
      final fresh = await inner.fetchQuestions();
      await cache.writeCatalog(locale, fresh);
      await cache.setCachedAsPremium(isPremium);
      await cache.markSynced();
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      final cached = await _readPremiumSafe(() => cache.readCatalog(locale));
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async {
    final dateKey = _dateOnly(date);
    try {
      final fresh = await inner.fetchDailyQuestion(date);
      if (fresh != null) await cache.writeDaily(locale, dateKey, fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      // Prefer today's cached daily; fall back to the last one we ever cached so
      // a fresh-day offline launch shows a (stale) daily instead of an error.
      final exact = cache.readDaily(locale, dateKey);
      if (exact != null) return exact;
      final latest = cache.readLatestDaily(locale);
      if (latest != null) return latest.question;
      rethrow;
    }
  }

  @override
  Future<List<Smaczek>> fetchSmaczki(String questionId) async {
    try {
      final fresh = await inner.fetchSmaczki(questionId);
      await cache.writeSmaczki(locale, questionId, fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      final cached = await _readPremiumSafe(
        () => cache.readSmaczki(locale, questionId),
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<UserStats?> syncUserState() async {
    try {
      final fresh = await inner.syncUserState();
      if (fresh != null) await cache.writeStats(fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      // Stats are not gated content (just the user's own streak/credits), so no
      // premium guard — serve the last sync so the chips don't reset offline.
      return cache.readStats();
    }
  }

  @override
  Future<List<Rank>> fetchRanks() async {
    try {
      final fresh = await inner.fetchRanks();
      await cache.writeRanks(fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      // Ranks are public + small, with a compiled-in default — never error here.
      return cache.readRanks() ?? kDefaultRanks;
    }
  }

  @override
  Future<Set<String>> fetchFavoriteIds() async {
    try {
      final fresh = await inner.fetchFavoriteIds();
      await cache.writeFavoriteIds(locale, fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      return cache.readFavoriteIds(locale) ?? const <String>{};
    }
  }

  @override
  Future<List<Question>> fetchFavoriteQuestions() async {
    try {
      final fresh = await inner.fetchFavoriteQuestions();
      await cache.writeFavoriteQuestions(locale, fresh);
      return fresh;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      final cached = cache.readFavoriteQuestions(locale);
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ---- Pass-through writes / live reads --------------------------------------
  // These need the server every time (entitlement, server clock, fresh tallies),
  // so they go straight to the inner repo. Offline they throw and the caller
  // surfaces a "you're offline" message — we deliberately do NOT queue.

  @override
  Future<({String id, String teaser})?> peekNextQuestion() =>
      inner.peekNextQuestion();

  @override
  Future<Question?> revealAdQuestion({String? questionId}) =>
      inner.revealAdQuestion(questionId: questionId);

  @override
  Future<Question?> revealFreeQuestion() => inner.revealFreeQuestion();

  @override
  Future<VoteResult> getDailyVoteState(String questionId) =>
      inner.getDailyVoteState(questionId);

  // The history's vote tallies are live (they keep changing) and premium-gated,
  // so it goes straight to the server every open rather than serving a stale
  // cache; offline it throws and the sheet shows its retry state.
  @override
  Future<List<DailyHistoryEntry>> fetchDailyHistory() =>
      inner.fetchDailyHistory();

  @override
  Future<VoteResult> castDailyVote(String questionId, int choice) =>
      inner.castDailyVote(questionId, choice);

  @override
  Future<void> markQuestionSeen(String questionId) =>
      inner.markQuestionSeen(questionId);

  @override
  Future<bool> toggleFavorite(String questionId) =>
      inner.toggleFavorite(questionId);

  // ---- Helpers ---------------------------------------------------------------

  /// Reads from [read], but treats a premium-tagged cache as empty when the
  /// current identity is NOT premium — and wipes it — so a lapsed subscriber
  /// can't keep reading the full pool offline. Returns null when there's nothing
  /// safe to serve.
  Future<T?> _readPremiumSafe<T>(T? Function() read) async {
    if (cache.cachedAsPremium && !isPremium) {
      await cache.clearContent();
      return null;
    }
    return read();
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
