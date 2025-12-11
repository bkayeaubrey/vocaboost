import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing skill mastery levels (0-5 crowns) per word
/// Implements Duolingo-style mastery progression
class SkillMasteryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mastery level requirements
  static const Map<int, Map<String, int>> _masteryRequirements = {
    1: {'correctCount': 3, 'minAccuracy': 0},
    2: {'correctCount': 6, 'minAccuracy': 80},
    3: {'correctCount': 10, 'minAccuracy': 85},
    4: {'correctCount': 15, 'minAccuracy': 90},
    5: {'correctCount': 20, 'minAccuracy': 95},
  };

  /// Update mastery level for a word based on performance
  /// 
  /// [wordId] - The word ID
  /// [isCorrect] - Whether the answer was correct
  /// [difficulty] - Difficulty level of the question (1-5)
  /// [word] - The Bisaya word (for display)
  /// [category] - Word category
  Future<Map<String, dynamic>> updateMastery({
    required String wordId,
    required bool isCorrect,
    required int difficulty,
    String? word,
    String? category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to update mastery');
    }

    try {
      // Get current mastery data
      final masteryDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .doc(wordId)
          .get();

      int correctCount = 0;
      int totalAttempts = 0;
      int currentLevel = 0;
      DateTime? lastMastered;
      List<bool> recentAttempts = [];

      if (masteryDoc.exists) {
        final data = masteryDoc.data()!;
        correctCount = (data['correctCount'] as num?)?.toInt() ?? 0;
        totalAttempts = (data['totalAttempts'] as num?)?.toInt() ?? 0;
        currentLevel = (data['masteryLevel'] as num?)?.toInt() ?? 0;
        lastMastered = (data['lastMastered'] as Timestamp?)?.toDate();
        recentAttempts = List<bool>.from(data['recentAttempts'] as List? ?? []);
      }

      // Update counts
      totalAttempts++;
      if (isCorrect) {
        correctCount++;
      }

      // Keep only last 10 attempts for accuracy calculation
      recentAttempts.add(isCorrect);
      if (recentAttempts.length > 10) {
        recentAttempts.removeAt(0);
      }

      // Calculate accuracy from recent attempts
      final recentAccuracy = recentAttempts.isEmpty
          ? 0.0
          : (recentAttempts.where((a) => a).length / recentAttempts.length * 100);

      // Check if mastery level should increase
      int newLevel = currentLevel;
      bool leveledUp = false;

      // Check each level requirement
      for (int level = currentLevel + 1; level <= 5; level++) {
        final requirements = _masteryRequirements[level]!;
        final requiredCorrect = requirements['correctCount']!;
        final requiredAccuracy = requirements['minAccuracy']!;

        if (correctCount >= requiredCorrect && recentAccuracy >= requiredAccuracy) {
          // Check for level 5 special requirement (no errors in 7 days)
          if (level == 5) {
            final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
            if (lastMastered != null && lastMastered.isAfter(sevenDaysAgo)) {
              // Check if there were any errors in the last 7 days
              final errorDoc = await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_words')
                  .doc(wordId)
                  .get();

              if (errorDoc.exists) {
                final errorData = errorDoc.data()!;
                final lastError = (errorData['lastError'] as Timestamp?)?.toDate();
                if (lastError != null && lastError.isAfter(sevenDaysAgo)) {
                  continue; // Has errors in last 7 days, can't reach level 5
                }
              }
            }
          }

          newLevel = level;
          leveledUp = true;
          lastMastered = DateTime.now();
        } else {
          break; // Can't reach this level yet
        }
      }

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .doc(wordId)
          .set({
        'wordId': wordId,
        'word': word,
        'category': category,
        'masteryLevel': newLevel,
        'correctCount': correctCount,
        'totalAttempts': totalAttempts,
        'recentAccuracy': recentAccuracy,
        'recentAttempts': recentAttempts,
        'lastMastered': lastMastered != null ? Timestamp.fromDate(lastMastered) : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'masteryLevel': newLevel,
        'leveledUp': leveledUp,
        'correctCount': correctCount,
        'totalAttempts': totalAttempts,
        'recentAccuracy': recentAccuracy,
        'progressToNextLevel': _getProgressToNextLevel(newLevel, correctCount, recentAccuracy),
      };
    } catch (e) {
      debugPrint('Error updating mastery: $e');
      throw Exception('Failed to update mastery: $e');
    }
  }

  /// Get progress percentage to next mastery level
  double _getProgressToNextLevel(int currentLevel, int correctCount, double accuracy) {
    if (currentLevel >= 5) return 100.0;

    final nextLevel = currentLevel + 1;
    final requirements = _masteryRequirements[nextLevel]!;
    final requiredCorrect = requirements['correctCount']!;
    final requiredAccuracy = requirements['minAccuracy']!;

    final correctProgress = (correctCount / requiredCorrect * 50).clamp(0.0, 50.0);
    final accuracyProgress = (accuracy / requiredAccuracy * 50).clamp(0.0, 50.0);

    return (correctProgress + accuracyProgress).clamp(0.0, 100.0);
  }

  /// Get mastery level for a word
  Future<int> getMasteryLevel(String wordId) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final masteryDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .doc(wordId)
          .get();

      if (!masteryDoc.exists) return 0;

      final data = masteryDoc.data()!;
      return (data['masteryLevel'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting mastery level: $e');
      return 0;
    }
  }

  /// Get all skills by minimum mastery level
  Future<List<Map<String, dynamic>>> getSkillsByLevel(int minLevel) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .where('masteryLevel', isGreaterThanOrEqualTo: minLevel)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'wordId': doc.id,
          'word': data['word'] as String? ?? '',
          'category': data['category'] as String? ?? '',
          'masteryLevel': (data['masteryLevel'] as num?)?.toInt() ?? 0,
          'correctCount': (data['correctCount'] as num?)?.toInt() ?? 0,
          'totalAttempts': (data['totalAttempts'] as num?)?.toInt() ?? 0,
          'recentAccuracy': (data['recentAccuracy'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting skills by level: $e');
      return [];
    }
  }

  /// Get mastery progress for a category
  Future<Map<String, dynamic>> getMasteryProgress(String category) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalWords': 0,
        'masteredWords': 0,
        'averageLevel': 0.0,
        'crowns': 0,
      };
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .where('category', isEqualTo: category)
          .get();

      int totalWords = snapshot.docs.length;
      int masteredWords = 0;
      int totalCrowns = 0;
      double totalLevel = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level = (data['masteryLevel'] as num?)?.toInt() ?? 0;
        totalLevel += level;
        totalCrowns += level;
        if (level >= 5) {
          masteredWords++;
        }
      }

      return {
        'totalWords': totalWords,
        'masteredWords': masteredWords,
        'averageLevel': totalWords > 0 ? totalLevel / totalWords : 0.0,
        'crowns': totalCrowns,
        'masteryPercentage': totalWords > 0 ? (masteredWords / totalWords * 100) : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting mastery progress: $e');
      return {
        'totalWords': 0,
        'masteredWords': 0,
        'averageLevel': 0.0,
        'crowns': 0,
      };
    }
  }

  /// Get all mastery data for dashboard/skill tree
  Future<Map<String, dynamic>> getAllMasteryData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalWords': 0,
        'masteredWords': 0,
        'totalCrowns': 0,
        'byCategory': <String, Map<String, dynamic>>{},
        'byLevel': <int, int>{},
      };
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('skill_mastery')
          .get();

      int totalWords = snapshot.docs.length;
      int masteredWords = 0;
      int totalCrowns = 0;
      Map<String, Map<String, dynamic>> byCategory = {};
      Map<int, int> byLevel = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final level = (data['masteryLevel'] as num?)?.toInt() ?? 0;
        final category = data['category'] as String? ?? 'Uncategorized';

        totalCrowns += level;
        byLevel[level] = (byLevel[level] ?? 0) + 1;

        if (level >= 5) {
          masteredWords++;
        }

        if (!byCategory.containsKey(category)) {
          byCategory[category] = {
            'totalWords': 0,
            'masteredWords': 0,
            'totalCrowns': 0,
          };
        }

        final categoryData = byCategory[category];
        if (categoryData != null) {
          categoryData['totalWords'] = (categoryData['totalWords'] as int) + 1;
          categoryData['totalCrowns'] = (categoryData['totalCrowns'] as int) + level;
          if (level >= 5) {
            categoryData['masteredWords'] = (categoryData['masteredWords'] as int) + 1;
          }
        }
      }

      return {
        'totalWords': totalWords,
        'masteredWords': masteredWords,
        'totalCrowns': totalCrowns,
        'byCategory': byCategory,
        'byLevel': byLevel,
      };
    } catch (e) {
      debugPrint('Error getting all mastery data: $e');
      return {
        'totalWords': 0,
        'masteredWords': 0,
        'totalCrowns': 0,
        'byCategory': <String, Map<String, dynamic>>{},
        'byLevel': <int, int>{},
      };
    }
  }
}

