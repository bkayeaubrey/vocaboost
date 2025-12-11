import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save quiz result to Firestore
  Future<void> saveQuizResult({
    required int score,
    required int totalQuestions,
    required List<Map<String, dynamic>> questions,
    required List<int?> selectedAnswers,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .add({
        'score': score,
        'totalQuestions': totalQuestions,
        'percentage': (score / totalQuestions * 100).round(),
        'questions': questions,
        'selectedAnswers': selectedAnswers,
        'timestamp': FieldValue.serverTimestamp(),
        'date': now.toIso8601String(),
        'dateString': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'timeString': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      });
    } catch (e) {
      throw Exception('Failed to save quiz result: $e');
    }
  }

  /// Get all quiz results for the current user
  Stream<QuerySnapshot> getQuizResults() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('quiz_results')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get quiz statistics
  Future<Map<String, dynamic>> getQuizStatistics() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'totalQuestions': 0,
        'correctAnswers': 0,
      };
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalQuizzes': 0,
          'averageScore': 0.0,
          'totalQuestions': 0,
          'correctAnswers': 0,
        };
      }

      int totalQuizzes = snapshot.docs.length;
      int totalScore = 0;
      int totalQuestions = 0;
      int correctAnswers = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalScore += (data['score'] as num?)?.toInt() ?? 0;
        totalQuestions += (data['totalQuestions'] as num?)?.toInt() ?? 0;
        correctAnswers += (data['score'] as num?)?.toInt() ?? 0;
      }

      return {
        'totalQuizzes': totalQuizzes,
        'averageScore': totalQuizzes > 0 ? (totalScore / totalQuizzes) : 0.0,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
      };
    } catch (e) {
      throw Exception('Failed to get quiz statistics: $e');
    }
  }

  /// Get total number of quizzes completed
  Future<int> getTotalQuizzesCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of perfect quizzes (100% score)
  Future<int> getPerfectQuizCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .where('percentage', isEqualTo: 100)
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of voice exercises completed
  Future<int> getVoiceExercisesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      // Count all quiz results (voice exercises are tracked as quiz results)
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

