import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking and calculating learning accuracy
/// Provides realistic and high-accuracy metrics for Bisaya learning
class LearningAccuracyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Record a flashcard interaction
  /// 
  /// [word] - The Bisaya word
  /// [isCorrect] - Whether the user answered correctly
  /// [timeSpent] - Time spent on the card in seconds
  /// [attempts] - Number of attempts before getting it right
  Future<void> recordFlashcardInteraction({
    required String word,
    required bool isCorrect,
    int timeSpent = 0,
    int attempts = 1,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final wordRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .doc(word.toLowerCase());

      final wordDoc = await wordRef.get();
      final existingData = wordDoc.data() ?? {};

      final totalInteractions = (existingData['totalInteractions'] ?? 0) + 1;
      final correctCount = (existingData['correctCount'] ?? 0) + (isCorrect ? 1 : 0);
      final totalTimeSpent = (existingData['totalTimeSpent'] ?? 0) + timeSpent;
      final totalAttempts = (existingData['totalAttempts'] ?? 0) + attempts;
      final lastAttempted = DateTime.now().toIso8601String();

      // Calculate accuracy percentage
      final accuracy = totalInteractions > 0
          ? (correctCount / totalInteractions * 100)
          : 0.0;

      // Calculate average time per interaction
      final avgTimeSpent = totalInteractions > 0
          ? (totalTimeSpent / totalInteractions)
          : 0.0;

      // Calculate mastery level (0-100)
      final masteryLevel = _calculateMasteryLevel(
        accuracy: accuracy,
        totalInteractions: totalInteractions,
        avgTimeSpent: avgTimeSpent,
        avgAttempts: totalInteractions > 0 ? (totalAttempts / totalInteractions) : 0.0,
      );

      await wordRef.set({
        'word': word,
        'totalInteractions': totalInteractions,
        'correctCount': correctCount,
        'accuracy': accuracy,
        'totalTimeSpent': totalTimeSpent,
        'avgTimeSpent': avgTimeSpent,
        'totalAttempts': totalAttempts,
        'masteryLevel': masteryLevel,
        'lastAttempted': lastAttempted,
        'firstAttempted': existingData['firstAttempted'] ?? lastAttempted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording flashcard interaction: $e');
    }
  }

  /// Record a practice mode exercise result
  /// 
  /// [word] - The Bisaya word
  /// [isCorrect] - Whether the user answered correctly
  /// [exerciseType] - Type of exercise (fill_in_blank, multiple_choice, etc.)
  /// [timeSpent] - Time spent on the exercise in seconds
  Future<void> recordPracticeExercise({
    required String word,
    required bool isCorrect,
    required String exerciseType,
    int timeSpent = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final wordRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .doc(word.toLowerCase());

      final wordDoc = await wordRef.get();
      final existingData = wordDoc.data() ?? {};

      final practiceData = existingData['practiceData'] as Map<String, dynamic>? ?? {};
      final exerciseData = practiceData[exerciseType] as Map<String, dynamic>? ?? {};

      final totalExercises = (exerciseData['total'] ?? 0) + 1;
      final correctExercises = (exerciseData['correct'] ?? 0) + (isCorrect ? 1 : 0);
      final totalTime = (exerciseData['totalTime'] ?? 0) + timeSpent;

      practiceData[exerciseType] = {
        'total': totalExercises,
        'correct': correctExercises,
        'accuracy': totalExercises > 0 ? (correctExercises / totalExercises * 100) : 0.0,
        'totalTime': totalTime,
        'avgTime': totalExercises > 0 ? (totalTime / totalExercises) : 0.0,
      };

      await wordRef.set({
        'practiceData': practiceData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording practice exercise: $e');
    }
  }

  /// Get learning accuracy for a specific word
  Future<Map<String, dynamic>?> getWordAccuracy(String word) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final wordDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .doc(word.toLowerCase())
          .get();

      if (!wordDoc.exists) return null;

      return wordDoc.data();
    } catch (e) {
      debugPrint('Error getting word accuracy: $e');
      return null;
    }
  }

  /// Get overall learning accuracy statistics
  Future<Map<String, dynamic>> getOverallAccuracy() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalWords': 0,
        'averageAccuracy': 0.0,
        'masteredWords': 0,
        'learningWords': 0,
        'strugglingWords': 0,
      };
    }

    try {
      final accuracySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .get();

      if (accuracySnapshot.docs.isEmpty) {
        return {
          'totalWords': 0,
          'averageAccuracy': 0.0,
          'masteredWords': 0,
          'learningWords': 0,
          'strugglingWords': 0,
        };
      }

      int totalWords = 0;
      double totalAccuracy = 0.0;
      int masteredWords = 0;
      int learningWords = 0;
      int strugglingWords = 0;

      for (var doc in accuracySnapshot.docs) {
        final data = doc.data();
        final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
        final masteryLevel = (data['masteryLevel'] as num?)?.toDouble() ?? 0.0;
        final totalInteractions = (data['totalInteractions'] as num?)?.toInt() ?? 0;

        if (totalInteractions > 0) {
          totalWords++;
          totalAccuracy += accuracy;

          if (masteryLevel >= 80 && totalInteractions >= 3) {
            masteredWords++;
          } else if (accuracy < 50 && totalInteractions >= 2) {
            strugglingWords++;
          } else {
            learningWords++;
          }
        }
      }

      final averageAccuracy = totalWords > 0 ? (totalAccuracy / totalWords) : 0.0;

      return {
        'totalWords': totalWords,
        'averageAccuracy': averageAccuracy,
        'masteredWords': masteredWords,
        'learningWords': learningWords,
        'strugglingWords': strugglingWords,
      };
    } catch (e) {
      debugPrint('Error getting overall accuracy: $e');
      return {
        'totalWords': 0,
        'averageAccuracy': 0.0,
        'masteredWords': 0,
        'learningWords': 0,
        'strugglingWords': 0,
      };
    }
  }

  /// Get words that need more practice (low accuracy or struggling)
  Future<List<Map<String, dynamic>>> getWordsNeedingPractice({int limit = 10}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final accuracySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .where('accuracy', isLessThan: 70.0)
          .orderBy('accuracy')
          .limit(limit)
          .get();

      return accuracySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'word': data['word'] ?? doc.id,
          'accuracy': (data['accuracy'] as num?)?.toDouble() ?? 0.0,
          'masteryLevel': (data['masteryLevel'] as num?)?.toDouble() ?? 0.0,
          'totalInteractions': (data['totalInteractions'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting words needing practice: $e');
      return [];
    }
  }

  /// Calculate mastery level (0-100) based on multiple factors
  double _calculateMasteryLevel({
    required double accuracy,
    required int totalInteractions,
    required double avgTimeSpent,
    required double avgAttempts,
  }) {
    // Base mastery from accuracy (0-60 points)
    double mastery = accuracy * 0.6;

    // Bonus for consistency (more interactions = more reliable) (0-20 points)
    if (totalInteractions >= 10) {
      mastery += 20;
    } else if (totalInteractions >= 5) {
      mastery += 15;
    } else if (totalInteractions >= 3) {
      mastery += 10;
    } else if (totalInteractions >= 2) {
      mastery += 5;
    }

    // Bonus for speed (faster = better understanding) (0-10 points)
    if (avgTimeSpent > 0) {
      if (avgTimeSpent <= 3) {
        mastery += 10; // Very fast
      } else if (avgTimeSpent <= 5) {
        mastery += 7; // Fast
      } else if (avgTimeSpent <= 8) {
        mastery += 4; // Moderate
      } else {
        mastery += 1; // Slow
      }
    }

    // Bonus for fewer attempts (first try = better) (0-10 points)
    if (avgAttempts <= 1.2) {
      mastery += 10; // Usually gets it right on first try
    } else if (avgAttempts <= 1.5) {
      mastery += 7;
    } else if (avgAttempts <= 2.0) {
      mastery += 4;
    } else {
      mastery += 1;
    }

    return mastery.clamp(0.0, 100.0);
  }

  /// Get learning progress over time
  Future<List<Map<String, dynamic>>> getLearningProgress({int days = 7}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final accuracySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_accuracy')
          .get();

      final now = DateTime.now();
      final progress = <Map<String, dynamic>>[];

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month}-${date.day}';

        int wordsLearned = 0;
        double dailyAccuracy = 0.0;
        int totalInteractions = 0;

        for (var doc in accuracySnapshot.docs) {
          final data = doc.data();
          final firstAttempted = data['firstAttempted'] as String?;
          final lastAttempted = data['lastAttempted'] as String?;

          if (firstAttempted != null) {
            final firstDate = DateTime.tryParse(firstAttempted);
            if (firstDate != null && 
                firstDate.year == date.year &&
                firstDate.month == date.month &&
                firstDate.day == date.day) {
              wordsLearned++;
            }
          }

          if (lastAttempted != null) {
            final lastDate = DateTime.tryParse(lastAttempted);
            if (lastDate != null &&
                lastDate.year == date.year &&
                lastDate.month == date.month &&
                lastDate.day == date.day) {
              final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
              dailyAccuracy += accuracy;
              totalInteractions += (data['totalInteractions'] as num?)?.toInt() ?? 0;
            }
          }
        }

        progress.add({
          'date': dayKey,
          'day': date.day,
          'wordsLearned': wordsLearned,
          'averageAccuracy': totalInteractions > 0 ? (dailyAccuracy / totalInteractions) : 0.0,
          'totalInteractions': totalInteractions,
        });
      }

      return progress;
    } catch (e) {
      debugPrint('Error getting learning progress: $e');
      return [];
    }
  }
}

