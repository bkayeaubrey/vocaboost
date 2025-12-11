import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for progress data to avoid redundant queries
  Map<String, dynamic>? _cachedProgressData;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 1);

  /// Get all progress data with minimized Firestore reads.
  ///
  /// This method is an optimized replacement for calling
  /// getProgressStatistics, getWeeklyProgress, getWordMastery and
  /// getPronunciationScore separately. It:
  /// - Reads `saved_words` once
  /// - Reads `quiz_results` once
  /// - Computes overall stats, weekly chart data, word mastery,
  ///   and pronunciation stats in a single pass over the data.
  ///
  /// Return shape:
  /// {
  ///   'stats': <String, dynamic>,
  ///   'weeklyData': <List<Map<String, dynamic>>>,
  ///   'wordMastery': <String, dynamic>,
  ///   'pronunciationScore': <String, dynamic>,
  /// }
  Future<Map<String, dynamic>> getAllProgressData({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'stats': {
          'totalSavedWords': 0,
          'totalQuizzes': 0,
          'averageQuizScore': 0.0,
          'totalQuestionsAnswered': 0,
          'correctAnswers': 0,
          'overallAccuracy': 0.0,
        },
        'weeklyData': <Map<String, dynamic>>[],
        'wordMastery': {
          'wordStats': <String, Map<String, int>>{},
          'masteredWords': 0,
          'learningWords': 0,
          'totalWords': 0,
        },
        'pronunciationScore': {
          'totalPronunciationQuizzes': 0,
          'averagePronunciationScore': 0.0,
          'totalPronunciationQuestions': 0,
          'correctPronunciations': 0,
          'pronunciationAccuracy': 0.0,
        },
      };
    }

    // Return cached data if available and not expired
    if (!forceRefresh && 
        _cachedProgressData != null && 
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedProgressData!;
    }

    try {
      // Fetch saved words and quiz results in parallel.
      // Optimize by using orderBy for quiz results to ensure efficient queries
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved_words')
            .get(),
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('quiz_results')
            .orderBy('timestamp', descending: true)
            .get(),
      ]);

      final savedWordsSnapshot = results[0];
      final quizResultsSnapshot = results[1];

      // ---------- Overall statistics ----------
      int totalSavedWords = savedWordsSnapshot.docs.length;
      int totalQuizzes = quizResultsSnapshot.docs.length;
      int totalScore = 0;
      int totalQuestions = 0;
      int correctAnswers = 0;

      // ---------- Weekly progress ----------
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      Map<String, int> dailyScores = {};

      // ---------- Word mastery ----------
      Map<String, Map<String, int>> wordStats = {};

      // ---------- Pronunciation stats ----------
      int totalPronunciationQuizzes = 0;
      int totalPronunciationQuestions = 0;
      int correctPronunciations = 0;
      int totalPronunciationScore = 0;

      for (var doc in quizResultsSnapshot.docs) {
        final data = doc.data();

        final score = (data['score'] as num?)?.toInt() ?? 0;
        final questionsCount =
            (data['totalQuestions'] as num?)?.toInt() ?? 0;
        totalScore += score;
        totalQuestions += questionsCount;
        correctAnswers += score;

        // Weekly progress: group scores by day for last 7 days.
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          if (!date.isBefore(weekAgo)) {
            final dayKey = '${date.year}-${date.month}-${date.day}';
            dailyScores[dayKey] =
                (dailyScores[dayKey] ?? 0) + score;
          }
        }

        // Common question data for word mastery & pronunciation.
        final questions = data['questions'] as List<dynamic>? ?? [];
        final selectedAnswers =
            data['selectedAnswers'] as List<dynamic>? ?? [];

        // Determine if this quiz is a pronunciation quiz.
        bool isPronunciationQuiz = false;
        if (questions.isNotEmpty) {
          final firstQuestion = questions[0] as Map<String, dynamic>?;
          isPronunciationQuiz = firstQuestion?.containsKey('word') ?? false;
        }

        if (isPronunciationQuiz) {
          totalPronunciationQuizzes++;
          totalPronunciationQuestions += questionsCount;
          correctPronunciations += score;
          totalPronunciationScore += score;
        }

        // Word mastery: process each question (optimized loop)
        final questionsLength = questions.length;
        final answersLength = selectedAnswers.length;
        final maxLength = questionsLength < answersLength ? questionsLength : answersLength;
        
        for (int i = 0; i < maxLength; i++) {
          final question = questions[i] as Map<String, dynamic>?;
          if (question == null) continue;
          
          final selectedAnswer = selectedAnswers[i];

          String? word;
          bool isCorrect = false;

          // Optimize: check for word field first (most common case)
          if (question.containsKey('word')) {
            // Voice / pronunciation quiz format.
            word = (question['word'] as String?)?.toLowerCase();
            // Voice quiz uses -1 for correct answers in selectedAnswers.
            isCorrect = selectedAnswer == -1;
          } else if (question.containsKey('question') &&
              question.containsKey('correct')) {
            // Text quiz format.
            final correctIndex = question['correct'] as int? ?? -1;
            final answers = question['answers'] as List<dynamic>? ?? [];

            // Prefer bisayaWord field if available (for top words display)
            if (question.containsKey('bisayaWord')) {
              word = (question['bisayaWord'] as String?)?.toLowerCase();
            } else {
              final questionText = question['question'] as String? ?? '';
              if (questionText.isNotEmpty && questionText.contains('"')) {
                final match = RegExp(r'"([^"]+)"').firstMatch(questionText);
                word = match?.group(1)?.toLowerCase();
              } else if (correctIndex >= 0 &&
                  correctIndex < answers.length) {
                word = (answers[correctIndex] as String?)?.toLowerCase();
              }
            }

            isCorrect = selectedAnswer == correctIndex;
          }

          if (word != null && word.isNotEmpty) {
            final stats = wordStats.putIfAbsent(
                word, () => <String, int>{'correct': 0, 'total': 0});
            stats['total'] = (stats['total'] ?? 0) + 1;
            if (isCorrect) {
              stats['correct'] = (stats['correct'] ?? 0) + 1;
            }
          }
        }
      }

      // Final overall stats.
      double averageQuizScore =
          totalQuizzes > 0 ? (totalScore / totalQuizzes) : 0.0;
      double overallAccuracy = totalQuestions > 0
          ? (correctAnswers / totalQuestions * 100)
          : 0.0;

      final stats = {
        'totalSavedWords': totalSavedWords,
        'totalQuizzes': totalQuizzes,
        'averageQuizScore': averageQuizScore,
        'totalQuestionsAnswered': totalQuestions,
        'correctAnswers': correctAnswers,
        'overallAccuracy': overallAccuracy,
      };

      // Build weekly data list for last 7 days.
      List<Map<String, dynamic>> weeklyData = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month}-${date.day}';
        weeklyData.add({
          'day': date.day,
          'score': dailyScores[dayKey] ?? 0,
        });
      }

      // Word mastery tallies.
      int masteredWords = 0;
      int learningWords = 0;

      wordStats.forEach((_, stats) {
        final correct = stats['correct'] ?? 0;
        final total = stats['total'] ?? 1;
        final accuracy = (correct / total) * 100;

        if (total >= 2 && accuracy >= 80) {
          masteredWords++;
        } else {
          learningWords++;
        }
      });

      final wordMastery = {
        'wordStats': wordStats,
        'masteredWords': masteredWords,
        'learningWords': learningWords,
        'totalWords': wordStats.length,
      };

      // Pronunciation summary.
      double averagePronunciationScore =
          totalPronunciationQuizzes > 0
              ? (totalPronunciationScore / totalPronunciationQuizzes)
              : 0.0;
      double pronunciationAccuracy =
          totalPronunciationQuestions > 0
              ? (correctPronunciations /
                      totalPronunciationQuestions *
                      100)
                  : 0.0;

      final pronunciationScore = {
        'totalPronunciationQuizzes': totalPronunciationQuizzes,
        'averagePronunciationScore': averagePronunciationScore,
        'totalPronunciationQuestions': totalPronunciationQuestions,
        'correctPronunciations': correctPronunciations,
        'pronunciationAccuracy': pronunciationAccuracy,
      };

      final result = {
        'stats': stats,
        'weeklyData': weeklyData,
        'wordMastery': wordMastery,
        'pronunciationScore': pronunciationScore,
      };
      
      // Cache the result
      _cachedProgressData = result;
      _cacheTimestamp = DateTime.now();
      
      return result;
    } catch (e) {
      throw Exception('Failed to get all progress data: $e');
    }
  }

  /// Get progressive learning statistics
  Future<Map<String, dynamic>> getProgressiveLearningStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'currentLevel': 1,
        'currentWordIndex': 0,
        'learnedWordsCount': 0,
        'learnedWordIndices': <int>[],
        'levelCorrectCount': 0,
        'levelTotalCount': 0,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      
      return {
        'currentLevel': data['currentLevel'] ?? 1,
        'currentWordIndex': data['currentWordIndex'] ?? 0,
        'learnedWordsCount': (data['learnedWordIndices'] as List<dynamic>?)?.length ?? 0,
        'learnedWordIndices': (data['learnedWordIndices'] as List<dynamic>?)?.cast<int>() ?? <int>[],
        'levelCorrectCount': data['levelCorrectCount'] ?? 0,
        'levelTotalCount': data['levelTotalCount'] ?? 0,
      };
    } catch (e) {
      throw Exception('Failed to get progressive learning stats: $e');
    }
  }
  
  /// Clear the progress data cache
  void clearCache() {
    _cachedProgressData = null;
    _cacheTimestamp = null;
  }

  /// Get overall progress statistics
  Future<Map<String, dynamic>> getProgressStatistics() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalSavedWords': 0,
        'totalQuizzes': 0,
        'averageQuizScore': 0.0,
        'totalQuestionsAnswered': 0,
        'correctAnswers': 0,
        'overallAccuracy': 0.0,
      };
    }

    try {
      // Get saved words count
      final savedWordsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .get();

      // Get quiz results
      final quizResultsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();

      int totalSavedWords = savedWordsSnapshot.docs.length;
      int totalQuizzes = quizResultsSnapshot.docs.length;
      int totalScore = 0;
      int totalQuestions = 0;
      int correctAnswers = 0;

      for (var doc in quizResultsSnapshot.docs) {
        final data = doc.data();
        final score = (data['score'] as num?)?.toInt() ?? 0;
        final questions = (data['totalQuestions'] as num?)?.toInt() ?? 0;
        totalScore += score;
        totalQuestions += questions;
        correctAnswers += score;
      }

      double averageQuizScore = totalQuizzes > 0 ? (totalScore / totalQuizzes) : 0.0;
      double overallAccuracy = totalQuestions > 0
          ? (correctAnswers / totalQuestions * 100)
          : 0.0;

      return {
        'totalSavedWords': totalSavedWords,
        'totalQuizzes': totalQuizzes,
        'averageQuizScore': averageQuizScore,
        'totalQuestionsAnswered': totalQuestions,
        'correctAnswers': correctAnswers,
        'overallAccuracy': overallAccuracy,
      };
    } catch (e) {
      throw Exception('Failed to get progress statistics: $e');
    }
  }

  /// Get weekly progress data for charts
  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      // Get quiz results from last 7 days
      final quizSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      // Group by day
      Map<String, int> dailyScores = {};
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayKey = '${date.year}-${date.month}-${date.day}';
          dailyScores[dayKey] = (dailyScores[dayKey] ?? 0) + ((data['score'] as num?)?.toInt() ?? 0);
        }
      }

      // Convert to list format
      List<Map<String, dynamic>> weeklyData = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month}-${date.day}';
        weeklyData.add({
          'day': date.day,
          'score': dailyScores[dayKey] ?? 0,
        });
      }

      return weeklyData;
    } catch (e) {
      throw Exception('Failed to get weekly progress: $e');
    }
  }

  /// Get word mastery statistics
  Future<Map<String, dynamic>> getWordMastery() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'wordStats': <String, Map<String, int>>{},
        'masteredWords': 0,
        'learningWords': 0,
        'totalWords': 0,
      };
    }

    try {
      // Get all quiz results
      final quizResultsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();

      // Track word statistics: {word: {correct: count, total: count}}
      Map<String, Map<String, int>> wordStats = {};

      for (var doc in quizResultsSnapshot.docs) {
        final data = doc.data();
        final questions = data['questions'] as List<dynamic>? ?? [];
        final selectedAnswers = data['selectedAnswers'] as List<dynamic>? ?? [];

        // Process each question
        for (int i = 0; i < questions.length && i < selectedAnswers.length; i++) {
          final question = questions[i] as Map<String, dynamic>;
          final selectedAnswer = selectedAnswers[i];
          
          String? word;
          bool isCorrect = false;

          // Check if it's a voice quiz (has 'word' field)
          if (question.containsKey('word')) {
            word = (question['word'] as String?)?.toLowerCase();
            // For voice quiz, check if answer was correct
            // Voice quiz uses -1 for correct answers in selectedAnswers
            isCorrect = selectedAnswer == -1;
          } 
          // Check if it's a text quiz (has 'question' field)
          else if (question.containsKey('question') && question.containsKey('correct')) {
            final correctIndex = question['correct'] as int? ?? -1;
            final answers = question['answers'] as List<dynamic>? ?? [];
            
            // Prefer bisayaWord field if available (for top words display)
            if (question.containsKey('bisayaWord')) {
              word = (question['bisayaWord'] as String?)?.toLowerCase();
            } else {
              // Extract word from question text or correct answer
              final questionText = question['question'] as String? ?? '';
              if (questionText.contains('"')) {
                // Extract word from quotes
                final match = RegExp(r'"([^"]+)"').firstMatch(questionText);
                word = match?.group(1)?.toLowerCase();
              } else if (correctIndex >= 0 && correctIndex < answers.length) {
                // Use the correct answer as the word
                word = (answers[correctIndex] as String?)?.toLowerCase();
              }
            }
            
            isCorrect = selectedAnswer == correctIndex;
          }

          if (word != null && word.isNotEmpty) {
            wordStats.putIfAbsent(word, () => {'correct': 0, 'total': 0});
            wordStats[word]!['total'] = (wordStats[word]!['total'] ?? 0) + 1;
            if (isCorrect) {
              wordStats[word]!['correct'] = (wordStats[word]!['correct'] ?? 0) + 1;
            }
          }
        }
      }

      // Calculate mastered words (>= 80% accuracy with at least 2 attempts)
      int masteredWords = 0;
      int learningWords = 0;
      
      wordStats.forEach((word, stats) {
        final correct = stats['correct'] ?? 0;
        final total = stats['total'] ?? 1;
        final accuracy = (correct / total) * 100;
        
        if (total >= 2 && accuracy >= 80) {
          masteredWords++;
        } else {
          learningWords++;
        }
      });

      return {
        'wordStats': wordStats,
        'masteredWords': masteredWords,
        'learningWords': learningWords,
        'totalWords': wordStats.length,
      };
    } catch (e) {
      throw Exception('Failed to get word mastery: $e');
    }
  }

  /// Get pronunciation score statistics
  Future<Map<String, dynamic>> getPronunciationScore() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalPronunciationQuizzes': 0,
        'averagePronunciationScore': 0.0,
        'totalPronunciationQuestions': 0,
        'correctPronunciations': 0,
        'pronunciationAccuracy': 0.0,
      };
    }

    try {
      // Get all quiz results
      final quizResultsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();

      int totalPronunciationQuizzes = 0;
      int totalPronunciationQuestions = 0;
      int correctPronunciations = 0;
      int totalScore = 0;

      for (var doc in quizResultsSnapshot.docs) {
        final data = doc.data();
        final questions = data['questions'] as List<dynamic>? ?? [];
        
        // Check if this is a pronunciation quiz (has 'word' field in questions)
        bool isPronunciationQuiz = false;
        if (questions.isNotEmpty) {
          final firstQuestion = questions[0] as Map<String, dynamic>?;
          isPronunciationQuiz = firstQuestion?.containsKey('word') ?? false;
        }

        if (isPronunciationQuiz) {
          final score = (data['score'] as num?)?.toInt() ?? 0;
          final totalQuestions = (data['totalQuestions'] as num?)?.toInt() ?? 0;
          
          totalPronunciationQuizzes++;
          totalPronunciationQuestions += totalQuestions;
          correctPronunciations += score;
          totalScore += score;
        }
      }

      double averagePronunciationScore = totalPronunciationQuizzes > 0
          ? (totalScore / totalPronunciationQuizzes)
          : 0.0;
      double pronunciationAccuracy = totalPronunciationQuestions > 0
          ? (correctPronunciations / totalPronunciationQuestions * 100)
          : 0.0;

      return {
        'totalPronunciationQuizzes': totalPronunciationQuizzes,
        'averagePronunciationScore': averagePronunciationScore,
        'totalPronunciationQuestions': totalPronunciationQuestions,
        'correctPronunciations': correctPronunciations,
        'pronunciationAccuracy': pronunciationAccuracy,
      };
    } catch (e) {
      throw Exception('Failed to get pronunciation score: $e');
    }
  }
}

