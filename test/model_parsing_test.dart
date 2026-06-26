import 'package:debatly/data/models/question.dart';
import 'package:debatly/data/models/rank.dart';
import 'package:debatly/data/models/smaczek.dart';
import 'package:debatly/data/models/user_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// `fromJson` is the contract boundary between the app and the SQL RPCs: every
/// column name and null-handling rule here mirrors what the server returns. A
/// silent schema drift (a renamed column, a type change, a newly-nullable field)
/// would surface as a crash or a leak in production, so these pin the mapping —
/// including the *fail-safe* defaults that decide gating when a field is absent.
void main() {
  group('Question.fromJson', () {
    test('maps an RPC row, coercing a numeric id and reading the teaser', () {
      final q = Question.fromJson(const {
        'id': 42, // RPCs may return a bigint, not a string
        'category': 'money',
        'question_text': 'Czy pieniądze dają szczęście?',
        'teaser': 'Czy pieniądze',
        'locked': true,
      });
      expect(q.id, '42');
      expect(q.category, 'money');
      expect(q.questionText, 'Czy pieniądze dają szczęście?');
      expect(q.teaser, 'Czy pieniądze');
      expect(q.isLocked, true);
    });

    test('a daily-shape row without `locked` defaults to unlocked', () {
      // get_daily_question omits `locked` — the daily is always readable.
      final q = Question.fromJson(const {'id': 'd1', 'question_text': 'Hej?'});
      expect(q.isLocked, false);
      expect(q.category, 'general'); // fallback when absent
      expect(q.teaser, isNull);
    });

    test(
      '`seen` is read from get_questions and defaults false when absent',
      () {
        // Only get_questions returns `seen`; the daily / reveal shapes omit it.
        expect(
          Question.fromJson(const {'id': 'q1', 'seen': true}).seen,
          isTrue,
        );
        expect(Question.fromJson(const {'id': 'q2'}).seen, isFalse);
      },
    );
  });

  group('Smaczek.fromJson', () {
    test('an unlocked row carries its text', () {
      final s = Smaczek.fromJson(const {
        'position': 1,
        'is_locked': false,
        'text': 'Zapytaj o konkretny przykład.',
      });
      expect(s.isLocked, false);
      expect(s.text, 'Zapytaj o konkretny przykład.');
    });

    test('a locked row arrives without text', () {
      final s = Smaczek.fromJson(const {'position': 2, 'is_locked': true});
      expect(s.isLocked, true);
      expect(s.text, isNull);
    });

    test(
      'a missing is_locked fails safe to locked — never leak unflagged text',
      () {
        final s = Smaczek.fromJson(const {'position': 3});
        expect(s.isLocked, true);
      },
    );
  });

  group('Rank', () {
    test('fromJson maps both locale names plus tier/minStreak', () {
      final r = Rank.fromJson(const {
        'tier': 2,
        'min_streak': 7,
        'name_pl': 'Podżegacz',
        'name_en': 'Instigator',
        'icon': 'flame',
      });
      expect(r.tier, 2);
      expect(r.minStreak, 7);
      expect(r.nameFor('pl'), 'Podżegacz');
      expect(r.nameFor('en'), 'Instigator');
      expect(r.nameFor('de'), 'Instigator', reason: 'non-pl falls back to en');
    });

    test('the default ladder is contiguous and strictly increasing', () {
      // The rank-selection logic (_currentRank/_nextRank) assumes the ladder is
      // ordered by ascending tier *and* minStreak; guard that invariant.
      expect(
        kDefaultRanks.first.minStreak,
        0,
        reason: 'the entry rank must be reachable from a zero streak',
      );
      for (var i = 1; i < kDefaultRanks.length; i++) {
        expect(kDefaultRanks[i].tier, kDefaultRanks[i - 1].tier + 1);
        expect(
          kDefaultRanks[i].minStreak,
          greaterThan(kDefaultRanks[i - 1].minStreak),
        );
      }
    });
  });

  group('UserStats.fromJson grace window', () {
    Map<String, Object?> row({Object? grace}) => {
      'current_streak': 5,
      'longest_streak': 9,
      'free_unlock_credits': 1,
      'rank_tier': 1,
      'rank_name': 'Prowokator',
      'next_rank_streak': 7,
      'grace_days_left': grace,
    };

    test(
      'a null grace_days_left means the streak is intact (no freeze badge)',
      () {
        expect(UserStats.fromJson(row(grace: null)).graceDaysLeft, isNull);
      },
    );

    test(
      'a present grace_days_left is parsed (mid-freeze, about to drop a tier)',
      () {
        expect(UserStats.fromJson(row(grace: 2)).graceDaysLeft, 2);
      },
    );
  });
}
