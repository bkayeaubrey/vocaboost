import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing customizable avatars
/// Users can unlock and equip avatar items using XP
class AvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Avatar item categories
  static const String categoryHead = 'head';
  static const String categoryFace = 'face';
  static const String categoryBody = 'body';
  static const String categoryAccessory = 'accessory';
  static const String categoryBackground = 'background';

  // Default avatar items (free)
  static final List<Map<String, dynamic>> _defaultItems = [
    // Heads
    {'id': 'head_default', 'category': categoryHead, 'name': 'Default', 'icon': '😊', 'color': 0xFF4CAF50, 'xpCost': 0, 'isDefault': true},
    {'id': 'head_cool', 'category': categoryHead, 'name': 'Cool', 'icon': '😎', 'color': 0xFF2196F3, 'xpCost': 100},
    {'id': 'head_happy', 'category': categoryHead, 'name': 'Happy', 'icon': '😄', 'color': 0xFFFFEB3B, 'xpCost': 150},
    {'id': 'head_smart', 'category': categoryHead, 'name': 'Smart', 'icon': '🤓', 'color': 0xFF9C27B0, 'xpCost': 200},
    {'id': 'head_star', 'category': categoryHead, 'name': 'Star', 'icon': '🌟', 'color': 0xFFFF9800, 'xpCost': 500},
    {'id': 'head_crown', 'category': categoryHead, 'name': 'Royal', 'icon': '👑', 'color': 0xFFFFD700, 'xpCost': 1000},
    
    // Faces
    {'id': 'face_default', 'category': categoryFace, 'name': 'Normal', 'icon': '👤', 'color': 0xFF795548, 'xpCost': 0, 'isDefault': true},
    {'id': 'face_glasses', 'category': categoryFace, 'name': 'Glasses', 'icon': '👓', 'color': 0xFF607D8B, 'xpCost': 75},
    {'id': 'face_sunglasses', 'category': categoryFace, 'name': 'Sunglasses', 'icon': '🕶️', 'color': 0xFF212121, 'xpCost': 150},
    {'id': 'face_monocle', 'category': categoryFace, 'name': 'Monocle', 'icon': '🧐', 'color': 0xFFD4AF37, 'xpCost': 300},
    
    // Bodies
    {'id': 'body_default', 'category': categoryBody, 'name': 'Casual', 'icon': '👕', 'color': 0xFF3F51B5, 'xpCost': 0, 'isDefault': true},
    {'id': 'body_formal', 'category': categoryBody, 'name': 'Formal', 'icon': '👔', 'color': 0xFF1A237E, 'xpCost': 200},
    {'id': 'body_sporty', 'category': categoryBody, 'name': 'Sporty', 'icon': '🏃', 'color': 0xFFE91E63, 'xpCost': 250},
    {'id': 'body_superhero', 'category': categoryBody, 'name': 'Hero', 'icon': '🦸', 'color': 0xFFF44336, 'xpCost': 750},
    
    // Accessories
    {'id': 'acc_none', 'category': categoryAccessory, 'name': 'None', 'icon': '➖', 'color': 0xFF9E9E9E, 'xpCost': 0, 'isDefault': true},
    {'id': 'acc_medal', 'category': categoryAccessory, 'name': 'Medal', 'icon': '🏅', 'color': 0xFFFFD700, 'xpCost': 300},
    {'id': 'acc_trophy', 'category': categoryAccessory, 'name': 'Trophy', 'icon': '🏆', 'color': 0xFFFFD700, 'xpCost': 500},
    {'id': 'acc_book', 'category': categoryAccessory, 'name': 'Book', 'icon': '📚', 'color': 0xFF8D6E63, 'xpCost': 100},
    {'id': 'acc_flag', 'category': categoryAccessory, 'name': 'Flag', 'icon': '🇵🇭', 'color': 0xFF0038A8, 'xpCost': 250},
    {'id': 'acc_sparkles', 'category': categoryAccessory, 'name': 'Sparkles', 'icon': '✨', 'color': 0xFFFFEB3B, 'xpCost': 400},
    
    // Backgrounds
    {'id': 'bg_default', 'category': categoryBackground, 'name': 'Blue', 'icon': '🔵', 'color': 0xFF3B5FAE, 'xpCost': 0, 'isDefault': true},
    {'id': 'bg_sunset', 'category': categoryBackground, 'name': 'Sunset', 'icon': '🌅', 'color': 0xFFFF7043, 'xpCost': 150},
    {'id': 'bg_nature', 'category': categoryBackground, 'name': 'Nature', 'icon': '🌿', 'color': 0xFF4CAF50, 'xpCost': 200},
    {'id': 'bg_ocean', 'category': categoryBackground, 'name': 'Ocean', 'icon': '🌊', 'color': 0xFF00BCD4, 'xpCost': 250},
    {'id': 'bg_stars', 'category': categoryBackground, 'name': 'Stars', 'icon': '🌌', 'color': 0xFF1A237E, 'xpCost': 350},
    {'id': 'bg_rainbow', 'category': categoryBackground, 'name': 'Rainbow', 'icon': '🌈', 'color': 0xFFE91E63, 'xpCost': 500},
    {'id': 'bg_gold', 'category': categoryBackground, 'name': 'Gold', 'icon': '💛', 'color': 0xFFFFD700, 'xpCost': 1000},
  ];

  /// Get all available avatar items
  List<Map<String, dynamic>> getAllItems() {
    return List.from(_defaultItems);
  }

  /// Get items by category
  List<Map<String, dynamic>> getItemsByCategory(String category) {
    return _defaultItems.where((item) => item['category'] == category).toList();
  }

  /// Get user's unlocked items
  Future<List<String>> getUnlockedItems() async {
    final user = _auth.currentUser;
    if (user == null) return _getDefaultItemIds();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('avatar')
          .doc('unlocked')
          .get();

      if (!doc.exists) {
        return _getDefaultItemIds();
      }

      final data = doc.data()!;
      final items = List<String>.from(data['items'] ?? []);
      
      // Always include default items
      for (final defaultId in _getDefaultItemIds()) {
        if (!items.contains(defaultId)) {
          items.add(defaultId);
        }
      }
      
      return items;
    } catch (e) {
      debugPrint('Error getting unlocked items: $e');
      return _getDefaultItemIds();
    }
  }

  /// Get default item IDs
  List<String> _getDefaultItemIds() {
    return _defaultItems
        .where((item) => item['isDefault'] == true)
        .map((item) => item['id'] as String)
        .toList();
  }

  /// Get user's equipped avatar
  Future<Map<String, String>> getEquippedAvatar() async {
    final user = _auth.currentUser;
    if (user == null) return _getDefaultEquipped();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('avatar')
          .doc('equipped')
          .get();

      if (!doc.exists) {
        return _getDefaultEquipped();
      }

      final data = doc.data()!;
      return {
        categoryHead: data[categoryHead] ?? 'head_default',
        categoryFace: data[categoryFace] ?? 'face_default',
        categoryBody: data[categoryBody] ?? 'body_default',
        categoryAccessory: data[categoryAccessory] ?? 'acc_none',
        categoryBackground: data[categoryBackground] ?? 'bg_default',
      };
    } catch (e) {
      debugPrint('Error getting equipped avatar: $e');
      return _getDefaultEquipped();
    }
  }

  /// Get default equipped items
  Map<String, String> _getDefaultEquipped() {
    return {
      categoryHead: 'head_default',
      categoryFace: 'face_default',
      categoryBody: 'body_default',
      categoryAccessory: 'acc_none',
      categoryBackground: 'bg_default',
    };
  }

  /// Unlock an item using XP
  Future<Map<String, dynamic>> unlockItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Not logged in'};
    }

    try {
      // Find the item
      final item = _defaultItems.firstWhere(
        (i) => i['id'] == itemId,
        orElse: () => {},
      );

      if (item.isEmpty) {
        return {'success': false, 'message': 'Item not found'};
      }

      final xpCost = item['xpCost'] as int;

      // Check if already unlocked
      final unlockedItems = await getUnlockedItems();
      if (unlockedItems.contains(itemId)) {
        return {'success': false, 'message': 'Already unlocked'};
      }

      // Get user's current XP
      final xpDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_data')
          .doc('current')
          .get();

      int totalXP = 0;
      if (xpDoc.exists) {
        totalXP = (xpDoc.data()?['totalXP'] as num?)?.toInt() ?? 0;
      }

      if (totalXP < xpCost) {
        return {
          'success': false,
          'message': 'Not enough XP (need $xpCost, have $totalXP)',
        };
      }

      // Deduct XP and unlock item
      await _firestore.runTransaction((transaction) async {
        // Update XP
        transaction.update(
          _firestore.collection('users').doc(user.uid).collection('xp_data').doc('current'),
          {'totalXP': totalXP - xpCost},
        );

        // Add to unlocked items
        final unlockedRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('avatar')
            .doc('unlocked');

        final unlockedDoc = await transaction.get(unlockedRef);
        if (unlockedDoc.exists) {
          transaction.update(unlockedRef, {
            'items': FieldValue.arrayUnion([itemId]),
          });
        } else {
          transaction.set(unlockedRef, {
            'items': [..._getDefaultItemIds(), itemId],
          });
        }
      });

      return {
        'success': true,
        'message': 'Unlocked ${item['name']}!',
        'xpSpent': xpCost,
        'remainingXP': totalXP - xpCost,
      };
    } catch (e) {
      debugPrint('Error unlocking item: $e');
      return {'success': false, 'message': 'Failed to unlock item'};
    }
  }

  /// Equip an item
  Future<bool> equipItem(String category, String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Verify item is unlocked
      final unlockedItems = await getUnlockedItems();
      if (!unlockedItems.contains(itemId)) {
        return false;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('avatar')
          .doc('equipped')
          .set({category: itemId}, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error equipping item: $e');
      return false;
    }
  }

  /// Get item details by ID
  Map<String, dynamic>? getItemById(String itemId) {
    try {
      return _defaultItems.firstWhere((item) => item['id'] == itemId);
    } catch (e) {
      return null;
    }
  }

  /// Get user's current XP
  Future<int> getCurrentXP() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final xpDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_data')
          .doc('current')
          .get();

      if (!xpDoc.exists) return 0;
      return (xpDoc.data()?['totalXP'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
