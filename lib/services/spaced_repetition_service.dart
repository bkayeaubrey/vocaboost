import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/achievement_service.dart';

/// Service for managing spaced repetition algorithm
/// Implements SM-2 algorithm (SuperMemo 2) for optimal review scheduling
class SpacedRepetitionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AchievementService _achievementService = AchievementService();

  /// Calculate next review date using SM-2 algorithm
  /// 
  /// [quality] - User's performance (0-5 scale):
  ///   0: Complete blackout
  ///   1: Incorrect response, but remembered after seeing answer
  ///   2: Incorrect response, but correct one seems familiar
  ///   3: Correct response, but with serious difficulty
  ///   4: Correct response, but with hesitation
  ///   5: Perfect response
  /// 
  /// [easinessFactor] - Current easiness factor (default 2.5)
  /// [repetitions] - Number of successful repetitions
  /// [interval] - Current interval in days
  /// 
  /// Returns Map with: nextReviewDate, newEasinessFactor, newRepetitions, newInterval
  Map<String, dynamic> calculateNextReview({
    required int quality,
    double easinessFactor = 2.5,
    int repetitions = 0,
    int interval = 0,
  }) {
    // SM-2 Algorithm
    // Quality must be between 0-5
    quality = quality.clamp(0, 5);

    // Calculate new easiness factor
    double newEasinessFactor = easinessFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    
    // Minimum easiness factor is 1.3
    if (newEasinessFactor < 1.3) {
      newEasinessFactor = 1.3;
    }

    int newRepetitions = repetitions;
    int newInterval = interval;

    if (quality < 3) {
      // If quality is less than 3, reset repetitions
      newRepetitions = 0;
      newInterval = 1; // Review again tomorrow
    } else {
      // Successful recall
      newRepetitions = repetitions + 1;

      if (newRepetitions == 1) {
        newInterval = 1; // First review: tomorrow
      } else if (newRepetitions == 2) {
        newInterval = 6; // Second review: 6 days later
      } else {
        // Subsequent reviews: interval * easiness factor
        newInterval = (newInterval * newEasinessFactor).round();
      }
    }

    // Calculate next review date
    final nextReviewDate = DateTime.now().add(Duration(days: newInterval));

    return {
      'nextReviewDate': nextReviewDate,
      'easinessFactor': newEasinessFactor,
      'repetitions': newRepetitions,
      'interval': newInterval,
      'lastReviewed': DateTime.now(),
    };
  }

  /// Save or update word with spaced repetition data
  Future<void> saveWordForReview({
    required String word,
    required String translation,
    String? fromLanguage,
    String? toLanguage,
    int quality = 3, // Default quality for new words
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if word already exists
      final existingQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('input', isEqualTo: word)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing word
        final doc = existingQuery.docs.first;
        final data = doc.data();
        
        final currentEasinessFactor = (data['easinessFactor'] as num?)?.toDouble() ?? 2.5;
        final currentRepetitions = (data['repetitions'] as num?)?.toInt() ?? 0;
        final currentInterval = (data['interval'] as num?)?.toInt() ?? 0;

        final reviewData = calculateNextReview(
          quality: quality,
          easinessFactor: currentEasinessFactor,
          repetitions: currentRepetitions,
          interval: currentInterval,
        );

        await doc.reference.update({
          'easinessFactor': reviewData['easinessFactor'],
          'repetitions': reviewData['repetitions'],
          'interval': reviewData['interval'],
          'nextReviewDate': Timestamp.fromDate(reviewData['nextReviewDate'] as DateTime),
          'lastReviewed': Timestamp.fromDate(reviewData['lastReviewed'] as DateTime),
          'totalReviews': (data['totalReviews'] as num? ?? 0).toInt() + 1,
        });
      } else {
        // New word - initialize with first review
        final reviewData = calculateNextReview(quality: quality);

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved_words')
            .add({
          'input': word,
          'output': translation,
          'fromLanguage': fromLanguage ?? 'Bisaya',
          'toLanguage': toLanguage ?? 'English',
          'easinessFactor': reviewData['easinessFactor'],
          'repetitions': reviewData['repetitions'],
          'interval': reviewData['interval'],
          'nextReviewDate': Timestamp.fromDate(reviewData['nextReviewDate'] as DateTime),
          'lastReviewed': Timestamp.fromDate(reviewData['lastReviewed'] as DateTime),
          'totalReviews': 1,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Check words learned achievements for new words
        final wordsCount = await getLearnedWordsCount();
        await _achievementService.checkAndUnlockBadges(wordsLearned: wordsCount);
      }
    } catch (e) {
      debugPrint('Error saving word for review: $e');
      throw Exception('Failed to save word for review: $e');
    }
  }

  /// Record review result and update spaced repetition data
  Future<void> recordReviewResult({
    required String word,
    required int quality, // 0-5 scale
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('input', isEqualTo: word)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        debugPrint('Word not found for review: $word');
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();

      final currentEasinessFactor = (data['easinessFactor'] as num?)?.toDouble() ?? 2.5;
      final currentRepetitions = (data['repetitions'] as num?)?.toInt() ?? 0;
      final currentInterval = (data['interval'] as num?)?.toInt() ?? 0;

      final reviewData = calculateNextReview(
        quality: quality,
        easinessFactor: currentEasinessFactor,
        repetitions: currentRepetitions,
        interval: currentInterval,
      );

      await doc.reference.update({
        'easinessFactor': reviewData['easinessFactor'],
        'repetitions': reviewData['repetitions'],
        'interval': reviewData['interval'],
        'nextReviewDate': Timestamp.fromDate(reviewData['nextReviewDate'] as DateTime),
        'lastReviewed': Timestamp.fromDate(reviewData['lastReviewed'] as DateTime),
        'totalReviews': (data['totalReviews'] as num? ?? 0).toInt() + 1,
        'lastQuality': quality,
      });
    } catch (e) {
      debugPrint('Error recording review result: $e');
      throw Exception('Failed to record review result: $e');
    }
  }

  /// Get words due for review
  /// Returns words where nextReviewDate <= today
  /// [limit] - Maximum number of words to return (default: 50)
  /// [filterByLanguage] - Optional language filter (Bisaya, English, Tagalog)
  Future<List<Map<String, dynamic>>> getWordsDueForReview({
    int limit = 50,
    String? filterByLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final now = DateTime.now();
      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(now));

      // Apply language filter if specified
      if (filterByLanguage != null && filterByLanguage.isNotEmpty) {
        query = query.where('fromLanguage', isEqualTo: filterByLanguage);
      }

      final snapshot = await query
          .orderBy('nextReviewDate', descending: false)
          .limit(limit)
          .get();

      // Additional client-side filtering to ensure data integrity
      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            
            // Filter out words without required fields
            final input = data['input'] as String?;
            if (input == null || input.isEmpty) {
              return null;
            }
            // Filter out words without spaced repetition data (legacy words)
            if (data['nextReviewDate'] == null) {
              return null;
            }
            
            return {
              'id': doc.id,
              'word': input,
              'translation': (data['output'] as String?) ?? '',
              'fromLanguage': (data['fromLanguage'] as String?) ?? 'Bisaya',
              'toLanguage': (data['toLanguage'] as String?) ?? 'English',
              'easinessFactor': (data['easinessFactor'] as num?)?.toDouble() ?? 2.5,
              'repetitions': (data['repetitions'] as num?)?.toInt() ?? 0,
              'interval': (data['interval'] as num?)?.toInt() ?? 0,
              'nextReviewDate': (data['nextReviewDate'] as Timestamp?)?.toDate(),
              'lastReviewed': (data['lastReviewed'] as Timestamp?)?.toDate(),
              'totalReviews': (data['totalReviews'] as num?)?.toInt() ?? 0,
            };
          })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('Error getting words due for review: $e');
      // If composite index error, try without orderBy as fallback
      if (e.toString().contains('index')) {
        debugPrint('Index error detected, trying fallback query without orderBy');
        try {
          final now = DateTime.now();
          final snapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('saved_words')
              .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
              .limit(limit)
              .get();

          final results = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return null;
                
                final input = data['input'] as String?;
                if (input == null || input.isEmpty) {
                  return null;
                }
                if (data['nextReviewDate'] == null) {
                  return null;
                }
                
                final nextReview = (data['nextReviewDate'] as Timestamp?)?.toDate();
                return {
                  'id': doc.id,
                  'word': input,
                  'translation': (data['output'] as String?) ?? '',
                  'fromLanguage': (data['fromLanguage'] as String?) ?? 'Bisaya',
                  'toLanguage': (data['toLanguage'] as String?) ?? 'English',
                  'easinessFactor': (data['easinessFactor'] as num?)?.toDouble() ?? 2.5,
                  'repetitions': (data['repetitions'] as num?)?.toInt() ?? 0,
                  'interval': (data['interval'] as num?)?.toInt() ?? 0,
                  'nextReviewDate': nextReview,
                  'lastReviewed': (data['lastReviewed'] as Timestamp?)?.toDate(),
                  'totalReviews': (data['totalReviews'] as num?)?.toInt() ?? 0,
                };
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          
          // Sort client-side as fallback
          results.sort((a, b) {
            final dateA = a['nextReviewDate'] as DateTime?;
            final dateB = b['nextReviewDate'] as DateTime?;
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateA.compareTo(dateB);
          });
          
          return results;
        } catch (fallbackError) {
          debugPrint('Fallback query also failed: $fallbackError');
          return [];
        }
      }
      return [];
    }
  }

  /// Get all words with review statistics
  Future<List<Map<String, dynamic>>> getAllReviewWords() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .orderBy('nextReviewDate', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final nextReview = (data['nextReviewDate'] as Timestamp?)?.toDate();
        final isDue = nextReview != null && nextReview.isBefore(DateTime.now());

        return {
          'id': doc.id,
          'word': data['input'] ?? '',
          'translation': data['output'] ?? '',
          'fromLanguage': data['fromLanguage'] ?? 'Bisaya',
          'toLanguage': data['toLanguage'] ?? 'English',
          'easinessFactor': (data['easinessFactor'] as num?)?.toDouble() ?? 2.5,
          'repetitions': (data['repetitions'] as num?)?.toInt() ?? 0,
          'interval': (data['interval'] as num?)?.toInt() ?? 0,
          'nextReviewDate': nextReview,
          'lastReviewed': (data['lastReviewed'] as Timestamp?)?.toDate(),
          'totalReviews': (data['totalReviews'] as num?)?.toInt() ?? 0,
          'isDue': isDue,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting all review words: $e');
      return [];
    }
  }

  /// Get review statistics
  Future<Map<String, dynamic>> getReviewStatistics() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalWords': 0,
        'wordsDue': 0,
        'wordsMastered': 0,
        'averageEasinessFactor': 0.0,
      };
    }

    try {
      final allWords = await getAllReviewWords();

      int wordsDue = 0;
      int wordsMastered = 0;
      double totalEasiness = 0.0;

      for (final word in allWords) {
        if (word['isDue'] == true) {
          wordsDue++;
        }
        if ((word['repetitions'] as int) >= 5 && (word['easinessFactor'] as double) >= 2.5) {
          wordsMastered++;
        }
        totalEasiness += (word['easinessFactor'] as double);
      }

      return {
        'totalWords': allWords.length,
        'wordsDue': wordsDue,
        'wordsMastered': wordsMastered,
        'averageEasinessFactor': allWords.isNotEmpty ? totalEasiness / allWords.length : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting review statistics: $e');
      return {
        'totalWords': 0,
        'wordsDue': 0,
        'wordsMastered': 0,
        'averageEasinessFactor': 0.0,
      };
    }
  }

  /// Get the total count of learned words
  Future<int> getLearnedWordsCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting learned words count: $e');
      return 0;
    }
  }

  /// Import words from quiz results into the spaced repetition system
  /// This seeds the SR system with words the user has practiced
  Future<int> importWordsFromQuizResults() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      // Get quiz results
      final quizResults = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      int importedCount = 0;

      for (final doc in quizResults.docs) {
        final data = doc.data();
        final answers = data['answers'] as List<dynamic>? ?? [];

        for (final answer in answers) {
          if (answer is Map<String, dynamic>) {
            final word = answer['word'] as String?;
            final correctAnswer = answer['correctAnswer'] as String?;
            final isCorrect = answer['isCorrect'] as bool? ?? false;

            if (word != null && correctAnswer != null) {
              // Check if word already exists
              final existing = await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_words')
                  .where('input', isEqualTo: word)
                  .limit(1)
                  .get();

              if (existing.docs.isEmpty) {
                // Add new word with initial quality based on quiz result
                final quality = isCorrect ? 4 : 2;
                await saveWordForReview(
                  word: word,
                  translation: correctAnswer,
                  quality: quality,
                );
                importedCount++;
              }
            }
          }
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('Error importing words from quiz results: $e');
      return 0;
    }
  }

  /// Add a word directly to the review system
  Future<void> addWordToReview({
    required String bisayaWord,
    required String englishWord,
    String? tagalogWord,
  }) async {
    await saveWordForReview(
      word: bisayaWord,
      translation: englishWord,
      fromLanguage: 'Bisaya',
      toLanguage: 'English',
      quality: 3,
    );
  }

  /// Get words that are struggling (low easiness factor)
  Future<List<Map<String, dynamic>>> getStrugglingWords({int limit = 20}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('easinessFactor', isLessThan: 2.0)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'word': data['input'] ?? '',
          'translation': data['output'] ?? '',
          'easinessFactor': (data['easinessFactor'] as num?)?.toDouble() ?? 2.5,
          'repetitions': (data['repetitions'] as num?)?.toInt() ?? 0,
          'totalReviews': (data['totalReviews'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting struggling words: $e');
      return [];
    }
  }

  /// Reset a word's spaced repetition data (for re-learning)
  Future<void> resetWord(String word) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('input', isEqualTo: word)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'easinessFactor': 2.5,
          'repetitions': 0,
          'interval': 0,
          'nextReviewDate': Timestamp.fromDate(DateTime.now()),
          'lastReviewed': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error resetting word: $e');
    }
  }
}
