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
        'date': DateTime.now().toIso8601String(),
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
}

