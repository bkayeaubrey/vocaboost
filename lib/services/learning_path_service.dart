import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing learning paths/courses
/// Structured curriculum from Beginner to Advanced
class LearningPathService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Learning path definitions
  static final List<Map<String, dynamic>> _learningPaths = [
    {
      'id': 'basics',
      'name': 'Bisaya Basics',
      'description': 'Start your journey with essential greetings and expressions',
      'icon': '🌱',
      'color': 0xFF4CAF50,
      'difficulty': 'Beginner',
      'estimatedHours': 2,
      'xpReward': 500,
      'lessons': [
        {
          'id': 'greetings',
          'name': 'Greetings',
          'description': 'Learn how to say hello and goodbye',
          'words': ['Kumusta', 'Maayong buntag', 'Maayong hapon', 'Maayong gabii', 'Amping'],
          'xpReward': 50,
        },
        {
          'id': 'introductions',
          'name': 'Introductions',
          'description': 'Introduce yourself in Bisaya',
          'words': ['Ako si', 'Unsa imong ngalan', 'Taga asa ka', 'Malipayon'],
          'xpReward': 50,
        },
        {
          'id': 'basic_phrases',
          'name': 'Basic Phrases',
          'description': 'Essential everyday phrases',
          'words': ['Oo', 'Dili', 'Salamat', 'Palihug', 'Pasayloa ko'],
          'xpReward': 50,
        },
        {
          'id': 'numbers_1_10',
          'name': 'Numbers 1-10',
          'description': 'Count from one to ten',
          'words': ['Usa', 'Duha', 'Tulo', 'Upat', 'Lima', 'Unom', 'Pito', 'Walo', 'Siyam', 'Napulo'],
          'xpReward': 75,
        },
        {
          'id': 'colors',
          'name': 'Colors',
          'description': 'Learn common colors',
          'words': ['Pula', 'Asul', 'Berde', 'Dilaw', 'Itom', 'Puti'],
          'xpReward': 50,
        },
      ],
    },
    {
      'id': 'everyday',
      'name': 'Everyday Conversations',
      'description': 'Common phrases for daily life situations',
      'icon': '💬',
      'color': 0xFF2196F3,
      'difficulty': 'Beginner',
      'estimatedHours': 3,
      'xpReward': 750,
      'prerequisite': 'basics',
      'lessons': [
        {
          'id': 'family',
          'name': 'Family Members',
          'description': 'Talk about your family',
          'words': ['Amahan', 'Inahan', 'Anak', 'Igsoon', 'Lolo', 'Lola'],
          'xpReward': 50,
        },
        {
          'id': 'time',
          'name': 'Time & Days',
          'description': 'Express time and days of the week',
          'words': ['Karon', 'Ugma', 'Gahapon', 'Buntag', 'Hapon', 'Gabii'],
          'xpReward': 60,
        },
        {
          'id': 'food_drinks',
          'name': 'Food & Drinks',
          'description': 'Order food and drinks',
          'words': ['Kan-on', 'Tubig', 'Kape', 'Isda', 'Karne', 'Utan'],
          'xpReward': 60,
        },
        {
          'id': 'weather',
          'name': 'Weather',
          'description': 'Talk about the weather',
          'words': ['Init', 'Bugnaw', 'Ulan', 'Hangin', 'Adlaw'],
          'xpReward': 50,
        },
        {
          'id': 'directions',
          'name': 'Directions',
          'description': 'Ask for and give directions',
          'words': ['Wala', 'Tuo', 'Diretso', 'Unahan', 'Luyo'],
          'xpReward': 75,
        },
      ],
    },
    {
      'id': 'travel',
      'name': 'Travel & Tourism',
      'description': 'Essential phrases for traveling in Bisaya regions',
      'icon': '✈️',
      'color': 0xFFFF9800,
      'difficulty': 'Intermediate',
      'estimatedHours': 4,
      'xpReward': 1000,
      'prerequisite': 'everyday',
      'lessons': [
        {
          'id': 'transportation',
          'name': 'Transportation',
          'description': 'Get around using public transport',
          'words': ['Jeepney', 'Habal-habal', 'Barko', 'Eroplano', 'Sakyanan'],
          'xpReward': 75,
        },
        {
          'id': 'hotel',
          'name': 'At the Hotel',
          'description': 'Book and stay at accommodations',
          'words': ['Kuwarto', 'Higdaan', 'Bayad', 'Susi', 'Pahulay'],
          'xpReward': 75,
        },
        {
          'id': 'shopping',
          'name': 'Shopping',
          'description': 'Buy things at markets and stores',
          'words': ['Pila', 'Mahal', 'Barato', 'Palit', 'Tinda'],
          'xpReward': 75,
        },
        {
          'id': 'restaurant',
          'name': 'At the Restaurant',
          'description': 'Order food at restaurants',
          'words': ['Menu', 'Pagkaon', 'Ilimnon', 'Bayad', 'Lamian'],
          'xpReward': 75,
        },
        {
          'id': 'emergencies',
          'name': 'Emergencies',
          'description': 'Handle emergency situations',
          'words': ['Tabang', 'Doktor', 'Pulis', 'Sunog', 'Ospital'],
          'xpReward': 100,
        },
      ],
    },
    {
      'id': 'culture',
      'name': 'Bisaya Culture',
      'description': 'Deep dive into Bisaya traditions and expressions',
      'icon': '🎭',
      'color': 0xFF9C27B0,
      'difficulty': 'Intermediate',
      'estimatedHours': 5,
      'xpReward': 1250,
      'prerequisite': 'everyday',
      'lessons': [
        {
          'id': 'festivals',
          'name': 'Festivals',
          'description': 'Learn about Bisaya festivals',
          'words': ['Sinulog', 'Fiesta', 'Sayaw', 'Salo-salo', 'Pasalamat'],
          'xpReward': 100,
        },
        {
          'id': 'traditions',
          'name': 'Traditions',
          'description': 'Understand cultural traditions',
          'words': ['Mano', 'Bayanihan', 'Pagdayeg', 'Pagtahod', 'Kasal'],
          'xpReward': 100,
        },
        {
          'id': 'proverbs',
          'name': 'Proverbs & Sayings',
          'description': 'Learn Bisaya wisdom',
          'words': ['Sanglitanan', 'Hunahuna', 'Kamatuoran', 'Kaalam'],
          'xpReward': 125,
        },
        {
          'id': 'music',
          'name': 'Music & Songs',
          'description': 'Bisaya musical expressions',
          'words': ['Kanta', 'Awit', 'Gitara', 'Tugon', 'Melodiya'],
          'xpReward': 100,
        },
      ],
    },
    {
      'id': 'advanced',
      'name': 'Advanced Bisaya',
      'description': 'Master complex grammar and expressions',
      'icon': '🎓',
      'color': 0xFFE91E63,
      'difficulty': 'Advanced',
      'estimatedHours': 8,
      'xpReward': 2000,
      'prerequisite': 'travel',
      'lessons': [
        {
          'id': 'verb_conjugation',
          'name': 'Verb Conjugation',
          'description': 'Master Bisaya verb forms',
          'words': ['Mokaon', 'Gikaon', 'Kaonon', 'Nagkaon', 'Makaon'],
          'xpReward': 150,
        },
        {
          'id': 'complex_sentences',
          'name': 'Complex Sentences',
          'description': 'Build complex sentence structures',
          'words': ['Tungod kay', 'Kung', 'Samtang', 'Bisan pa', 'Apan'],
          'xpReward': 150,
        },
        {
          'id': 'formal_speech',
          'name': 'Formal Speech',
          'description': 'Formal and polite expressions',
          'words': ['Gikinahanglan', 'Mahimo ba', 'Uyon', 'Pangutana'],
          'xpReward': 175,
        },
        {
          'id': 'idioms',
          'name': 'Idioms & Expressions',
          'description': 'Native Bisaya expressions',
          'words': ['Tingala', 'Bati', 'Paspas', 'Hinay-hinay'],
          'xpReward': 175,
        },
        {
          'id': 'storytelling',
          'name': 'Storytelling',
          'description': 'Tell stories in Bisaya',
          'words': ['Sugilanon', 'Karaan', 'Bayani', 'Katapusan'],
          'xpReward': 200,
        },
      ],
    },
  ];

  /// Get all learning paths
  List<Map<String, dynamic>> getAllPaths() {
    return List.from(_learningPaths);
  }

  /// Get a specific path by ID
  Map<String, dynamic>? getPathById(String pathId) {
    try {
      return _learningPaths.firstWhere((p) => p['id'] == pathId);
    } catch (e) {
      return null;
    }
  }

  /// Get user's progress for all paths
  Future<Map<String, Map<String, dynamic>>> getUserProgress() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_paths')
          .get();

      Map<String, Map<String, dynamic>> progress = {};
      for (final doc in snapshot.docs) {
        progress[doc.id] = doc.data();
      }
      return progress;
    } catch (e) {
      debugPrint('Error getting user progress: $e');
      return {};
    }
  }

  /// Get progress for a specific path
  Future<Map<String, dynamic>> getPathProgress(String pathId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'completedLessons': [], 'startedAt': null, 'completedAt': null};
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_paths')
          .doc(pathId)
          .get();

      if (!doc.exists) {
        return {'completedLessons': [], 'startedAt': null, 'completedAt': null};
      }

      return doc.data()!;
    } catch (e) {
      debugPrint('Error getting path progress: $e');
      return {'completedLessons': [], 'startedAt': null, 'completedAt': null};
    }
  }

  /// Start a learning path
  Future<bool> startPath(String pathId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_paths')
          .doc(pathId)
          .set({
        'startedAt': FieldValue.serverTimestamp(),
        'completedLessons': [],
        'completedAt': null,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error starting path: $e');
      return false;
    }
  }

  /// Complete a lesson in a path
  Future<Map<String, dynamic>> completeLesson(String pathId, String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Not logged in'};
    }

    try {
      final path = getPathById(pathId);
      if (path == null) {
        return {'success': false, 'message': 'Path not found'};
      }

      final lessons = path['lessons'] as List<dynamic>;
      final lesson = lessons.firstWhere(
        (l) => l['id'] == lessonId,
        orElse: () => null,
      );

      if (lesson == null) {
        return {'success': false, 'message': 'Lesson not found'};
      }

      // Get current progress
      final progressDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_paths')
          .doc(pathId)
          .get();

      List<String> completedLessons = [];
      if (progressDoc.exists) {
        completedLessons = List<String>.from(progressDoc.data()?['completedLessons'] ?? []);
      }

      // Check if already completed
      if (completedLessons.contains(lessonId)) {
        return {'success': true, 'message': 'Lesson already completed', 'alreadyCompleted': true};
      }

      // Mark lesson as completed
      completedLessons.add(lessonId);

      // Check if path is now complete
      bool pathCompleted = completedLessons.length == lessons.length;

      // Get existing startedAt or use null
      dynamic existingStartedAt;
      if (progressDoc.exists) {
        final data = progressDoc.data();
        existingStartedAt = data?['startedAt'];
      }
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('learning_paths')
          .doc(pathId)
          .set({
        'completedLessons': completedLessons,
        'completedAt': pathCompleted ? FieldValue.serverTimestamp() : null,
        'startedAt': existingStartedAt ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'success': true,
        'message': 'Lesson completed!',
        'xpEarned': lesson['xpReward'],
        'pathCompleted': pathCompleted,
        'totalCompleted': completedLessons.length,
        'totalLessons': lessons.length,
      };
    } catch (e) {
      debugPrint('Error completing lesson: $e');
      return {'success': false, 'message': 'Failed to complete lesson'};
    }
  }

  /// Check if prerequisite is met
  Future<bool> isPathUnlocked(String pathId) async {
    final path = getPathById(pathId);
    if (path == null) return false;

    final prerequisiteId = path['prerequisite'] as String?;
    if (prerequisiteId == null) return true; // No prerequisite

    final progress = await getPathProgress(prerequisiteId);
    return progress['completedAt'] != null;
  }

  /// Get words for a lesson
  List<String> getLessonWords(String pathId, String lessonId) {
    final path = getPathById(pathId);
    if (path == null) return [];

    final lessons = path['lessons'] as List<dynamic>;
    final lesson = lessons.firstWhere(
      (l) => l['id'] == lessonId,
      orElse: () => null,
    );

    if (lesson == null) return [];
    return List<String>.from(lesson['words'] ?? []);
  }

  /// Get next uncompleted lesson in a path
  Future<Map<String, dynamic>?> getNextLesson(String pathId) async {
    final path = getPathById(pathId);
    if (path == null) return null;

    final progress = await getPathProgress(pathId);
    final completedLessons = List<String>.from(progress['completedLessons'] ?? []);
    final lessons = path['lessons'] as List<dynamic>;

    for (final lesson in lessons) {
      if (!completedLessons.contains(lesson['id'])) {
        return Map<String, dynamic>.from(lesson);
      }
    }

    return null; // All lessons completed
  }
}
