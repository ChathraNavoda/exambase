import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class ExamBaseApp extends StatelessWidget {
  const ExamBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamBase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: Text('ExamBase is connected to Firebase 🎉')),
      ),
    );
  }
}
