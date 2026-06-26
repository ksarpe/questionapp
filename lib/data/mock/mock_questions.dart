import '../models/question.dart';

/// Seed questions used to populate the UI before Supabase is wired up.
///
/// Once the `questions` table is live, swap the repository over to the remote
/// data source and keep this list only for offline/preview/testing.
const List<Question> kMockQuestions = [
  Question(
    id: '1',
    category: 'Connection',
    questionText:
        'What is a belief you held strongly five years ago that you no longer hold?',
  ),
  Question(
    id: '2',
    category: 'Dreams',
    questionText:
        'If money were no object, how would you spend the next ten years?',
  ),
  Question(
    id: '3',
    category: 'Reflection',
    questionText:
        'When did you last change your mind about something important?',
  ),
  Question(
    id: '4',
    category: 'Connection',
    questionText: 'What does someone do that instantly earns your trust?',
  ),
  Question(
    id: '5',
    category: 'Values',
    questionText:
        'What is something you are proud of but rarely get to talk about?',
    isPremium: true,
  ),
  Question(
    id: '6',
    category: 'Reflection',
    questionText: 'What is a small thing that reliably makes your day better?',
  ),
];
