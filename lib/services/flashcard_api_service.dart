import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vocaboost/services/dataset_service.dart';

/// API Service for generating flashcards and practice exercises using OpenAI
class FlashcardApiService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  /// Get flashcards from API
  /// 
  /// [count] - Number of flashcards to generate
  /// [difficulty] - Optional difficulty level (beginner, intermediate, advanced)
  /// 
  /// Returns a list of flashcards with word, pronunciation, meaning, examples, etc.
  Future<List<Map<String, dynamic>>> getFlashcards({
    int count = 10,
    String? difficulty,
  }) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
      }

      final prompt = '''Generate $count ACCURATE and REALISTIC Bisaya (Cebuano) learning flashcards in JSON format.

CRITICAL REQUIREMENTS FOR ACCURACY:
1. Use authentic Bisaya grammar and sentence structure
2. Ensure proper verb conjugation (mo-, nag-, gi- prefixes)
3. Use culturally appropriate and commonly used phrases
4. Provide accurate phonetic pronunciation following Bisaya phonetics
5. Include realistic, everyday usage examples
6. Ensure translations are precise and natural

Each flashcard must have:
- word: The Bisaya word (use proper spelling and capitalization)
- pronunciation: Accurate phonetic guide using Bisaya phonetics (e.g., "kah-ON" with stress on capitalized syllable)
- meaning: Precise English translation
- partOfSpeech: Accurate part of speech (Verb, Noun, Adjective, Adverb, Number, etc.)
- category: Category (Food & Dining, Family, Numbers, Market/Shopping, Greetings, Common Phrases)
- imageEmoji: Relevant emoji for the word
- difficulty: Realistic difficulty level 1-5 based on:
  * 1: Very common, short words (e.g., "Oo", "Dili", "Kaon")
  * 2: Common daily words (e.g., "Tubig", "Balay", "Mopalit")
  * 3: Moderate complexity (e.g., "Amahan", "Maayong buntag")
  * 4: Complex words with affixes (e.g., "Nagkaon", "Gipalit")
  * 5: Advanced vocabulary and phrases
- contextualExamples: Object with beginner, intermediate, and advanced arrays, each containing 2 REALISTIC example sentences in format "Bisaya sentence → English translation"
  * Beginner: Simple, short sentences with basic grammar
  * Intermediate: Longer sentences with common verb forms
  * Advanced: Complex sentences with proper affixes and grammar

${difficulty != null ? 'Focus on $difficulty level words.' : ''}

Return ONLY a valid JSON array, no other text. Example format:
[
  {
    "word": "Kaon",
    "pronunciation": "kah-ON",
    "meaning": "To eat",
    "partOfSpeech": "Verb",
    "category": "Food & Dining",
    "imageEmoji": "🍽️",
    "difficulty": 2,
    "contextualExamples": {
      "beginner": ["Kaon na. → Let's eat now.", "Gusto ko mokaon. → I want to eat."],
      "intermediate": ["Nakaon na ba ka? → Have you eaten already?", "Mokaon ta sa restaurant. → Let's eat at the restaurant."],
      "advanced": ["Gikaon nako ang tinapay ganina. → I ate the bread earlier.", "Dili ko mokaon ug karne. → I don't eat meat."]
    }
  }
]''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a Bisaya language learning assistant. Always respond with valid JSON only, no markdown formatting, no code blocks.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final content = message['content'] as String;
          
          // Clean the content (remove markdown code blocks if present)
          String cleanedContent = content.trim();
          if (cleanedContent.startsWith('```json')) {
            cleanedContent = cleanedContent.substring(7);
          }
          if (cleanedContent.startsWith('```')) {
            cleanedContent = cleanedContent.substring(3);
          }
          if (cleanedContent.endsWith('```')) {
            cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
          }
          cleanedContent = cleanedContent.trim();
          
          final flashcards = jsonDecode(cleanedContent) as List;
          return flashcards.cast<Map<String, dynamic>>();
        }
        throw Exception('No flashcards generated from API');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] as String?;
        throw Exception(errorMessage ?? 'Failed to get flashcards. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting flashcards from API: $e');
      rethrow;
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();
  final DatasetService _datasetService = DatasetService.instance;

  /// Get fill-in-the-blank exercise for a word from database (saved_words collection)
  /// Uses contextual examples (beginner/intermediate/advanced) row by row
  /// 
  /// [word] - The Bisaya word
  /// [meaning] - English meaning
  /// [partOfSpeech] - Part of speech
  /// 
  /// Returns a fill-in-the-blank exercise with sentence, options, correct answer, and feedback
  Future<Map<String, dynamic>> getFillInBlankExercise({
    required String word,
    required String meaning,
    required String partOfSpeech,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to get fill-in-blank exercises');
      }

      // Query saved_words collection for the word
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_words')
          .where('input', isEqualTo: word)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Word not found in saved_words collection');
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Get contextual examples from database (saved_words collection)
      String beginnerExample = (data['beginnerExample'] as String? ?? '').trim();
      String intermediateExample = (data['intermediateExample'] as String? ?? '').trim();
      String advancedExample = (data['advancedExample'] as String? ?? '').trim();

      // If no examples in saved_words, try dataset service as fallback
      if (beginnerExample.isEmpty && intermediateExample.isEmpty && advancedExample.isEmpty) {
        debugPrint('⚠️ No examples in saved_words, trying dataset service...');
        
        // Ensure dataset is loaded
        if (!_datasetService.isLoaded) {
          try {
            await _datasetService.loadDataset();
          } catch (e) {
            debugPrint('⚠️ Failed to load dataset: $e');
          }
        }
        
        // Get metadata from dataset
        final metadata = _datasetService.getWordMetadata(word);
        if (metadata != null) {
          beginnerExample = (metadata['beginnerExample'] as String? ?? '').trim();
          intermediateExample = (metadata['intermediateExample'] as String? ?? '').trim();
          advancedExample = (metadata['advancedExample'] as String? ?? '').trim();
        }
      }

      // Get all available examples
      final List<String> availableExamples = [];
      if (beginnerExample.isNotEmpty) availableExamples.add(beginnerExample);
      if (intermediateExample.isNotEmpty) availableExamples.add(intermediateExample);
      if (advancedExample.isNotEmpty) availableExamples.add(advancedExample);

      if (availableExamples.isEmpty) {
        throw Exception('No contextual examples found for this word in database or dataset');
      }

      // Select a random example from available ones
      final selectedExample = availableExamples[_random.nextInt(availableExamples.length)];
      
      // Determine which level this example is from (for feedback)
      String exampleLevel = 'intermediate';
      if (selectedExample == beginnerExample) {
        exampleLevel = 'beginner';
      } else if (selectedExample == advancedExample) {
        exampleLevel = 'advanced';
      }

      // Create fill-in-the-blank from the selected example
      final result = _createFillInBlankFromExample(
        example: selectedExample,
        word: word,
        meaning: meaning,
        partOfSpeech: partOfSpeech,
        exampleLevel: exampleLevel,
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error getting fill-in-blank from database: $e');
      rethrow;
    }
  }

  /// Create fill-in-the-blank exercise from a contextual example sentence
  Map<String, dynamic> _createFillInBlankFromExample({
    required String example,
    required String word,
    required String meaning,
    required String partOfSpeech,
    required String exampleLevel,
  }) {
    final wordLower = word.toLowerCase().trim();
    final exampleLower = example.toLowerCase();
    
    // Find the word in the sentence (handle various forms)
    final wordForms = [
      word, // Original form
      wordLower, // Lowercase
      word.trim(), // Trimmed
      'mo$wordLower', // Infinitive
      'mag$wordLower', // Future/Infinitive
      'nag$wordLower', // Present progressive
      'gi$wordLower', // Past
      'ka$wordLower', // Ability/possibility
      wordLower.replaceAll('mo', ''), // Remove mo prefix
      wordLower.replaceAll('mag', ''), // Remove mag prefix
      wordLower.replaceAll('nag', ''), // Remove nag prefix
      wordLower.replaceAll('gi', ''), // Remove gi prefix
    ];

    String? foundForm;
    int foundIndex = -1;
    int foundLength = 0;

    // Search for the word in the sentence
    for (final form in wordForms) {
      if (form.isEmpty) continue;
      final formLower = form.toLowerCase();
      int index = exampleLower.indexOf(formLower);

      while (index != -1) {
        // Check if it's a whole word (not part of another word)
        final before = index > 0 ? exampleLower[index - 1] : ' ';
        final after = index + form.length < exampleLower.length 
            ? exampleLower[index + form.length] 
            : ' ';

        // Check if surrounded by word boundaries
        if (!_isLetter(before) && !_isLetter(after)) {
          foundForm = example.substring(index, index + form.length);
          foundIndex = index;
          foundLength = form.length;
          break;
        }

        index = exampleLower.indexOf(formLower, index + 1);
      }

      if (foundIndex != -1) break;
    }

    if (foundIndex == -1) {
      // Fallback: try partial match
      final partialIndex = exampleLower.indexOf(wordLower);
      if (partialIndex != -1) {
        final before = partialIndex > 0 ? exampleLower[partialIndex - 1] : ' ';
        final after = partialIndex + wordLower.length < exampleLower.length 
            ? exampleLower[partialIndex + wordLower.length] 
            : ' ';
        if (!_isLetter(before) && !_isLetter(after)) {
          foundIndex = partialIndex;
          foundLength = wordLower.length;
          foundForm = example.substring(partialIndex, partialIndex + wordLower.length);
        }
      }
    }

    if (foundIndex == -1 || foundForm == null) {
      throw Exception('Word "$word" not found in example sentence: "$example"');
    }

    // Create sentence with blank
    final sentence = '${example.substring(0, foundIndex)}_____${example.substring(foundIndex + foundLength)}';
    final correctAnswer = foundForm;

    // Generate wrong options
    final options = _generateWrongOptions(
      correctAnswer: correctAnswer,
      word: word,
      partOfSpeech: partOfSpeech,
    );

    // Generate feedback
    final feedback = _generateFeedback(
      correctAnswer: correctAnswer,
      word: word,
      meaning: meaning,
      partOfSpeech: partOfSpeech,
      exampleLevel: exampleLevel,
    );

    // Generate translation (simplified - could be enhanced)
    final translation = _generateTranslation(example, meaning);

    return {
      'sentence': sentence,
      'correctAnswer': correctAnswer,
      'options': options,
      'feedback': feedback,
      'translation': translation,
    };
  }

  /// Check if character is a letter
  bool _isLetter(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
           (code >= 97 && code <= 122) || // a-z
           (code >= 192 && code <= 255); // Extended Latin (for Bisaya characters)
  }

  /// Generate wrong options for the fill-in-the-blank
  List<String> _generateWrongOptions({
    required String correctAnswer,
    required String word,
    required String partOfSpeech,
  }) {
    final options = <String>[correctAnswer];
    final wordLower = word.toLowerCase();

    // Generate wrong options based on part of speech
    if (partOfSpeech.toLowerCase().contains('verb')) {
      // For verbs, use different verb forms as wrong options
      final baseWord = wordLower.replaceAll(RegExp(r'^(mo|mag|nag|gi|ka)'), '');
      
      if (!correctAnswer.toLowerCase().startsWith('mo') && baseWord.isNotEmpty) {
        options.add('mo$baseWord');
      }
      if (!correctAnswer.toLowerCase().startsWith('nag') && baseWord.isNotEmpty) {
        options.add('nag$baseWord');
      }
      if (!correctAnswer.toLowerCase().startsWith('gi') && baseWord.isNotEmpty) {
        options.add('gi$baseWord');
      }
      if (!correctAnswer.toLowerCase().startsWith('mag') && baseWord.isNotEmpty) {
        options.add('mag$baseWord');
      }
    } else {
      // For nouns/adjectives, add variations
      if (wordLower.endsWith('a')) {
        options.add('${wordLower.substring(0, wordLower.length - 1)}o');
      }
      if (wordLower.endsWith('o')) {
        options.add('${wordLower.substring(0, wordLower.length - 1)}a');
      }
      options.add('${wordLower}na');
      options.add('${wordLower}ng');
    }

    // Remove duplicates and ensure we have exactly 4 options
    options.removeWhere((opt) => opt.isEmpty);
    final uniqueOptions = options.toSet().toList();
    
    // If we don't have enough options, add generic wrong answers
    while (uniqueOptions.length < 4) {
      final genericWrong = '$wordLower${_random.nextInt(100)}';
      if (!uniqueOptions.contains(genericWrong)) {
        uniqueOptions.add(genericWrong);
      } else {
        break;
      }
    }

    // Shuffle and return exactly 4 options
    uniqueOptions.shuffle(_random);
    return uniqueOptions.take(4).toList();
  }

  /// Generate feedback for the exercise
  String _generateFeedback({
    required String correctAnswer,
    required String word,
    required String meaning,
    required String partOfSpeech,
    required String exampleLevel,
  }) {
    String feedback = 'Correct! ';
    
    if (partOfSpeech.toLowerCase().contains('verb')) {
      if (correctAnswer.toLowerCase().startsWith('mo')) {
        feedback += 'The form "$correctAnswer" is used for future actions or expressing desire. ';
      } else if (correctAnswer.toLowerCase().startsWith('nag')) {
        feedback += 'The form "$correctAnswer" indicates an ongoing or recent action. ';
      } else if (correctAnswer.toLowerCase().startsWith('gi')) {
        feedback += 'The form "$correctAnswer" is the past tense form. ';
      } else {
        feedback += 'The form "$correctAnswer" is the correct verb form for this sentence. ';
      }
    } else {
      feedback += '"$correctAnswer" means "$meaning". ';
    }

    feedback += 'This is a $exampleLevel level example.';
    return feedback;
  }

  /// Generate translation (simplified version)
  String _generateTranslation(String bisayaSentence, String wordMeaning) {
    // This is a simplified translation - in a real implementation,
    // you might want to store translations in the database or use a translation service
    return 'Translation: $bisayaSentence (The word "$wordMeaning" is used in this sentence)';
  }

  /// Get practice exercises (batch)
  /// 
  /// [count] - Number of exercises to generate
  /// 
  /// Returns a list of practice exercises with fill-in-the-blank
  Future<List<Map<String, dynamic>>> getPracticeExercises({int count = 10}) async {
    try {
      final flashcards = await getFlashcards(count: count);
      final exercises = <Map<String, dynamic>>[];

      // Generate fill-in-blank for each flashcard
      for (final card in flashcards) {
        try {
          final exercise = await getFillInBlankExercise(
            word: card['word'] as String,
            meaning: card['meaning'] as String,
            partOfSpeech: card['partOfSpeech'] as String? ?? 'Verb',
          ).timeout(
            const Duration(seconds: 10),
          );

          if (exercise.isNotEmpty) {
            exercises.add({
              'word': card['word'],
              'meaning': card['meaning'],
              'pronunciation': card['pronunciation'],
              'fillInBlank': exercise,
            });
          }
        } on TimeoutException {
          debugPrint('⚠️ Timeout generating exercise for ${card['word']}');
          // Continue with next word
        } catch (e) {
          debugPrint('⚠️ Error generating exercise for ${card['word']}: $e');
          // Continue with next word
        }
      }

      return exercises;
    } catch (e) {
      debugPrint('❌ Error getting practice exercises: $e');
      rethrow;
    }
  }
}

