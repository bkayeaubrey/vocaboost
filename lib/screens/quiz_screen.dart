import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/quiz_service.dart';
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/translation_service.dart';
import 'package:vocaboost/services/adaptive_quiz_service.dart';
import 'package:vocaboost/services/flashcard_service.dart';
import 'dart:math';

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
  final TranslationService _translationService = TranslationService();
  final AdaptiveQuizService _adaptiveQuizService = AdaptiveQuizService();
  final FlashcardService _flashcardService = FlashcardService();
  final List<int?> _selectedAnswers = []; // Track all selected answers
  final NLPModelService _nlpService = NLPModelService.instance;
  final Map<String, int> _incorrectCount = {}; // Track consecutive incorrect answers per word
  bool _isLoading = true;
  bool _modelLoaded = false;
  int _currentDifficulty = 3; // Start with medium difficulty
  final List<Map<String, dynamic>> _answeredQuestions = []; // Track answered questions for adaptation

  // Text Quiz - Multiple Choice Questions (HARDCODED - COMMENTED OUT)
  // Now using NLPModelService to generate questions dynamically
  /*
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
  */
  
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadModelAndGenerateQuestions();
  }

  Future<void> _playBeep() async {
    try {
      // Play system beep sound for correct answer
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Beep sound error: $e');
    }
  }

  Future<void> _loadModelAndGenerateQuestions() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      if (!_nlpService.isLoaded) {
        await _nlpService.loadModel();
      }
      setState(() {
        _modelLoaded = true;
      });
      await _generateQuestions();
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQuestions() async {
    if (!_modelLoaded) return;

    // Get user's recent performance to determine initial difficulty
    final performance = await _adaptiveQuizService.getRecentPerformance();
    _currentDifficulty = await _adaptiveQuizService.calculateAdaptiveDifficulty(
      recentAccuracy: performance['recentAccuracy'] as double,
      totalQuestionsAnswered: performance['totalQuestions'] as int,
      currentDifficulty: _currentDifficulty,
    );

    final questions = <Map<String, dynamic>>[];
    final random = Random();
    final allWords = _nlpService.getAllWords();
    
    if (allWords.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Convert words to metadata format for adaptive selection
    final wordsWithMetadata = allWords.map((word) {
      final metadata = _nlpService.getWordMetadata(word);
      if (metadata == null) return null;
      return {
        'bisaya': metadata['bisaya'] ?? word,
        'english': metadata['english'] ?? '',
        'tagalog': metadata['tagalog'] ?? '',
        'partOfSpeech': metadata['partOfSpeech'] ?? 'Unknown',
        'pronunciation': metadata['pronunciation'] ?? '',
      };
    }).where((item) => item != null).cast<Map<String, dynamic>>().toList();

    // Use adaptive service to select words by difficulty
    final selectedWords = _adaptiveQuizService.selectWordsByDifficulty(
      allWords: wordsWithMetadata,
      targetDifficulty: _currentDifficulty,
      count: 10,
    );

    // Generate questions from selected words
    for (final wordData in selectedWords) {
      final bisaya = wordData['bisaya'] as String? ?? '';
      final english = wordData['english'] as String? ?? '';

      if (english.isEmpty || bisaya.isEmpty) continue;

      // Randomly choose question type
      final questionType = random.nextInt(3);
      
      if (questionType == 0) {
        // "What is the meaning of [Bisaya word]?"
        final correctAnswer = english;
        // Get similar words using bisaya word
        final bisayaWordForSimilarity = bisaya.toLowerCase();
        final similarWords = await _nlpService.getSimilarWords(bisayaWordForSimilarity, count: 3);
        final wrongAnswers = <String>[];
        
        for (final similarWord in similarWords) {
          final similarMeta = _nlpService.getWordMetadata(similarWord);
          if (similarMeta != null) {
            final similarEnglish = similarMeta['english'] as String? ?? '';
            if (similarEnglish.isNotEmpty && similarEnglish != correctAnswer) {
              wrongAnswers.add(similarEnglish);
            }
          }
        }
        
        // Fill with random words if needed
        while (wrongAnswers.length < 3) {
          final randomWord = allWords[random.nextInt(allWords.length)];
          final randomMeta = _nlpService.getWordMetadata(randomWord);
          if (randomMeta != null) {
            final randomEnglish = randomMeta['english'] as String? ?? '';
            if (randomEnglish.isNotEmpty && 
                randomEnglish != correctAnswer && 
                !wrongAnswers.contains(randomEnglish)) {
              wrongAnswers.add(randomEnglish);
            }
          }
        }

        final answers = [correctAnswer, ...wrongAnswers.take(3)];
        answers.shuffle(random);
        final correctIndex = answers.indexOf(correctAnswer);

        questions.add({
          'question': 'What is the meaning of "$bisaya"?',
          'answers': answers,
          'correct': correctIndex,
          'bisayaWord': bisaya,
        });
      } else if (questionType == 1) {
        // "What is the Bisaya word for [English word]?"
        final correctAnswer = bisaya;
        final bisayaWordForSimilarity = bisaya.toLowerCase();
        final similarWords = await _nlpService.getSimilarWords(bisayaWordForSimilarity, count: 3);
        final wrongAnswers = <String>[];
        
        for (final similarWord in similarWords) {
          final similarMeta = _nlpService.getWordMetadata(similarWord);
          if (similarMeta != null) {
            final similarBisaya = similarMeta['bisaya'] as String? ?? similarWord;
            if (similarBisaya != correctAnswer && !wrongAnswers.contains(similarBisaya)) {
              wrongAnswers.add(similarBisaya);
            }
          }
        }
        
        while (wrongAnswers.length < 3) {
          final randomWord = allWords[random.nextInt(allWords.length)];
          final randomMeta = _nlpService.getWordMetadata(randomWord);
          if (randomMeta != null) {
            final randomBisaya = randomMeta['bisaya'] as String? ?? randomWord;
            if (randomBisaya != correctAnswer && 
                !wrongAnswers.contains(randomBisaya)) {
              wrongAnswers.add(randomBisaya);
            }
          }
        }

        final answers = [correctAnswer, ...wrongAnswers.take(3)];
        answers.shuffle(random);
        final correctIndex = answers.indexOf(correctAnswer);

        questions.add({
          'question': 'What is the Bisaya word for "$english"?',
          'answers': answers,
          'correct': correctIndex,
          'bisayaWord': bisaya,
        });
      } else {
        // "Translate [English word] into Bisaya."
        final correctAnswer = bisaya;
        final bisayaWordForSimilarity = bisaya.toLowerCase();
        final similarWords = await _nlpService.getSimilarWords(bisayaWordForSimilarity, count: 3);
        final wrongAnswers = <String>[];
        
        for (final similarWord in similarWords) {
          final similarMeta = _nlpService.getWordMetadata(similarWord);
          if (similarMeta != null) {
            final similarBisaya = similarMeta['bisaya'] as String? ?? similarWord;
            if (similarBisaya != correctAnswer && !wrongAnswers.contains(similarBisaya)) {
              wrongAnswers.add(similarBisaya);
            }
          }
        }
        
        while (wrongAnswers.length < 3) {
          final randomWord = allWords[random.nextInt(allWords.length)];
          final randomMeta = _nlpService.getWordMetadata(randomWord);
          if (randomMeta != null) {
            final randomBisaya = randomMeta['bisaya'] as String? ?? randomWord;
            if (randomBisaya != correctAnswer && 
                !wrongAnswers.contains(randomBisaya)) {
              wrongAnswers.add(randomBisaya);
            }
          }
        }

        final answers = [correctAnswer, ...wrongAnswers.take(3)];
        answers.shuffle(random);
        final correctIndex = answers.indexOf(correctAnswer);

        questions.add({
          'question': 'Translate "$english" into Bisaya.',
          'answers': answers,
          'correct': correctIndex,
          'bisayaWord': bisaya,
        });
      }
    }

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _answerQuestion(int index) async {
    if (_answered || _questions.isEmpty) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final bisayaWord = currentQuestion['bisayaWord'] as String? ?? '';
    final isCorrect = index == currentQuestion['correct'];
    
    // Track answered question for adaptive learning
    _answeredQuestions.add({
      ...currentQuestion,
      'isCorrect': isCorrect,
    });
    
    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      _selectedAnswers.add(index); // Save the selected answer

      if (isCorrect) {
        _score++;
        // Play beep sound for correct answer
        _playBeep();
        // Reset incorrect count for this word
        if (bisayaWord.isNotEmpty) {
          _incorrectCount[bisayaWord] = 0;
        }
      } else {
        // Track incorrect answer
        if (bisayaWord.isNotEmpty) {
          _incorrectCount[bisayaWord] = (_incorrectCount[bisayaWord] ?? 0) + 1;
          
          // Auto-save if incorrect 3 times in a row
          if (_incorrectCount[bisayaWord]! >= 3) {
            _autoSaveWord(bisayaWord);
            _incorrectCount[bisayaWord] = 0; // Reset after saving
          }
        }
      }
    });

    // Adapt quiz content based on performance (after 3+ questions answered)
    if (_answeredQuestions.length >= 3 && _currentQuestionIndex < _questions.length - 1) {
      try {
        final allWords = _nlpService.getAllWords().map((word) {
          final metadata = _nlpService.getWordMetadata(word);
          if (metadata == null) return null;
          return {
            'bisaya': metadata['bisaya'] ?? word,
            'english': metadata['english'] ?? '',
            'tagalog': metadata['tagalog'] ?? '',
            'partOfSpeech': metadata['partOfSpeech'] ?? 'Unknown',
            'pronunciation': metadata['pronunciation'] ?? '',
          };
        }).where((item) => item != null).cast<Map<String, dynamic>>().toList();

        final updatedQuestions = await _adaptiveQuizService.adjustQuizContent(
          currentQuestions: _questions,
          answeredQuestions: _answeredQuestions,
          availableWords: allWords,
        );

        if (mounted && updatedQuestions.length == _questions.length) {
          setState(() {
            _questions = updatedQuestions;
          });
        }
      } catch (e) {
        debugPrint('Error adapting quiz: $e');
      }
    }

    // Automatically move to next question after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
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

  Future<void> _autoSaveWord(String bisayaWord) async {
    try {
      final metadata = _nlpService.getWordMetadata(bisayaWord);
      if (metadata != null) {
        final english = metadata['english'] as String? ?? '';
        if (english.isNotEmpty) {
          await _translationService.saveTranslation(
            input: bisayaWord,
            output: english,
            fromLanguage: 'Bisaya',
            toLanguage: 'English',
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to auto-save word: $e');
    }
  }

  Future<void> _saveQuizResult() async {
    try {
      await _quizService.saveQuizResult(
        score: _score,
        totalQuestions: _questions.length,
        questions: _questions,
        selectedAnswers: _selectedAnswers,
      );
      
      // Update learning streak when quiz is completed
      await _flashcardService.updateLearningStreak();
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
                _answeredQuestions.clear(); // Clear answered questions
                _currentDifficulty = 3; // Reset difficulty
              });
              _generateQuestions(); // Regenerate with fresh difficulty
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: kPrimary,
          title: const Text(
            'Text Quiz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _modelLoaded 
                    ? 'Generating questions...' 
                    : 'Loading model...',
                style: GoogleFonts.poppins(color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: kPrimary,
          title: const Text(
            'Text Quiz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: textColor.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'No questions available. Please check your model files.',
                style: GoogleFonts.poppins(color: textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Text Quiz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
