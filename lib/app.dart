import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/questions/screens/question_screen.dart';

/// Root widget. Riverpod's `ProviderScope` is mounted in `main()`.
class QuestionApp extends StatelessWidget {
  const QuestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const QuestionScreen(),
    );
  }
}
