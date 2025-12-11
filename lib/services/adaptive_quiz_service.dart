import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/progress_service.dart';

/// Service for adaptive quiz difficulty adjustment
class AdaptiveQuizService {
  final ProgressService _progressService = ProgressService();

  /// Calculate difficulty level based on user performance
  /// Returns 1-5 (1=easiest, 5=hardest)
  Future<int> calculateAdaptiveDifficulty({
    required double recentAccuracy, // 0.0-1.0
    required int totalQuestionsAnswered,
    int currentDifficulty = 3,
  }) async {
    // If user has answered few questions, start with medium difficulty
    if (totalQuestionsAnswered < 5) {
      return 3;
    }

    int newDifficulty = currentDifficulty;

    // Adjust based on recent accuracy
    if (recentAccuracy >= 0.8) {
      // High accuracy - increase difficulty
      newDifficulty = (currentDifficulty + 1).clamp(1, 5);
    } else if (recentAccuracy >= 0.6) {
      // Good accuracy - maintain or slightly increase
      newDifficulty = currentDifficulty;
    } else if (recentAccuracy >= 0.4) {
      // Moderate accuracy - maintain or slightly decrease
      newDifficulty = (currentDifficulty - 0.5).round().clamp(1, 5);
    } else {
      // Low accuracy - decrease difficulty
      newDifficulty = (currentDifficulty - 1).clamp(1, 5);
    }

    return newDifficulty;
  }

  /// Get words appropriate for current difficulty level
  /// 
  /// [allWords] - List of all available words with metadata
  /// [targetDifficulty] - Target difficulty level (1-5)
  /// [count] - Number of words to return
  List<Map<String, dynamic>> selectWordsByDifficulty({
    required List<Map<String, dynamic>> allWords,
    required int targetDifficulty,
    required int count,
  }) {
    // Calculate difficulty for each word
    final wordsWithDifficulty = allWords.map((word) {
      final wordText = (word['bisaya'] as String? ?? word['word'] as String? ?? '').toLowerCase();
      final difficulty = _calculateWordDifficulty(wordText, word);
      return {
        'word': word,
        'difficulty': difficulty,
        'distance': (difficulty - targetDifficulty).abs(),
      };
    }).toList();

    // Sort by distance from target difficulty, then randomize slightly
    wordsWithDifficulty.sort((a, b) {
      final distanceCompare = (a['distance'] as int).compareTo(b['distance'] as int);
      if (distanceCompare != 0) return distanceCompare;
      // If same distance, randomize
      return (DateTime.now().millisecondsSinceEpoch % 2 == 0) ? -1 : 1;
    });

    // Take words closest to target difficulty
    return wordsWithDifficulty
        .take(count)
        .map((item) => item['word'] as Map<String, dynamic>)
        .toList();
  }

  /// Calculate word difficulty based on characteristics
  int _calculateWordDifficulty(String word, Map<String, dynamic> metadata) {
    int difficulty = 1; // Start with easiest

    // Factor 1: Word length
    if (word.length > 8) difficulty += 1;
    if (word.length > 12) difficulty += 2;

    // Factor 2: Phonetic complexity
    final complexPatterns = ['ng', 'nga', 'kaon', 'gikaon', 'nag', 'kinahanglan'];
    for (var pattern in complexPatterns) {
      if (word.contains(pattern)) {
        difficulty += 1;
        break;
      }
    }

    // Factor 3: Affix complexity
    final affixPatterns = ['nag', 'mag', 'gi', 'ka', 'kinahanglan', 'mahinumduman'];
    int affixCount = 0;
    for (var affix in affixPatterns) {
      if (word.contains(affix)) {
        affixCount++;
      }
    }
    if (affixCount >= 2) difficulty += 1;
    if (affixCount >= 3) difficulty += 2;

    // Factor 4: Part of speech (verbs are generally harder)
    final pos = (metadata['partOfSpeech'] as String? ?? '').toLowerCase();
    if (pos.contains('verb')) difficulty += 1;

    // Clamp between 1 and 5
    return difficulty.clamp(1, 5);
  }

  /// Adjust quiz content dynamically based on real-time performance
  /// 
  /// [currentQuestions] - Current questions in quiz
  /// [answeredQuestions] - Questions already answered with results
  /// [availableWords] - Pool of available words
  /// 
  /// Returns updated question list with adjusted difficulty
  Future<List<Map<String, dynamic>>> adjustQuizContent({
    required List<Map<String, dynamic>> currentQuestions,
    required List<Map<String, dynamic>> answeredQuestions,
    required List<Map<String, dynamic>> availableWords,
  }) async {
    if (answeredQuestions.isEmpty) {
      return currentQuestions; // No adjustments needed yet
    }

    // Calculate current performance
    int correct = 0;
    int total = answeredQuestions.length;
    for (final question in answeredQuestions) {
      if (question['isCorrect'] == true) {
        correct++;
      }
    }
    final accuracy = total > 0 ? correct / total : 0.5;

    // Determine target difficulty based on performance
    int targetDifficulty = 3; // Default medium
    if (accuracy >= 0.8) {
      targetDifficulty = 4; // Increase difficulty
    } else if (accuracy >= 0.6) {
      targetDifficulty = 3; // Maintain
    } else if (accuracy >= 0.4) {
      targetDifficulty = 2; // Decrease slightly
    } else {
      targetDifficulty = 1; // Decrease significantly
    }

    // Get remaining questions to adjust
    final remainingCount = currentQuestions.length - answeredQuestions.length;
    if (remainingCount <= 0) {
      return currentQuestions; // No remaining questions
    }

    // Select new questions with adjusted difficulty
    final newQuestions = selectWordsByDifficulty(
      allWords: availableWords,
      targetDifficulty: targetDifficulty,
      count: remainingCount,
    );

    // Replace remaining questions with adjusted ones
    final updatedQuestions = List<Map<String, dynamic>>.from(currentQuestions);
    for (int i = answeredQuestions.length; i < updatedQuestions.length && 
         (i - answeredQuestions.length) < newQuestions.length; i++) {
      final newWord = newQuestions[i - answeredQuestions.length];
      // Create question from new word
      updatedQuestions[i] = {
        'word': newWord['bisaya'] ?? newWord['word'],
        'pronunciation': newWord['pronunciation'] ?? '',
        'meaning': newWord['english'] ?? '',
        'correctAnswer': newWord['bisaya'] ?? newWord['word'],
        'alternatives': _generateAlternatives(newWord, availableWords),
        'tip': 'Listen carefully to the pronunciation guide',
      };
    }

    return updatedQuestions;
  }

  /// Generate alternative answers for a question
  List<String> _generateAlternatives(
    Map<String, dynamic> word,
    List<Map<String, dynamic>> allWords,
  ) {
    final alternatives = <String>[];
    final wordText = (word['bisaya'] as String? ?? word['word'] as String? ?? '').toLowerCase();
    
    // Add the word itself
    alternatives.add(wordText);
    
    // Add similar words (same length, similar structure)
    for (final otherWord in allWords) {
      if (alternatives.length >= 4) break;
      final otherText = (otherWord['bisaya'] as String? ?? otherWord['word'] as String? ?? '').toLowerCase();
      if (otherText != wordText && 
          otherText.length >= wordText.length - 2 && 
          otherText.length <= wordText.length + 2) {
        alternatives.add(otherText);
      }
    }
    
    return alternatives.toSet().toList();
  }

  /// Get user's recent performance statistics
  Future<Map<String, dynamic>> getRecentPerformance() async {
    try {
      final progressData = await _progressService.getAllProgressData();
      final stats = progressData['stats'] as Map<String, dynamic>?;
      
      if (stats == null) {
        return {
          'recentAccuracy': 0.5,
          'totalQuestions': 0,
          'averageScore': 0.0,
        };
      }

      final totalQuestions = stats['totalQuestionsAnswered'] as int? ?? 0;
      final correctAnswers = stats['correctAnswers'] as int? ?? 0;
      final recentAccuracy = totalQuestions > 0 ? correctAnswers / totalQuestions : 0.5;

      return {
        'recentAccuracy': recentAccuracy,
        'totalQuestions': totalQuestions,
        'averageScore': stats['averageQuizScore'] as double? ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting recent performance: $e');
      return {
        'recentAccuracy': 0.5,
        'totalQuestions': 0,
        'averageScore': 0.0,
      };
    }
  }
}

