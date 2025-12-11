import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vocaboost/services/spaced_repetition_service.dart';

class TranslationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpacedRepetitionService _spacedRepetitionService = SpacedRepetitionService();

  /// Save a translation to Firestore with spaced repetition
  Future<void> saveTranslation({
    required String input,
    required String output,
    required String fromLanguage,
    required String toLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use spaced repetition service to save with review scheduling
      await _spacedRepetitionService.saveWordForReview(
        word: input,
        translation: output,
        fromLanguage: fromLanguage,
        toLanguage: toLanguage,
        quality: 3, // Default quality for new words
      );
    } catch (e) {
      throw Exception('Failed to save translation: $e');
    }
  }

  /// Get all saved translations for the current user
  Stream<QuerySnapshot> getSavedTranslations() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_words')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Delete a saved translation
  Future<void> deleteTranslation(String documentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .doc(documentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete translation: $e');
    }
  }
}


