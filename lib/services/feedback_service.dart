import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit feedback to Firestore
  /// 
  /// The feedback will be stored in the 'feedback' collection and
  /// a Cloud Function will be triggered to send email notifications.
  Future<void> submitFeedback({
    required String message,
    String? category,
    int? rating,
  }) async {
    final user = _auth.currentUser;
    
    try {
      // Get user data for context
      Map<String, dynamic>? userData;
      String? userName;
      String? userEmail = user?.email;
      
      if (user != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          userData = userDoc.data();
          userName = userData?['fullname'] ?? userData?['username'] ?? userEmail?.split('@').first;
        } catch (e) {
          // If we can't get user data, continue with just email
          userName = userEmail?.split('@').first;
        }
      }

      // Submit feedback to Firestore
      await _firestore.collection('feedback').add({
        'message': message,
        'category': category ?? 'general',
        'rating': rating,
        'userId': user?.uid,
        'userEmail': userEmail,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new', // new, read, resolved
        'appVersion': '1.0.0',
      });
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  /// Get feedback history for the current user (optional feature)
  Stream<QuerySnapshot> getUserFeedback() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore
        .collection('feedback')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}



