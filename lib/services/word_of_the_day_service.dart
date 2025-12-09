import 'package:cloud_firestore/cloud_firestore.dart';

class WordOfTheDayService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Seed data for Bisaya (Davao) words - can be extended via Firestore
  final List<Map<String, String>> _seedWords = [
    {'bisaya': 'Panagsa', 'english': 'Sometimes', 'pronunciation': 'pah-nahg-sah'},
    {'bisaya': 'Maayong buntag', 'english': 'Good morning', 'pronunciation': 'mah-ah-yong boon-tag'},
    {'bisaya': 'Kumusta', 'english': 'Hello / How are you', 'pronunciation': 'koo-moos-tah'},
    {'bisaya': 'Salamat', 'english': 'Thank you', 'pronunciation': 'sah-lah-maht'},
    {'bisaya': 'Gwapa', 'english': 'Beautiful', 'pronunciation': 'gwah-pah'},
    {'bisaya': 'Tubig', 'english': 'Water', 'pronunciation': 'too-big'},
    {'bisaya': 'Maayo', 'english': 'Good / Fine', 'pronunciation': 'mah-ah-yo'},
    {'bisaya': 'Dili', 'english': 'No', 'pronunciation': 'dee-lee'},
    {'bisaya': 'Oo', 'english': 'Yes', 'pronunciation': 'oh-oh'},
    {'bisaya': 'Palihug', 'english': 'Please', 'pronunciation': 'pah-lee-hoog'},
    {'bisaya': 'Pasaylo', 'english': 'Sorry', 'pronunciation': 'pah-sah-yo-lo'},
    {'bisaya': 'Maayong hapon', 'english': 'Good afternoon', 'pronunciation': 'mah-ah-yong hah-pon'},
    {'bisaya': 'Maayong gabii', 'english': 'Good evening', 'pronunciation': 'mah-ah-yong gah-bee-ee'},
    {'bisaya': 'Kumusta na ka?', 'english': 'How are you?', 'pronunciation': 'koo-moos-tah nah kah'},
    {'bisaya': 'Kaayo', 'english': 'Very', 'pronunciation': 'kah-ah-yo'},
    {'bisaya': 'Daghan', 'english': 'Many / A lot', 'pronunciation': 'dah-ghan'},
    {'bisaya': 'Gamay', 'english': 'Small / Little', 'pronunciation': 'gah-may'},
    {'bisaya': 'Dako', 'english': 'Big / Large', 'pronunciation': 'dah-ko'},
    {'bisaya': 'Gutom', 'english': 'Hungry', 'pronunciation': 'goo-tom'},
    {'bisaya': 'Busog', 'english': 'Full / Satisfied', 'pronunciation': 'boo-sog'},
    {'bisaya': 'Katawa', 'english': 'Laugh', 'pronunciation': 'kah-tah-wah'},
    {'bisaya': 'Higugma', 'english': 'Love', 'pronunciation': 'hee-goog-mah'},
    {'bisaya': 'Balay', 'english': 'House / Home', 'pronunciation': 'bah-lay'},
    {'bisaya': 'Kwarta', 'english': 'Money', 'pronunciation': 'kwahr-tah'},
    {'bisaya': 'Pagkaon', 'english': 'Food', 'pronunciation': 'pahg-kah-on'},
    {'bisaya': 'Inom', 'english': 'Drink', 'pronunciation': 'ee-nom'},
    {'bisaya': 'Tulog', 'english': 'Sleep', 'pronunciation': 'too-log'},
    {'bisaya': 'Lakaw', 'english': 'Walk', 'pronunciation': 'lah-kaw'},
    {'bisaya': 'Dagan', 'english': 'Run', 'pronunciation': 'dah-gan'},
    {'bisaya': 'Basaha', 'english': 'Read', 'pronunciation': 'bah-sah-hah'},
    {'bisaya': 'Sulat', 'english': 'Write', 'pronunciation': 'soo-laht'},
    {'bisaya': 'Paminaw', 'english': 'Listen', 'pronunciation': 'pah-mee-naw'},
    {'bisaya': 'Sulti', 'english': 'Speak / Say', 'pronunciation': 'sool-tee'},
    {'bisaya': 'Tan-aw', 'english': 'Look / See', 'pronunciation': 'tahn-aw'},
    {'bisaya': 'Buhat', 'english': 'Do / Make', 'pronunciation': 'boo-haht'},
    {'bisaya': 'Adto', 'english': 'There', 'pronunciation': 'ahd-toh'},
    {'bisaya': 'Dinhi', 'english': 'Here', 'pronunciation': 'deen-hee'},
    {'bisaya': 'Asa', 'english': 'Where', 'pronunciation': 'ah-sah'},
    {'bisaya': 'Kanus-a', 'english': 'When', 'pronunciation': 'kah-noos-ah'},
    {'bisaya': 'Ngano', 'english': 'Why', 'pronunciation': 'ngah-no'},
    {'bisaya': 'Unsa', 'english': 'What', 'pronunciation': 'oon-sah'},
    {'bisaya': 'Kinsa', 'english': 'Who', 'pronunciation': 'keen-sah'},
    {'bisaya': 'Giunsa', 'english': 'How', 'pronunciation': 'gee-oon-sah'},
    {'bisaya': 'Mahal', 'english': 'Expensive / Dear', 'pronunciation': 'mah-hahl'},
    {'bisaya': 'Barato', 'english': 'Cheap', 'pronunciation': 'bah-rah-to'},
    {'bisaya': 'Init', 'english': 'Hot', 'pronunciation': 'ee-neet'},
    {'bisaya': 'Bugnaw', 'english': 'Cold', 'pronunciation': 'boog-naw'},
    {'bisaya': 'Humok', 'english': 'Soft', 'pronunciation': 'hoo-mok'},
    {'bisaya': 'Gahi', 'english': 'Hard', 'pronunciation': 'gah-hee'},
    {'bisaya': 'Bag-o', 'english': 'New', 'pronunciation': 'bah-go'},
    {'bisaya': 'Daan', 'english': 'Old', 'pronunciation': 'dah-an'},
    {'bisaya': 'Hinlo', 'english': 'Clean', 'pronunciation': 'heen-lo'},
    {'bisaya': 'Hugaw', 'english': 'Dirty', 'pronunciation': 'hoo-gaw'},
  ];

  /// Get the word of the day based on the current date
  /// This ensures the same word is shown throughout the day
  Future<Map<String, String>> getWordOfTheDay() async {
    try {
      // First, try to get words from Firestore (if available)
      final wordsSnapshot = await _firestore
          .collection('words_of_the_day')
          .limit(1)
          .get();

      List<Map<String, String>> availableWords = [];

      if (wordsSnapshot.docs.isNotEmpty) {
        // Use Firestore words if available
        for (var doc in wordsSnapshot.docs) {
          final data = doc.data();
          availableWords.add({
            'bisaya': data['bisaya'] ?? '',
            'english': data['english'] ?? '',
            'pronunciation': data['pronunciation'] ?? '',
          });
        }
      }

      // If Firestore has words, use them; otherwise use seed data
      if (availableWords.isEmpty) {
        availableWords = List.from(_seedWords);
      } else {
        // Merge Firestore words with seed words for more variety
        availableWords = [...availableWords, ..._seedWords];
      }

      // Select a random word each time
      final random = DateTime.now().millisecondsSinceEpoch % availableWords.length;
      return availableWords[random];
    } catch (e) {
      // Fallback to seed data if Firestore fails
      final random = DateTime.now().millisecondsSinceEpoch % _seedWords.length;
      return _seedWords[random];
    }
  }

  /// Add a new word to Firestore (for admin use)
  Future<void> addWord({
    required String bisaya,
    required String english,
    String? pronunciation,
  }) async {
    try {
      await _firestore.collection('words_of_the_day').add({
        'bisaya': bisaya,
        'english': english,
        'pronunciation': pronunciation ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add word: $e');
    }
  }

  /// Get all words from Firestore (for admin/managing)
  Future<List<Map<String, String>>> getAllWords() async {
    try {
      final snapshot = await _firestore
          .collection('words_of_the_day')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, String>{
          'bisaya': (data['bisaya'] as String?) ?? '',
          'english': (data['english'] as String?) ?? '',
          'pronunciation': (data['pronunciation'] as String?) ?? '',
        };
      }).toList();
    } catch (e) {
      return <Map<String, String>>[];
    }
  }
}

