import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/achievement_service.dart';

/// Service for managing XP (Experience Points) and leveling system
/// Implements Duolingo-style XP tracking and level calculation
class XPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AchievementService _achievementService = AchievementService();

  // XP required per level (exponential growth)
  static const int _baseXPPerLevel = 100;
  static const double _xpMultiplier = 1.5;

  /// Calculate level from total XP
  int calculateLevel(int totalXP) {
    if (totalXP < _baseXPPerLevel) return 1;
    
    int level = 1;
    int xpRequired = 0;
    
    while (xpRequired <= totalXP) {
      level++;
      xpRequired += (_baseXPPerLevel * pow(_xpMultiplier, level - 2)).round();
    }
    
    return level - 1;
  }

  /// Calculate XP required for next level
  int getXPToNextLevel(int currentLevel, int totalXP) {
    if (currentLevel == 1) {
      return _baseXPPerLevel - totalXP;
    }
    
    int xpForNextLevel = (_baseXPPerLevel * pow(_xpMultiplier, currentLevel - 1)).round();
    int xpAtCurrentLevelStart = _getTotalXPForLevel(currentLevel - 1);
    
    int xpProgressInLevel = totalXP - xpAtCurrentLevelStart;
    int xpNeeded = xpForNextLevel - xpProgressInLevel;
    
    return xpNeeded > 0 ? xpNeeded : 0;
  }

  /// Get total XP required to reach a specific level
  int _getTotalXPForLevel(int level) {
    if (level <= 1) return 0;
    
    int total = 0;
    for (int i = 2; i <= level; i++) {
      total += (_baseXPPerLevel * pow(_xpMultiplier, i - 2)).round();
    }
    return total;
  }

  /// Earn XP for an activity
  /// 
  /// [amount] - Base XP amount
  /// [activityType] - Type of activity (quiz, flashcard, review, challenge, etc.)
  /// [difficulty] - Optional difficulty multiplier (1.0 = normal, 1.5 = hard, 2.0 = expert)
  /// [streakBonus] - Optional streak bonus multiplier
  Future<Map<String, dynamic>> earnXP({
    required int amount,
    required String activityType,
    double difficulty = 1.0,
    double streakBonus = 1.0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to earn XP');
    }

    try {
      // Calculate final XP with multipliers
      final finalXP = (amount * difficulty * streakBonus).round();
      
      // Get current XP data
      final xpDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_data')
          .doc('current')
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: now.weekday - 1));

      int totalXP = 0;
      int dailyXP = 0;
      int weeklyXP = 0;
      DateTime? lastXPDate;
      DateTime? lastXPWeek;

      if (xpDoc.exists) {
        final data = xpDoc.data()!;
        totalXP = (data['totalXP'] as num?)?.toInt() ?? 0;
        dailyXP = (data['dailyXP'] as num?)?.toInt() ?? 0;
        weeklyXP = (data['weeklyXP'] as num?)?.toInt() ?? 0;
        lastXPDate = (data['lastXPDate'] as Timestamp?)?.toDate();
        lastXPWeek = (data['lastXPWeek'] as Timestamp?)?.toDate();
      }

      // Reset daily XP if new day
      if (lastXPDate == null || lastXPDate.isBefore(today)) {
        dailyXP = 0;
      }

      // Reset weekly XP if new week
      if (lastXPWeek == null || lastXPWeek.isBefore(weekStart)) {
        weeklyXP = 0;
      }

      // Update XP values
      totalXP += finalXP;
      dailyXP += finalXP;
      weeklyXP += finalXP;

      // Calculate new level
      final oldLevel = calculateLevel(totalXP - finalXP);
      final newLevel = calculateLevel(totalXP);
      final leveledUp = newLevel > oldLevel;

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_data')
          .doc('current')
          .set({
        'totalXP': totalXP,
        'currentLevel': newLevel,
        'dailyXP': dailyXP,
        'weeklyXP': weeklyXP,
        'lastXPDate': Timestamp.fromDate(now),
        'lastXPWeek': Timestamp.fromDate(weekStart),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log XP history
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .add({
        'amount': finalXP,
        'baseAmount': amount,
        'difficulty': difficulty,
        'streakBonus': streakBonus,
        'activityType': activityType,
        'totalXP': totalXP,
        'level': newLevel,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Check XP achievements
      await _achievementService.checkAndUnlockBadges(totalXP: totalXP);

      return {
        'xpEarned': finalXP,
        'totalXP': totalXP,
        'dailyXP': dailyXP,
        'weeklyXP': weeklyXP,
        'level': newLevel,
        'leveledUp': leveledUp,
        'xpToNextLevel': getXPToNextLevel(newLevel, totalXP),
      };
    } catch (e) {
      debugPrint('Error earning XP: $e');
      throw Exception('Failed to earn XP: $e');
    }
  }

  /// Get current XP data
  Future<Map<String, dynamic>> getXPData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalXP': 0,
        'currentLevel': 1,
        'dailyXP': 0,
        'weeklyXP': 0,
        'xpToNextLevel': _baseXPPerLevel,
      };
    }

    try {
      final xpDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_data')
          .doc('current')
          .get();

      if (!xpDoc.exists) {
        return {
          'totalXP': 0,
          'currentLevel': 1,
          'dailyXP': 0,
          'weeklyXP': 0,
          'xpToNextLevel': _baseXPPerLevel,
        };
      }

      final data = xpDoc.data()!;
      final totalXP = (data['totalXP'] as num?)?.toInt() ?? 0;
      final level = calculateLevel(totalXP);

      return {
        'totalXP': totalXP,
        'currentLevel': level,
        'dailyXP': (data['dailyXP'] as num?)?.toInt() ?? 0,
        'weeklyXP': (data['weeklyXP'] as num?)?.toInt() ?? 0,
        'xpToNextLevel': getXPToNextLevel(level, totalXP),
      };
    } catch (e) {
      debugPrint('Error getting XP data: $e');
      return {
        'totalXP': 0,
        'currentLevel': 1,
        'dailyXP': 0,
        'weeklyXP': 0,
        'xpToNextLevel': _baseXPPerLevel,
      };
    }
  }

  /// Get total XP
  Future<int> getTotalXP() async {
    final data = await getXPData();
    return data['totalXP'] as int;
  }

  /// Get daily XP
  Future<int> getDailyXP() async {
    final data = await getXPData();
    return data['dailyXP'] as int;
  }

  /// Get current level
  Future<int> getLevel() async {
    final data = await getXPData();
    return data['currentLevel'] as int;
  }

  /// Get XP history for charts/analytics
  Future<List<Map<String, dynamic>>> getXPHistory({
    int limit = 30,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'id': doc.id,
          'amount': (data?['amount'] as num?)?.toInt() ?? 0,
          'activityType': data?['activityType'] as String? ?? '',
          'timestamp': (data?['timestamp'] as Timestamp?)?.toDate(),
          'level': (data?['level'] as num?)?.toInt() ?? 1,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting XP history: $e');
      return [];
    }
  }
}

