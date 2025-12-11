import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

/// Service for managing daily challenges
/// Generates random daily tasks with XP rewards
class DailyChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Challenge definitions
  static final List<Map<String, dynamic>> _challengeTemplates = [
    {
      'id': 'learn_words',
      'title': 'Word Explorer',
      'description': 'Learn {count} new Bisaya words',
      'icon': 'school',
      'baseXP': 50,
      'countOptions': [3, 5, 7, 10],
      'type': 'learn',
    },
    {
      'id': 'quiz_score',
      'title': 'Quiz Master',
      'description': 'Score at least {score}% on a quiz',
      'icon': 'quiz',
      'baseXP': 75,
      'scoreOptions': [70, 80, 90, 100],
      'type': 'quiz',
    },
    {
      'id': 'flashcard_review',
      'title': 'Flashcard Fan',
      'description': 'Review {count} flashcards',
      'icon': 'style',
      'baseXP': 40,
      'countOptions': [10, 15, 20, 25],
      'type': 'flashcard',
    },
    {
      'id': 'practice_session',
      'title': 'Practice Pro',
      'description': 'Complete {count} practice exercises',
      'icon': 'fitness_center',
      'baseXP': 60,
      'countOptions': [5, 8, 10, 15],
      'type': 'practice',
    },
    {
      'id': 'perfect_streak',
      'title': 'Perfect Streak',
      'description': 'Get {count} correct answers in a row',
      'icon': 'local_fire_department',
      'baseXP': 100,
      'countOptions': [3, 5, 7, 10],
      'type': 'streak',
    },
    {
      'id': 'voice_practice',
      'title': 'Voice Champion',
      'description': 'Complete {count} voice pronunciation exercises',
      'icon': 'mic',
      'baseXP': 80,
      'countOptions': [3, 5, 7],
      'type': 'voice',
    },
    {
      'id': 'time_challenge',
      'title': 'Speed Learner',
      'description': 'Study for {minutes} minutes today',
      'icon': 'timer',
      'baseXP': 45,
      'minuteOptions': [5, 10, 15, 20],
      'type': 'time',
    },
    {
      'id': 'category_master',
      'title': 'Category Explorer',
      'description': 'Learn words from {count} different categories',
      'icon': 'category',
      'baseXP': 70,
      'countOptions': [2, 3, 4],
      'type': 'category',
    },
  ];

  /// Get today's challenges (generates 3 random challenges per day)
  Future<List<Map<String, dynamic>>> getTodaysChallenges() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if today's challenges exist
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_challenges')
          .doc(todayStr);

      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        final challenges = List<Map<String, dynamic>>.from(data['challenges'] ?? []);
        return challenges;
      }

      // Generate new challenges for today
      final challenges = _generateDailyChallenges();
      
      await docRef.set({
        'date': todayStr,
        'challenges': challenges,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return challenges;
    } catch (e) {
      debugPrint('Error getting daily challenges: $e');
      return _generateDailyChallenges();
    }
  }

  /// Generate random daily challenges
  List<Map<String, dynamic>> _generateDailyChallenges() {
    final today = DateTime.now();
    
    // Use date as seed for consistent daily challenges
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final seededRandom = Random(seed);

    // Shuffle templates with seeded random
    final shuffled = List<Map<String, dynamic>>.from(_challengeTemplates);
    shuffled.shuffle(seededRandom);

    // Pick 3 challenges
    final selected = shuffled.take(3).toList();

    return selected.map((template) {
      final challenge = Map<String, dynamic>.from(template);
      
      // Fill in random values
      if (challenge.containsKey('countOptions')) {
        final options = List<int>.from(challenge['countOptions']);
        challenge['targetCount'] = options[seededRandom.nextInt(options.length)];
        challenge['description'] = (challenge['description'] as String)
            .replaceAll('{count}', challenge['targetCount'].toString());
        challenge.remove('countOptions');
      }
      
      if (challenge.containsKey('scoreOptions')) {
        final options = List<int>.from(challenge['scoreOptions']);
        challenge['targetScore'] = options[seededRandom.nextInt(options.length)];
        challenge['description'] = (challenge['description'] as String)
            .replaceAll('{score}', challenge['targetScore'].toString());
        challenge.remove('scoreOptions');
      }
      
      if (challenge.containsKey('minuteOptions')) {
        final options = List<int>.from(challenge['minuteOptions']);
        challenge['targetMinutes'] = options[seededRandom.nextInt(options.length)];
        challenge['description'] = (challenge['description'] as String)
            .replaceAll('{minutes}', challenge['targetMinutes'].toString());
        challenge.remove('minuteOptions');
      }

      challenge['currentProgress'] = 0;
      challenge['completed'] = false;
      challenge['xpReward'] = challenge['baseXP'];
      challenge.remove('baseXP');

      return challenge;
    }).toList();
  }

  /// Update challenge progress
  Future<Map<String, dynamic>?> updateChallengeProgress({
    required String challengeType,
    int increment = 1,
    int? score,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_challenges')
          .doc(todayStr);

      final doc = await docRef.get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final challenges = List<Map<String, dynamic>>.from(data['challenges'] ?? []);

      Map<String, dynamic>? completedChallenge;

      for (int i = 0; i < challenges.length; i++) {
        final challenge = challenges[i];
        if (challenge['type'] == challengeType && !(challenge['completed'] ?? false)) {
          int newProgress = (challenge['currentProgress'] ?? 0) + increment;
          
          // For score-based challenges, use the score directly
          if (challengeType == 'quiz' && score != null) {
            if (score >= (challenge['targetScore'] ?? 0)) {
              newProgress = challenge['targetScore'];
            }
          }

          challenges[i]['currentProgress'] = newProgress;

          // Check if completed
          int target = challenge['targetCount'] ?? 
                       challenge['targetScore'] ?? 
                       challenge['targetMinutes'] ?? 
                       1;
          
          if (newProgress >= target && !(challenge['completed'] ?? false)) {
            challenges[i]['completed'] = true;
            challenges[i]['completedAt'] = DateTime.now().toIso8601String();
            completedChallenge = challenges[i];
          }
        }
      }

      await docRef.update({'challenges': challenges});

      return completedChallenge;
    } catch (e) {
      debugPrint('Error updating challenge progress: $e');
      return null;
    }
  }

  /// Get challenge completion stats
  Future<Map<String, dynamic>> getChallengeStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'totalCompleted': 0, 'currentStreak': 0, 'totalXPEarned': 0};
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_challenges')
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      int totalCompleted = 0;
      int totalXPEarned = 0;
      int currentStreak = 0;
      DateTime? lastDate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final challenges = List<Map<String, dynamic>>.from(data['challenges'] ?? []);
        
        int dailyCompleted = 0;
        for (final challenge in challenges) {
          if (challenge['completed'] == true) {
            totalCompleted++;
            totalXPEarned += (challenge['xpReward'] as num?)?.toInt() ?? 0;
            dailyCompleted++;
          }
        }

        // Calculate streak (must complete at least 1 challenge per day)
        if (dailyCompleted > 0) {
          final dateStr = data['date'] as String;
          final parts = dateStr.split('-');
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          if (lastDate == null) {
            currentStreak = 1;
            lastDate = date;
          } else {
            final diff = lastDate.difference(date).inDays;
            if (diff == 1) {
              currentStreak++;
              lastDate = date;
            } else {
              break;
            }
          }
        }
      }

      return {
        'totalCompleted': totalCompleted,
        'currentStreak': currentStreak,
        'totalXPEarned': totalXPEarned,
      };
    } catch (e) {
      debugPrint('Error getting challenge stats: $e');
      return {'totalCompleted': 0, 'currentStreak': 0, 'totalXPEarned': 0};
    }
  }

  /// Claim reward for a completed challenge
  Future<bool> claimChallengeReward(String challengeId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_challenges')
          .doc(todayStr);

      final doc = await docRef.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final challenges = List<Map<String, dynamic>>.from(data['challenges'] ?? []);

      bool found = false;
      for (int i = 0; i < challenges.length; i++) {
        if (challenges[i]['id'] == challengeId && 
            challenges[i]['completed'] == true && 
            challenges[i]['claimed'] != true) {
          challenges[i]['claimed'] = true;
          challenges[i]['claimedAt'] = DateTime.now().toIso8601String();
          found = true;
          break;
        }
      }

      if (found) {
        await docRef.update({'challenges': challenges});
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error claiming challenge reward: $e');
      return false;
    }
  }

  /// Get count of unclaimed completed challenges
  Future<int> getUnclaimedCount() async {
    final challenges = await getTodaysChallenges();
    return challenges.where((c) => 
      c['completed'] == true && c['claimed'] != true
    ).length;
  }
}
