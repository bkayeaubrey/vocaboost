import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing achievement badges
/// Tracks milestones and unlocks badges
class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Badge definitions
  static final List<Map<String, dynamic>> _badgeDefinitions = [
    // Learning milestones
    {
      'id': 'first_word',
      'name': 'First Step',
      'description': 'Learn your first Bisaya word',
      'icon': 'star',
      'color': 0xFFFFD700,
      'category': 'learning',
      'requirement': {'type': 'words_learned', 'count': 1},
    },
    {
      'id': 'word_collector_10',
      'name': 'Word Collector',
      'description': 'Learn 10 Bisaya words',
      'icon': 'collections_bookmark',
      'color': 0xFF4CAF50,
      'category': 'learning',
      'requirement': {'type': 'words_learned', 'count': 10},
    },
    {
      'id': 'word_master_50',
      'name': 'Word Master',
      'description': 'Learn 50 Bisaya words',
      'icon': 'workspace_premium',
      'color': 0xFF2196F3,
      'category': 'learning',
      'requirement': {'type': 'words_learned', 'count': 50},
    },
    {
      'id': 'vocabulary_expert',
      'name': 'Vocabulary Expert',
      'description': 'Learn 100 Bisaya words',
      'icon': 'emoji_events',
      'color': 0xFF9C27B0,
      'category': 'learning',
      'requirement': {'type': 'words_learned', 'count': 100},
    },
    {
      'id': 'language_scholar',
      'name': 'Language Scholar',
      'description': 'Learn 250 Bisaya words',
      'icon': 'school',
      'color': 0xFFE91E63,
      'category': 'learning',
      'requirement': {'type': 'words_learned', 'count': 250},
    },

    // Quiz achievements
    {
      'id': 'first_quiz',
      'name': 'Quiz Taker',
      'description': 'Complete your first quiz',
      'icon': 'quiz',
      'color': 0xFFFF9800,
      'category': 'quiz',
      'requirement': {'type': 'quizzes_completed', 'count': 1},
    },
    {
      'id': 'quiz_enthusiast',
      'name': 'Quiz Enthusiast',
      'description': 'Complete 10 quizzes',
      'icon': 'assignment_turned_in',
      'color': 0xFF00BCD4,
      'category': 'quiz',
      'requirement': {'type': 'quizzes_completed', 'count': 10},
    },
    {
      'id': 'perfect_score',
      'name': 'Perfectionist',
      'description': 'Get 100% on a quiz',
      'icon': 'verified',
      'color': 0xFFFFD700,
      'category': 'quiz',
      'requirement': {'type': 'perfect_quiz', 'count': 1},
    },
    {
      'id': 'quiz_champion',
      'name': 'Quiz Champion',
      'description': 'Get 5 perfect quiz scores',
      'icon': 'military_tech',
      'color': 0xFFF44336,
      'category': 'quiz',
      'requirement': {'type': 'perfect_quiz', 'count': 5},
    },

    // Streak achievements
    {
      'id': 'streak_3',
      'name': 'Getting Started',
      'description': 'Maintain a 3-day learning streak',
      'icon': 'local_fire_department',
      'color': 0xFFFF5722,
      'category': 'streak',
      'requirement': {'type': 'streak', 'count': 3},
    },
    {
      'id': 'streak_7',
      'name': 'Week Warrior',
      'description': 'Maintain a 7-day learning streak',
      'icon': 'whatshot',
      'color': 0xFFFF5722,
      'category': 'streak',
      'requirement': {'type': 'streak', 'count': 7},
    },
    {
      'id': 'streak_14',
      'name': 'Fortnight Fighter',
      'description': 'Maintain a 14-day learning streak',
      'icon': 'bolt',
      'color': 0xFFFF9800,
      'category': 'streak',
      'requirement': {'type': 'streak', 'count': 14},
    },
    {
      'id': 'streak_30',
      'name': 'Monthly Master',
      'description': 'Maintain a 30-day learning streak',
      'icon': 'flash_on',
      'color': 0xFFFFD700,
      'category': 'streak',
      'requirement': {'type': 'streak', 'count': 30},
    },
    {
      'id': 'streak_100',
      'name': 'Century Champion',
      'description': 'Maintain a 100-day learning streak',
      'icon': 'auto_awesome',
      'color': 0xFF9C27B0,
      'category': 'streak',
      'requirement': {'type': 'streak', 'count': 100},
    },

    // XP achievements
    {
      'id': 'xp_100',
      'name': 'Point Starter',
      'description': 'Earn 100 XP',
      'icon': 'stars',
      'color': 0xFF8BC34A,
      'category': 'xp',
      'requirement': {'type': 'total_xp', 'count': 100},
    },
    {
      'id': 'xp_500',
      'name': 'Point Collector',
      'description': 'Earn 500 XP',
      'icon': 'grade',
      'color': 0xFF03A9F4,
      'category': 'xp',
      'requirement': {'type': 'total_xp', 'count': 500},
    },
    {
      'id': 'xp_1000',
      'name': 'Point Master',
      'description': 'Earn 1,000 XP',
      'icon': 'diamond',
      'color': 0xFF673AB7,
      'category': 'xp',
      'requirement': {'type': 'total_xp', 'count': 1000},
    },
    {
      'id': 'xp_5000',
      'name': 'XP Legend',
      'description': 'Earn 5,000 XP',
      'icon': 'rocket_launch',
      'color': 0xFFE91E63,
      'category': 'xp',
      'requirement': {'type': 'total_xp', 'count': 5000},
    },

    // Special achievements
    {
      'id': 'night_owl',
      'name': 'Night Owl',
      'description': 'Study after 10 PM',
      'icon': 'nightlight',
      'color': 0xFF3F51B5,
      'category': 'special',
      'requirement': {'type': 'study_time', 'hour': 22},
    },
    {
      'id': 'early_bird',
      'name': 'Early Bird',
      'description': 'Study before 7 AM',
      'icon': 'wb_sunny',
      'color': 0xFFFFC107,
      'category': 'special',
      'requirement': {'type': 'study_time', 'hour': 7},
    },
    {
      'id': 'category_explorer',
      'name': 'Category Explorer',
      'description': 'Learn words from 5 different categories',
      'icon': 'explore',
      'color': 0xFF009688,
      'category': 'special',
      'requirement': {'type': 'categories', 'count': 5},
    },
    {
      'id': 'voice_master',
      'name': 'Voice Master',
      'description': 'Complete 20 voice pronunciation exercises',
      'icon': 'record_voice_over',
      'color': 0xFF795548,
      'category': 'special',
      'requirement': {'type': 'voice_exercises', 'count': 20},
    },
    {
      'id': 'hangman_winner',
      'name': 'Hangman Hero',
      'description': 'Win 10 Hangman games',
      'icon': 'extension',
      'color': 0xFF607D8B,
      'category': 'games',
      'requirement': {'type': 'hangman_wins', 'count': 10},
    },
    {
      'id': 'conversation_starter',
      'name': 'Conversation Starter',
      'description': 'Complete 5 conversation exercises',
      'icon': 'chat',
      'color': 0xFF00BCD4,
      'category': 'special',
      'requirement': {'type': 'conversations', 'count': 5},
    },
  ];

  /// Get all badge definitions
  List<Map<String, dynamic>> getAllBadges() {
    return _badgeDefinitions;
  }

  /// Get user's unlocked badges
  Future<List<Map<String, dynamic>>> getUnlockedBadges() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('badges')
          .get();

      if (!doc.exists) return [];

      final data = doc.data()!;
      final unlockedIds = List<String>.from(data['unlocked'] ?? []);

      return _badgeDefinitions
          .where((badge) => unlockedIds.contains(badge['id']))
          .map((badge) {
            final unlockedAt = data['unlockedAt']?[badge['id']];
            return {
              ...badge,
              'unlockedAt': unlockedAt,
            };
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting unlocked badges: $e');
      return [];
    }
  }

  /// Get badges with unlock status
  Future<List<Map<String, dynamic>>> getBadgesWithStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _badgeDefinitions.map((b) => {...b, 'unlocked': false}).toList();
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('badges')
          .get();

      final unlockedIds = doc.exists 
          ? List<String>.from(doc.data()?['unlocked'] ?? [])
          : <String>[];
      final unlockedAt = doc.exists
          ? Map<String, dynamic>.from(doc.data()?['unlockedAt'] ?? {})
          : <String, dynamic>{};

      return _badgeDefinitions.map((badge) {
        final isUnlocked = unlockedIds.contains(badge['id']);
        return {
          ...badge,
          'unlocked': isUnlocked,
          'unlockedAt': isUnlocked ? unlockedAt[badge['id']] : null,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting badges with status: $e');
      return _badgeDefinitions.map((b) => {...b, 'unlocked': false}).toList();
    }
  }

  /// Unlock a badge
  Future<bool> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('badges');

      await docRef.set({
        'unlocked': FieldValue.arrayUnion([badgeId]),
        'unlockedAt': {
          badgeId: DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error unlocking badge: $e');
      return false;
    }
  }

  /// Check and unlock eligible badges based on current stats
  Future<List<Map<String, dynamic>>> checkAndUnlockBadges({
    int? wordsLearned,
    int? quizzesCompleted,
    int? perfectQuizzes,
    int? currentStreak,
    int? totalXP,
    int? voiceExercises,
    int? hangmanWins,
    int? conversations,
    int? categoriesExplored,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('badges')
          .get();

      final unlockedIds = doc.exists 
          ? List<String>.from(doc.data()?['unlocked'] ?? [])
          : <String>[];

      List<Map<String, dynamic>> newlyUnlocked = [];
      final now = DateTime.now();

      for (final badge in _badgeDefinitions) {
        if (unlockedIds.contains(badge['id'])) continue;

        final req = badge['requirement'] as Map<String, dynamic>;
        bool shouldUnlock = false;

        switch (req['type']) {
          case 'words_learned':
            if (wordsLearned != null && wordsLearned >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'quizzes_completed':
            if (quizzesCompleted != null && quizzesCompleted >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'perfect_quiz':
            if (perfectQuizzes != null && perfectQuizzes >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'streak':
            if (currentStreak != null && currentStreak >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'total_xp':
            if (totalXP != null && totalXP >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'voice_exercises':
            if (voiceExercises != null && voiceExercises >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'hangman_wins':
            if (hangmanWins != null && hangmanWins >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'conversations':
            if (conversations != null && conversations >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'categories':
            if (categoriesExplored != null && categoriesExplored >= (req['count'] as int)) {
              shouldUnlock = true;
            }
            break;
          case 'study_time':
            final hour = req['hour'] as int;
            if (hour >= 22 && now.hour >= 22) {
              shouldUnlock = true; // Night owl
            } else if (hour <= 7 && now.hour < 7) {
              shouldUnlock = true; // Early bird
            }
            break;
        }

        if (shouldUnlock) {
          await unlockBadge(badge['id'] as String);
          newlyUnlocked.add(badge);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      debugPrint('Error checking badges: $e');
      return [];
    }
  }

  /// Get badge count stats
  Future<Map<String, int>> getBadgeStats() async {
    final unlocked = await getUnlockedBadges();
    return {
      'unlocked': unlocked.length,
      'total': _badgeDefinitions.length,
    };
  }
}
