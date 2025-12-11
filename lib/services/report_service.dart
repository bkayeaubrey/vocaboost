import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Conditional import for web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Service to generate and download progress reports
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate and download a comprehensive progress report as CSV
  Future<bool> downloadProgressReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final reportData = await _gatherAllProgressData(user.uid);
      final csvContent = _generateProgressCSV(reportData);
      
      _downloadFile(csvContent, 'vocaboost_progress_report_${_getDateString()}.csv');
      return true;
    } catch (e) {
      debugPrint('Error generating progress report: $e');
      return false;
    }
  }

  /// Generate and download a weekly progress report as CSV
  Future<bool> downloadWeeklyReport() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final reportData = await _gatherWeeklyData(user.uid);
      final csvContent = _generateWeeklyCSV(reportData);
      
      _downloadFile(csvContent, 'vocaboost_weekly_report_${_getDateString()}.csv');
      return true;
    } catch (e) {
      debugPrint('Error generating weekly report: $e');
      return false;
    }
  }

  /// Generate and download quiz history as CSV
  Future<bool> downloadQuizHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final quizData = await _gatherQuizHistory(user.uid);
      final csvContent = _generateQuizHistoryCSV(quizData);
      
      _downloadFile(csvContent, 'vocaboost_quiz_history_${_getDateString()}.csv');
      return true;
    } catch (e) {
      debugPrint('Error generating quiz history: $e');
      return false;
    }
  }

  /// Gather all progress data for comprehensive report
  Future<Map<String, dynamic>> _gatherAllProgressData(String uid) async {
    final data = <String, dynamic>{};

    // User info
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      data['userName'] = userDoc.data()?['displayName'] ?? 'User';
      data['email'] = userDoc.data()?['email'] ?? '';
    }

    // XP data
    final xpDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('xp_data')
        .doc('current')
        .get();
    if (xpDoc.exists) {
      data['totalXP'] = xpDoc.data()?['totalXP'] ?? 0;
      data['currentLevel'] = xpDoc.data()?['level'] ?? 1;
      data['weeklyXP'] = xpDoc.data()?['weeklyXP'] ?? 0;
    }

    // Quiz results summary
    final quizResults = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .get();
    
    int totalQuizzes = quizResults.docs.length;
    int totalCorrect = 0;
    int totalQuestions = 0;
    
    for (var doc in quizResults.docs) {
      final docData = doc.data();
      totalCorrect += (docData['correctAnswers'] as num?)?.toInt() ?? 0;
      totalQuestions += (docData['totalQuestions'] as num?)?.toInt() ?? 0;
    }
    
    data['totalQuizzes'] = totalQuizzes;
    data['totalCorrectAnswers'] = totalCorrect;
    data['totalQuestions'] = totalQuestions;
    data['overallAccuracy'] = totalQuestions > 0 
        ? ((totalCorrect / totalQuestions) * 100).toStringAsFixed(1)
        : '0.0';

    // Streak data
    final streakDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('learning_data')
        .doc('streak')
        .get();
    if (streakDoc.exists) {
      data['currentStreak'] = streakDoc.data()?['currentStreak'] ?? 0;
      data['longestStreak'] = streakDoc.data()?['longestStreak'] ?? 0;
    }

    // Words mastered (from spaced repetition)
    final reviewWords = await _firestore
        .collection('users')
        .doc(uid)
        .collection('review_words')
        .get();
    
    int masteredWords = 0;
    int learningWords = 0;
    for (var doc in reviewWords.docs) {
      final docData = doc.data();
      final level = (docData['level'] as num?)?.toInt() ?? 0;
      if (level >= 5) {
        masteredWords++;
      } else {
        learningWords++;
      }
    }
    data['masteredWords'] = masteredWords;
    data['learningWords'] = learningWords;
    data['totalWordsStudied'] = masteredWords + learningWords;

    // Achievements
    final achievementsDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc('badges')
        .get();
    if (achievementsDoc.exists) {
      final badges = achievementsDoc.data()?['unlockedBadges'] as List<dynamic>? ?? [];
      data['totalBadges'] = badges.length;
      data['badges'] = badges.join(', ');
    }

    data['reportGeneratedAt'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    return data;
  }

  /// Gather weekly data for weekly report
  Future<Map<String, dynamic>> _gatherWeeklyData(String uid) async {
    final data = <String, dynamic>{};
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    data['weekStartDate'] = DateFormat('yyyy-MM-dd').format(weekStartDate);
    data['weekEndDate'] = DateFormat('yyyy-MM-dd').format(now);

    // Weekly XP
    final xpDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('xp_data')
        .doc('current')
        .get();
    data['weeklyXP'] = xpDoc.data()?['weeklyXP'] ?? 0;

    // Weekly quizzes
    final quizResults = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
        .get();

    int weeklyQuizzes = quizResults.docs.length;
    int weeklyCorrect = 0;
    int weeklyTotal = 0;
    Map<String, int> dailyActivity = {};

    for (var doc in quizResults.docs) {
      final docData = doc.data();
      weeklyCorrect += (docData['correctAnswers'] as num?)?.toInt() ?? 0;
      weeklyTotal += (docData['totalQuestions'] as num?)?.toInt() ?? 0;
      
      final timestamp = docData['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final day = DateFormat('EEEE').format(timestamp.toDate());
        dailyActivity[day] = (dailyActivity[day] ?? 0) + 1;
      }
    }

    data['weeklyQuizzes'] = weeklyQuizzes;
    data['weeklyCorrectAnswers'] = weeklyCorrect;
    data['weeklyTotalQuestions'] = weeklyTotal;
    data['weeklyAccuracy'] = weeklyTotal > 0 
        ? ((weeklyCorrect / weeklyTotal) * 100).toStringAsFixed(1)
        : '0.0';
    data['dailyActivity'] = dailyActivity;

    // XP History breakdown
    final xpHistory = await _firestore
        .collection('users')
        .doc(uid)
        .collection('xp_history')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
        .get();

    Map<String, int> xpByActivity = {};
    for (var doc in xpHistory.docs) {
      final docData = doc.data();
      final type = docData['activityType'] as String? ?? 'other';
      final amount = (docData['amount'] as num?)?.toInt() ?? 0;
      xpByActivity[type] = (xpByActivity[type] ?? 0) + amount;
    }
    data['xpByActivity'] = xpByActivity;

    data['reportGeneratedAt'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    return data;
  }

  /// Gather quiz history
  Future<List<Map<String, dynamic>>> _gatherQuizHistory(String uid) async {
    final quizResults = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    return quizResults.docs.map((doc) {
      final data = doc.data();
      return {
        'date': data['timestamp'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format((data['timestamp'] as Timestamp).toDate())
            : 'Unknown',
        'quizType': data['quizType'] ?? 'General',
        'correctAnswers': data['correctAnswers'] ?? 0,
        'totalQuestions': data['totalQuestions'] ?? 0,
        'accuracy': data['totalQuestions'] != null && data['totalQuestions'] > 0
            ? ((data['correctAnswers'] ?? 0) / data['totalQuestions'] * 100).toStringAsFixed(1)
            : '0.0',
        'xpEarned': data['xpEarned'] ?? 0,
      };
    }).toList();
  }

  /// Generate CSV content for progress report
  String _generateProgressCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    
    buffer.writeln('VocaBoost Progress Report');
    buffer.writeln('Generated: ${data['reportGeneratedAt']}');
    buffer.writeln('');
    
    buffer.writeln('=== User Information ===');
    buffer.writeln('Name,${_escapeCSV(data['userName'] ?? 'N/A')}');
    buffer.writeln('Email,${_escapeCSV(data['email'] ?? 'N/A')}');
    buffer.writeln('');
    
    buffer.writeln('=== XP & Level ===');
    buffer.writeln('Total XP,${data['totalXP'] ?? 0}');
    buffer.writeln('Current Level,${data['currentLevel'] ?? 1}');
    buffer.writeln('Weekly XP,${data['weeklyXP'] ?? 0}');
    buffer.writeln('');
    
    buffer.writeln('=== Quiz Performance ===');
    buffer.writeln('Total Quizzes Completed,${data['totalQuizzes'] ?? 0}');
    buffer.writeln('Total Correct Answers,${data['totalCorrectAnswers'] ?? 0}');
    buffer.writeln('Total Questions Attempted,${data['totalQuestions'] ?? 0}');
    buffer.writeln('Overall Accuracy,${data['overallAccuracy'] ?? 0}%');
    buffer.writeln('');
    
    buffer.writeln('=== Learning Streak ===');
    buffer.writeln('Current Streak (days),${data['currentStreak'] ?? 0}');
    buffer.writeln('Longest Streak (days),${data['longestStreak'] ?? 0}');
    buffer.writeln('');
    
    buffer.writeln('=== Vocabulary Progress ===');
    buffer.writeln('Words Mastered,${data['masteredWords'] ?? 0}');
    buffer.writeln('Words Learning,${data['learningWords'] ?? 0}');
    buffer.writeln('Total Words Studied,${data['totalWordsStudied'] ?? 0}');
    buffer.writeln('');
    
    buffer.writeln('=== Achievements ===');
    buffer.writeln('Total Badges Earned,${data['totalBadges'] ?? 0}');
    buffer.writeln('Badges,${_escapeCSV(data['badges'] ?? 'None')}');
    
    return buffer.toString();
  }

  /// Generate CSV content for weekly report
  String _generateWeeklyCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    
    buffer.writeln('VocaBoost Weekly Report');
    buffer.writeln('Week: ${data['weekStartDate']} to ${data['weekEndDate']}');
    buffer.writeln('Generated: ${data['reportGeneratedAt']}');
    buffer.writeln('');
    
    buffer.writeln('=== Weekly Summary ===');
    buffer.writeln('Total XP Earned,${data['weeklyXP'] ?? 0}');
    buffer.writeln('Quizzes Completed,${data['weeklyQuizzes'] ?? 0}');
    buffer.writeln('Correct Answers,${data['weeklyCorrectAnswers'] ?? 0}');
    buffer.writeln('Total Questions,${data['weeklyTotalQuestions'] ?? 0}');
    buffer.writeln('Average Accuracy,${data['weeklyAccuracy'] ?? 0}%');
    buffer.writeln('');
    
    buffer.writeln('=== Daily Activity ===');
    buffer.writeln('Day,Quizzes Completed');
    final dailyActivity = data['dailyActivity'] as Map<String, int>? ?? {};
    for (var day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
      buffer.writeln('$day,${dailyActivity[day] ?? 0}');
    }
    buffer.writeln('');
    
    buffer.writeln('=== XP by Activity Type ===');
    buffer.writeln('Activity,XP Earned');
    final xpByActivity = data['xpByActivity'] as Map<String, int>? ?? {};
    xpByActivity.forEach((activity, xp) {
      buffer.writeln('${_formatActivityName(activity)},$xp');
    });
    
    return buffer.toString();
  }

  /// Generate CSV content for quiz history
  String _generateQuizHistoryCSV(List<Map<String, dynamic>> quizData) {
    final buffer = StringBuffer();
    
    buffer.writeln('VocaBoost Quiz History');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('');
    
    buffer.writeln('Date,Quiz Type,Correct,Total,Accuracy (%),XP Earned');
    for (var quiz in quizData) {
      buffer.writeln(
        '${quiz['date']},${_escapeCSV(quiz['quizType'])},${quiz['correctAnswers']},${quiz['totalQuestions']},${quiz['accuracy']},${quiz['xpEarned']}'
      );
    }
    
    return buffer.toString();
  }

  /// Download file using dart:html (web only)
  void _downloadFile(String content, String filename) {
    if (kIsWeb) {
      final bytes = content.codeUnits;
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  /// Helper to escape CSV values
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get current date string for filename
  String _getDateString() {
    return DateFormat('yyyyMMdd').format(DateTime.now());
  }

  /// Format activity name for display
  String _formatActivityName(String activity) {
    return activity
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
