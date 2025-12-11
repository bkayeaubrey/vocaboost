import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  /// Upload profile picture to Firebase Storage (web-compatible using bytes)
  Future<String> uploadProfilePictureFromBytes(Uint8List imageBytes, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      // Delete old profile picture if exists
      try {
        final oldRef = _storage.ref('profile_pictures/${user.uid}.jpg');
        await oldRef.delete();
      } catch (e) {
        // Ignore if file doesn't exist
        print('Warning: Could not delete old profile picture: $e');
      }

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.toLowerCase().endsWith('.webp')) {
        contentType = 'image/webp';
      }

      // Upload new profile picture with metadata using putData (web-compatible)
      final ref = _storage.ref('profile_pictures/${user.uid}.jpg');
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final url = await snapshot.ref.getDownloadURL();
      
      // Update user document with profile picture URL
      await _firestore.collection('users').doc(user.uid).update({
        'profilePictureUrl': url,
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
      });

      return url;
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors
      String errorMessage = 'Failed to upload profile picture';
      if (e.code == 'unauthorized') {
        errorMessage = 'Permission denied. Please check Firebase Storage rules.';
      } else if (e.code == 'object-not-found') {
        errorMessage = 'Storage bucket not found. Please check Firebase configuration.';
      } else if (e.code == 'quota-exceeded') {
        errorMessage = 'Storage quota exceeded. Please contact support.';
      } else {
        errorMessage = 'Firebase error: ${e.code} - ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle other errors
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  /// Pick image from gallery or camera and return as XFile (web-compatible)
  Future<XFile?> pickImageAsXFile({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick and upload image in one step (web-compatible)
  Future<String?> pickAndUploadProfilePicture({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await pickImageAsXFile(source: source);
      if (image == null) return null;

      // Read image as bytes (works on web)
      final Uint8List imageBytes = await image.readAsBytes();
      
      // Upload using bytes
      return await uploadProfilePictureFromBytes(imageBytes, image.name);
    } catch (e) {
      throw Exception('Failed to pick and upload image: $e');
    }
  }

  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      // Delete from Storage
      try {
        await _storage.ref('profile_pictures/${user.uid}.jpg').delete();
      } catch (e) {
        // Ignore if file doesn't exist
      }

      // Remove URL from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profilePictureUrl': FieldValue.delete(),
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete profile picture: $e');
    }
  }

  /// Get profile picture URL
  Future<String?> getProfilePictureUrl() async {
    final userData = await getUserData();
    return userData?['profilePictureUrl'] as String?;
  }

  /// Save avatar URL directly (for character/anime avatars)
  Future<void> saveAvatarUrl(String avatarUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'profilePictureUrl': avatarUrl,
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save avatar URL: $e');
    }
  }

  /// Save current level to Firebase
  Future<void> saveCurrentLevel(int level) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'currentLevel': level,
        'levelUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save level: $e');
    }
  }

  /// Get current level from Firebase
  Future<int> getCurrentLevel() async {
    final userData = await getUserData();
    return (userData?['currentLevel'] as int?) ?? 1;
  }

  /// Save level progress (correct/total counts)
  Future<void> saveLevelProgress(int level, int correctCount, int totalCount) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'currentLevel': level,
        'levelCorrectCount': correctCount,
        'levelTotalCount': totalCount,
        'levelUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save level progress: $e');
    }
  }

  /// Get level progress from Firebase
  Future<Map<String, dynamic>> getLevelProgress() async {
    final userData = await getUserData();
    return {
      'level': (userData?['currentLevel'] as int?) ?? 1,
      'correctCount': (userData?['levelCorrectCount'] as int?) ?? 0,
      'totalCount': (userData?['levelTotalCount'] as int?) ?? 0,
      'wordIndex': (userData?['currentWordIndex'] as int?) ?? 0,
      'learnedWords': (userData?['learnedWordIndices'] as List<dynamic>?) ?? [],
    };
  }

  /// Save learned words to Firebase
  Future<void> saveLearnedWords(List<int> learnedIndices, int currentWordIndex) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'learnedWordIndices': learnedIndices,
        'currentWordIndex': currentWordIndex,
        'learnedWordsUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save learned words: $e');
    }
  }

  /// Save current word index to Firebase
  Future<void> saveCurrentWordIndex(int wordIndex) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'currentWordIndex': wordIndex,
      });
    } catch (e) {
      throw Exception('Failed to save word index: $e');
    }
  }

  /// Add word to favorites
  Future<void> addFavoriteWord(String bisayaWord, String englishWord, String tagalogWord) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'favoriteWords': FieldValue.arrayUnion([{
          'bisaya': bisayaWord,
          'english': englishWord,
          'tagalog': tagalogWord,
          'addedAt': DateTime.now().toIso8601String(),
        }]),
      });
    } catch (e) {
      throw Exception('Failed to add favorite word: $e');
    }
  }

  /// Remove word from favorites
  Future<void> removeFavoriteWord(String bisayaWord) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final userData = await getUserData();
      final favorites = (userData?['favoriteWords'] as List<dynamic>?) ?? [];
      final updatedFavorites = favorites.where((fav) => fav['bisaya'] != bisayaWord).toList();
      
      await _firestore.collection('users').doc(user.uid).update({
        'favoriteWords': updatedFavorites,
      });
    } catch (e) {
      throw Exception('Failed to remove favorite word: $e');
    }
  }

  /// Get all favorite words
  Future<List<Map<String, dynamic>>> getFavoriteWords() async {
    final userData = await getUserData();
    final favorites = (userData?['favoriteWords'] as List<dynamic>?) ?? [];
    return favorites.map((fav) => Map<String, dynamic>.from(fav)).toList();
  }

  /// Check if word is favorited
  Future<bool> isFavoriteWord(String bisayaWord) async {
    final favorites = await getFavoriteWords();
    return favorites.any((fav) => fav['bisaya'] == bisayaWord);
  }
}

