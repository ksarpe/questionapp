import 'package:flutter_test/flutter_test.dart';
import 'package:questionapp/data/models/daily_history_entry.dart';
import 'package:questionapp/data/models/vote_result.dart';
import 'package:questionapp/data/repositories/question_repository.dart';

void main() {
  group('DailyHistoryEntry.fromJson', () {
    test('maps the get_daily_history row shape, folding in the vote split', () {
      final entry = DailyHistoryEntry.fromJson({
        'question_id': 'q-1',
        'category': 'Ethics',
        'question_text': 'Czy kara śmierci powinna istnieć?',
        'publish_date': '2026-06-22',
        'yes_count': 7,
        'no_count': 3,
        'my_choice': 1,
      });

      expect(entry.questionId, 'q-1');
      expect(entry.category, 'Ethics');
      expect(entry.questionText, 'Czy kara śmierci powinna istnieć?');
      expect(entry.publishDate, DateTime(2026, 6, 22));
      expect(entry.votes.yesCount, 7);
      expect(entry.votes.noCount, 3);
      expect(entry.votes.total, 10);
      expect(entry.votes.yesPct, 70);
      expect(entry.votes.myChoice, VoteResult.yes);
    });

    test('treats a null my_choice as "not voted"', () {
      final entry = DailyHistoryEntry.fromJson({
        'question_id': 'q-2',
        'category': 'Society',
        'question_text': 'Pytanie?',
        'publish_date': '2026-06-20',
        'yes_count': 0,
        'no_count': 0,
        'my_choice': null,
      });

      expect(entry.votes.hasVoted, isFalse);
      expect(entry.votes.total, 0);
    });
  });

  group('MockQuestionRepository.fetchDailyHistory', () {
    test('returns past-dated entries, one per day, newest first', () async {
      const repo = MockQuestionRepository();
      final history = await repo.fetchDailyHistory();

      expect(history, isNotEmpty);

      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      // Every entry is strictly before today …
      for (final e in history) {
        expect(e.publishDate.isBefore(todayMidnight), isTrue);
      }
      // … and they descend in date (newest first).
      for (var i = 1; i < history.length; i++) {
        expect(
          history[i].publishDate.isBefore(history[i - 1].publishDate),
          isTrue,
        );
      }
    });
  });
}
