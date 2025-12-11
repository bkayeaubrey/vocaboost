import 'package:flutter/material.dart';
import 'learning_screen.dart';

class QuizSelectionScreen extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const QuizSelectionScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to Learning Screen
    return LearningScreen(
      isDarkMode: isDarkMode,
      onToggleDarkMode: onToggleDarkMode,
    );
  }
}


