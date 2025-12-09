import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const QuizScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  int _score = 0;
  bool _answered = false;
  final QuizService _quizService = QuizService();
  final List<int?> _selectedAnswers = []; // Track all selected answers

  // Text Quiz - Multiple Choice Questions
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'What is the meaning of "Panagsa"?',
      'answers': ['Sometimes', 'Always', 'Never', 'Everyday'],
      'correct': 0,
    },
    {
      'question': 'What is the Bisaya word for "Beautiful"?',
      'answers': ['Gwapa', 'Maayo', 'Tambok', 'Taas'],
      'correct': 0,
    },
    {
      'question': 'Translate "Water" into Bisaya.',
      'answers': ['Tubig', 'Kahoy', 'Hangin', 'Apoy'],
      'correct': 0,
    },
    {
      'question': 'What does "Maayo" mean?',
      'answers': ['Good', 'Bad', 'Big', 'Small'],
      'correct': 0,
    },
    {
      'question': 'What is the Bisaya word for "Hello"?',
      'answers': ['Kumusta', 'Salamat', 'Palangga', 'Gwapa'],
      'correct': 0,
    },
    {
      'question': 'Translate "Thank you" into Bisaya.',
      'answers': ['Salamat', 'Kumusta', 'Maayo', 'Gwapa'],
      'correct': 0,
    },
  ];

  void _answerQuestion(int index) {
    if (_answered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      _selectedAnswers.add(index); // Save the selected answer

      if (index == currentQuestion['correct']) {
        _score++;
      }
    });

    // Automatically move to next question after 1.5 seconds
    Future.delayed(const Duration(seconds: 1), () {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _answered = false;
          _selectedAnswerIndex = null;
        });
      } else {
        _saveQuizResult();
        _showFinalScore();
      }
    });
  }

  Future<void> _saveQuizResult() async {
    try {
      await _quizService.saveQuizResult(
        score: _score,
        totalQuestions: _questions.length,
        questions: _questions,
        selectedAnswers: _selectedAnswers,
      );
    } catch (e) {
      // Silently fail - quiz results are saved but user doesn't need to see errors
      debugPrint('Failed to save quiz result: $e');
    }
  }

  void _showFinalScore() {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
        title: const Text('Text Quiz Completed!'),
        content: Text('Your score is $_score out of ${_questions.length}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentQuestionIndex = 0;
                _score = 0;
                _answered = false;
                _selectedAnswerIndex = null;
                _selectedAnswers.clear(); // Clear previous answers
              });
            },
            child: const Text('Restart'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Blue Hour Harbor Palette
    final Color kPrimary = const Color(0xFF3B5FAE);
    final Color accentColor = const Color(0xFF2666B4);
    final Color backgroundColor = isDark ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = isDark ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF071B34);

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Text Quiz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => widget.onToggleDarkMode(!isDark),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score Display
            Text(
              'Score: $_score / ${_questions.length}',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : accentColor,
              ),
            ),
            const SizedBox(height: 20),

            // Quiz Title
            Text(
              'Text Quiz - Multiple Choice',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),

            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                currentQuestion['question'],
                style: GoogleFonts.poppins(fontSize: 18, color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),

            // Answer Buttons
            ...List.generate(currentQuestion['answers'].length, (index) {
              final answer = currentQuestion['answers'][index];

              Color buttonColor;
              Color textColorButton;

              if (_answered) {
                if (index == currentQuestion['correct']) {
                  buttonColor = Colors.green;
                  textColorButton = Colors.white;
                } else if (index == _selectedAnswerIndex &&
                    index != currentQuestion['correct']) {
                  buttonColor = Colors.redAccent;
                  textColorButton = Colors.white;
                } else {
                  buttonColor = cardColor;
                  textColorButton = isDark ? Colors.white : const Color(0xFF071B34);
                }
              } else {
                buttonColor = cardColor;
                textColorButton = isDark ? Colors.white : const Color(0xFF071B34);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  onPressed: () => _answerQuestion(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: textColorButton,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(answer),
                ),
              );
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
