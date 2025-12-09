import 'dart:io';
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

  /// Upload profile picture to Firebase Storage
  Future<String> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Delete old profile picture if exists
      try {
        final oldRef = _storage.ref('profile_pictures/${user.uid}.jpg');
        await oldRef.delete();
      } catch (e) {
        // Ignore if file doesn't exist (error code 404)
        if (e.toString().contains('404') || e.toString().contains('not-found')) {
          // File doesn't exist, which is fine
        } else {
          // Log other errors but continue
          print('Warning: Could not delete old profile picture: $e');
        }
      }

      // Upload new profile picture with metadata
      final ref = _storage.ref('profile_pictures/${user.uid}.jpg');
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
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

  /// Pick image from gallery or camera
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
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
}

