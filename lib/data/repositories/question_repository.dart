import '../mock/mock_questions.dart';
import '../models/question.dart';
import '../models/smaczek.dart';
import '../../services/supabase_service.dart';

/// Abstraction over the source of questions.
///
/// The app talks to this interface only, so the underlying source can move from
/// the local mock list to Supabase without touching the UI or providers.
abstract class QuestionRepository {
  Future<List<Question>> fetchQuestions();

  Future<Question?> fetchDailyQuestion(DateTime date);

  /// The discussion prompts ("smaczki") for a single question.
  ///
  /// The source applies the premium gate: a free user gets the first smaczek
  /// readable plus the rest as locked placeholders (no text), premium users get
  /// them all. See [Smaczek].
  Future<List<Smaczek>> fetchSmaczki(String questionId);
}

/// Default implementation backed by the in-memory mock list.
///
/// Replace with a `SupabaseQuestionRepository` (querying the `questions` table)
/// when the backend is ready — the [QuestionRepository] contract stays the same.
class MockQuestionRepository implements QuestionRepository {
  const MockQuestionRepository();

  @override
  Future<List<Question>> fetchQuestions() async {
    // Simulate a small network delay so loading states are exercised in the UI.
    await Future.delayed(const Duration(milliseconds: 300));
    return kMockQuestions;
  }

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (kMockQuestions.isEmpty) return null;

    return kMockQuestions[date.day % kMockQuestions.length];
  }

  @override
  Future<List<Smaczek>> fetchSmaczki(String questionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Dev/offline preview mirrors the free-tier shape the RPC returns: the
    // first smaczek is readable, the rest come back locked (no text). Premium
    // can't be exercised without real RevenueCat config, so mock mode is always
    // the free view.
    return const [
      Smaczek(
        position: 1,
        isLocked: false,
        text:
            'Zapytaj o konkretny przykład z ostatniego tygodnia — konkret '
            'otwiera rozmowę szybciej niż ogólniki.',
      ),
      Smaczek(position: 2, isLocked: true),
      Smaczek(position: 3, isLocked: true),
    ];
  }
}

/// Supabase-backed implementation used in production builds.
///
/// Matches the schema in `supabase/migrations/20260618120000_init.sql`:
/// question text lives in `question_translations` (one row per locale) and is
/// gated by RLS, so a free user only receives the text they may read (today's
/// daily + unlocked) while a premium user receives all of it. Writes never
/// happen here — content is managed via the dashboard / service-role.
class SupabaseQuestionRepository implements QuestionRepository {
  const SupabaseQuestionRepository({this.locale = 'pl'});

  final String locale;

  @override
  Future<List<Question>> fetchQuestions() async {
    // Drive the query from question_translations so the locale text comes back
    // flat; RLS decides which rows the current user is allowed to read.
    final rows = await SupabaseService.client
        .from('question_translations')
        .select('question_text, questions!inner(id, category, is_premium)')
        .eq('locale', locale)
        .eq('questions.is_active', true);

    return rows
        .map<Question>((row) {
          final q = row['questions'] as Map<String, dynamic>;
          return Question.fromJson({
            ...q,
            'question_text': row['question_text'],
          });
        })
        .where((question) => question.questionText.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async {
    // The RPC returns the flat shape Question.fromJson expects and applies the
    // free-daily / premium gate itself.
    final data = await SupabaseService.client.rpc(
      'get_daily_question',
      params: {'p_locale': locale, 'p_date': _dateOnly(date)},
    );

    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;

    final question = Question.fromJson(rows.first);
    return question.questionText.trim().isEmpty ? null : question;
  }

  @override
  Future<List<Smaczek>> fetchSmaczki(String questionId) async {
    // The RPC returns every smaczek for the question but withholds the text of
    // locked ones (premium-only beyond the first). RLS/grants are deliberately
    // off on the smaczki tables — this SECURITY DEFINER RPC is the only way in.
    final data = await SupabaseService.client.rpc(
      'get_question_smaczki',
      params: {'p_question_id': questionId, 'p_locale': locale},
    );

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Smaczek.fromJson)
        .toList();
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
