import '../mock/mock_questions.dart';
import '../models/question.dart';
import '../../services/supabase_service.dart';

/// Abstraction over the source of questions.
///
/// The app talks to this interface only, so the underlying source can move from
/// the local mock list to Supabase without touching the UI or providers.
abstract class QuestionRepository {
  Future<List<Question>> fetchQuestions();

  Future<Question?> fetchDailyQuestion(DateTime date);
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
}

/// Supabase-backed implementation used in production builds.
///
/// Expects the schema from `supabase/schema.sql`. The app only reads from the
/// public tables; inserts/updates should happen through Supabase Dashboard or a
/// separate admin surface protected by service-role credentials.
class SupabaseQuestionRepository implements QuestionRepository {
  const SupabaseQuestionRepository({this.locale = 'pl'});

  final String locale;

  @override
  Future<List<Question>> fetchQuestions() async {
    final rows = await SupabaseService.client
        .from('questions')
        .select()
        .eq('is_active', true)
        .eq('locale', locale)
        .order('created_at');

    return rows
        .map<Question>((row) => Question.fromJson(row))
        .where((question) => question.questionText.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<Question?> fetchDailyQuestion(DateTime date) async {
    final row = await SupabaseService.client
        .from('daily_questions')
        .select('questions(*)')
        .eq('publish_date', _dateOnly(date))
        .eq('locale', locale)
        .maybeSingle();

    final questionJson = row?['questions'] as Map<String, dynamic>?;
    if (questionJson == null) return null;

    final question = Question.fromJson(questionJson);
    return question.questionText.trim().isEmpty ? null : question;
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
