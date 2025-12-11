import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/progress_service.dart';

/// Service for adaptive flashcard system with contextual learning
class FlashcardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NLPModelService _nlpService = NLPModelService.instance;
  final DatasetService _datasetService = DatasetService.instance;
  final ProgressService _progressService = ProgressService();

  /// Calculate word difficulty for a user (1-5 scale)
  /// Based on: word length, phonetics similarity, affix complexity, user history
  Future<int> calculateWordDifficulty(String word, String? nativeLanguage) async {
    // Try dataset service first, then fallback to NLP service
    Map<String, dynamic>? metadata = _datasetService.getWordMetadata(word) 
        ?? _nlpService.getWordMetadata(word);
    if (metadata == null) return 3; // Default medium difficulty

    int difficulty = 1; // Start with easiest

    // Factor 1: Word length (longer = harder)
    if (word.length > 8) difficulty += 1;
    if (word.length > 12) difficulty += 1;

    // Factor 2: Phonetic complexity for English speakers
    if (nativeLanguage == 'English' || nativeLanguage == null) {
      // Check for difficult sounds for English speakers
      final difficultPatterns = ['ng', 'nga', 'kaon', 'gikaon', 'nag'];
      for (var pattern in difficultPatterns) {
        if (word.toLowerCase().contains(pattern)) {
          difficulty += 1;
          break;
        }
      }
    }

    // Factor 3: Affix complexity
    final affixPatterns = ['nag', 'mag', 'gi', 'ka', 'kinahanglan', 'mahinumduman'];
    int affixCount = 0;
    for (var affix in affixPatterns) {
      if (word.toLowerCase().contains(affix)) {
        affixCount++;
      }
    }
    if (affixCount >= 2) difficulty += 1;
    if (affixCount >= 3) difficulty += 1;

    // Factor 4: User's past performance with this word
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final wordMastery = await _progressService.getWordMastery();
        final wordStats = wordMastery['wordStats'] as Map<String, Map<String, int>>?;
        final stats = wordStats?[word.toLowerCase()];
        
        if (stats != null) {
          final total = stats['total'] ?? 0;
          final correct = stats['correct'] ?? 0;
          
          if (total > 0) {
            final accuracy = (correct / total) * 100;
            // If user struggles with this word, increase difficulty
            if (accuracy < 50 && total >= 2) {
              difficulty += 1;
            }
            // If user masters it, decrease difficulty
            if (accuracy >= 80 && total >= 3) {
              difficulty = difficulty > 1 ? difficulty - 1 : 1;
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors in difficulty calculation
    }

    // Clamp between 1 and 5
    return difficulty.clamp(1, 5);
  }

  /// Get difficulty color (Green/Yellow/Red)
  Color getDifficultyColor(int difficulty) {
    if (difficulty <= 2) return Colors.green;
    if (difficulty <= 3) return Colors.orange;
    return Colors.red;
  }

  /// Generate contextual examples at different difficulty levels using dataset first, then AI
  Future<Map<String, List<String>>> generateContextualExamples(String word) async {
    debugPrint('🔍 Looking for examples for word: "$word"');
    
    // Try dataset service first, then fallback to NLP service
    Map<String, dynamic>? metadata = _datasetService.getWordMetadata(word);
    
    if (metadata == null) {
      debugPrint('⚠️ Word not found in dataset, trying NLP service for: "$word"');
      metadata = _nlpService.getWordMetadata(word);
    }
    
    if (metadata == null) {
      debugPrint('❌ No metadata found for word: "$word"');
      return {
        'beginner': [],
        'intermediate': [],
        'advanced': [],
      };
    }

    final bisaya = metadata['bisaya'] as String? ?? word;
    final english = metadata['english'] as String? ?? '';
    debugPrint('📖 Found metadata for: "$word" -> Bisaya: "$bisaya", English: "$english"');

    // PRIORITY 1: Use dataset examples directly if available (from new model)
    final datasetExamples = _getDatasetExamples(metadata);
    if (datasetExamples.isNotEmpty) {
      debugPrint('✅ Using dataset examples for: $word (${datasetExamples['beginner']!.length} beginner, ${datasetExamples['intermediate']!.length} intermediate, ${datasetExamples['advanced']!.length} advanced)');
      return datasetExamples;
    }

    debugPrint('⚠️ No dataset examples found, using fallback pattern-based examples...');

    // PRIORITY 2: Fallback to pattern-based examples
    debugPrint('⚠️ Using fallback pattern-based examples for: $word');
    return generateFallbackExamples(bisaya, english);
  }

  /// Extract and format examples from dataset metadata
  Map<String, List<String>> _getDatasetExamples(Map<String, dynamic> metadata) {
    final examples = <String, List<String>>{
      'beginner': [],
      'intermediate': [],
      'advanced': [],
    };

    // Beginner examples
    final beginnerBisaya = (metadata['beginnerExample'] as String? ?? '').trim();
    final beginnerEnglish = (metadata['beginnerEnglish'] as String? ?? '').trim();
    final beginnerTagalog = (metadata['beginnerTagalog'] as String? ?? '').trim();
    
    if (beginnerBisaya.isNotEmpty && beginnerEnglish.isNotEmpty) {
      if (beginnerTagalog.isNotEmpty) {
        examples['beginner']!.add('$beginnerBisaya → "$beginnerEnglish" | "$beginnerTagalog"');
      } else {
        examples['beginner']!.add('$beginnerBisaya → "$beginnerEnglish"');
      }
      debugPrint('📝 Found beginner example: $beginnerBisaya → $beginnerEnglish');
    }

    // Intermediate examples
    final intermediateBisaya = (metadata['intermediateExample'] as String? ?? '').trim();
    final intermediateEnglish = (metadata['intermediateEnglish'] as String? ?? '').trim();
    final intermediateTagalog = (metadata['intermediateTagalog'] as String? ?? '').trim();
    
    if (intermediateBisaya.isNotEmpty && intermediateEnglish.isNotEmpty) {
      if (intermediateTagalog.isNotEmpty) {
        examples['intermediate']!.add('$intermediateBisaya → "$intermediateEnglish" | "$intermediateTagalog"');
      } else {
        examples['intermediate']!.add('$intermediateBisaya → "$intermediateEnglish"');
      }
      debugPrint('📝 Found intermediate example: $intermediateBisaya → $intermediateEnglish');
    }

    // Advanced examples
    final advancedBisaya = (metadata['advancedExample'] as String? ?? '').trim();
    final advancedEnglish = (metadata['advancedEnglish'] as String? ?? '').trim();
    final advancedTagalog = (metadata['advancedTagalog'] as String? ?? '').trim();
    
    if (advancedBisaya.isNotEmpty && advancedEnglish.isNotEmpty) {
      if (advancedTagalog.isNotEmpty) {
        examples['advanced']!.add('$advancedBisaya → "$advancedEnglish" | "$advancedTagalog"');
      } else {
        examples['advanced']!.add('$advancedBisaya → "$advancedEnglish"');
      }
      debugPrint('📝 Found advanced example: $advancedBisaya → $advancedEnglish');
    }

    // Return examples only if at least one level has examples
    final hasExamples = examples['beginner']!.isNotEmpty || 
                       examples['intermediate']!.isNotEmpty || 
                       examples['advanced']!.isNotEmpty;
    
    if (!hasExamples) {
      debugPrint('⚠️ No dataset examples found. Metadata keys: ${metadata.keys.join(", ")}');
      debugPrint('   beginnerExample: ${metadata['beginnerExample']}');
      debugPrint('   beginnerEnglish: ${metadata['beginnerEnglish']}');
      debugPrint('   intermediateExample: ${metadata['intermediateExample']}');
      debugPrint('   advancedExample: ${metadata['advancedExample']}');
    }
    
    return hasExamples ? examples : <String, List<String>>{};
  }

  /// Fallback examples when AI is unavailable (public for fast access)
  Map<String, List<String>> generateFallbackExamples(String bisayaWord, String englishWord) {
    final lowerWord = bisayaWord.toLowerCase();
    final lowerMeaning = englishWord.toLowerCase();

    List<String> beginner = [];
    List<String> intermediate = [];
    List<String> advanced = [];

    if (lowerWord.contains('kaon') || lowerMeaning.contains('eat')) {
      beginner = [
        'Kaon na. → "Let\'s eat now."',
        'Gusto ko mokaon. → "I want to eat."',
      ];
      intermediate = [
        'Nakaon na ba ka? → "Have you eaten already?"',
        'Magkaon ta sa balay. → "Let\'s eat at home."',
      ];
      advanced = [
        'Gikaon nako ang tinapay ganina. → "I ate the bread earlier."',
        'Kinahanglan nga mokaon ka aron kusgan. → "You need to eat to be strong."',
      ];
    } else if (lowerWord.contains('tulog') || lowerMeaning.contains('sleep')) {
      beginner = [
        'Tulog na. → "Sleep now."',
        'Gusto ko matulog. → "I want to sleep."',
      ];
      intermediate = [
        'Natulog na ba ka? → "Have you slept already?"',
        'Magtulog ta sa kwarto. → "Let\'s sleep in the room."',
      ];
      advanced = [
        'Gitulog nako ang tanan nga problema. → "I slept through all the problems."',
        'Kinahanglan nga matulog ka aron makapahuway. → "You need to sleep to rest."',
      ];
    } else {
      // Generic patterns
      beginner = [
        '$bisayaWord na. → "$englishWord now."',
        'Gusto ko $bisayaWord. → "I want $englishWord."',
      ];
      intermediate = [
        'Naka$bisayaWord na ba ka? → "Have you $englishWord already?"',
        'Mag$bisayaWord ta. → "Let\'s $englishWord."',
      ];
      advanced = [
        'Gi$bisayaWord nako ang tanan. → "I $englishWord everything."',
        'Kinahanglan nga $bisayaWord ka. → "You need to $englishWord."',
      ];
    }

    return {
      'beginner': beginner,
      'intermediate': intermediate,
      'advanced': advanced,
    };
  }

  /// Generate fill-in-the-blank exercise using dataset + AI
  Future<Map<String, dynamic>?> generateFillInTheBlank(String word) async {
    // Ensure dataset is loaded
    if (!_datasetService.isLoaded) {
      try {
        await _datasetService.loadDataset();
      } catch (e) {
        debugPrint('⚠️ Dataset not loaded, will try NLP service: $e');
      }
    }
    
    // Try dataset service first, then fallback to NLP service
    Map<String, dynamic>? metadata = _datasetService.getWordMetadata(word) 
        ?? _nlpService.getWordMetadata(word);
    
    // If still no metadata, try to create basic metadata from dummy data
    if (metadata == null) {
      debugPrint('⚠️ No metadata found for word: $word, creating basic metadata');
      // Try to extract basic info from common dummy words
      metadata = _createBasicMetadataForWord(word);
      if (metadata == null) {
        return null;
      }
    }
    
    debugPrint('✅ Generating fill-in-the-blank for: $word');

    final bisaya = metadata['bisaya'] as String? ?? word;
    final english = metadata['english'] as String? ?? '';
    final partOfSpeech = (metadata['partOfSpeech'] as String? ?? 'Verb').toLowerCase();
    final category = metadata['category'] as String? ?? '';

    // Generate locally using dataset data

    // Generate sentence template based on part of speech
    String sentence;
    String correctAnswer;
    List<String> options;
    String feedback;
    String translation;

    if (partOfSpeech.contains('verb')) {
      // For verbs: Generate diverse sentence patterns
      final baseWord = _getBaseForm(bisaya);
      final infinitiveForm = _getInfinitiveForm(baseWord);
      final pastForm = _getPastForm(baseWord);
      final presentForm = 'nag$baseWord';
      
      // Diverse sentence templates for verbs
      final verbTemplates = [
        'Gusto ko mo_____ ug {object}.', // I want to [verb] [object]
        'Asa ka mo_____?', // Where will you [verb]?
        'Nakaon na ba ka ug _____?', // Have you eaten [object]?
        'Mopalit ko ug _____ karon.', // I will buy [object] now
        'Nag_____ ko ganina.', // I [verb]ed earlier
        'Gikaon nako ang _____.', // I ate the [object]
        'Kanus-a ka mo_____?', // When will you [verb]?
        'Siya kay nag_____ karon.', // He/She is [verb]ing now
        'Dili ko mokaon ug _____.', // I don't eat [object]
        'Mobasa ko ug _____ unya.', // I will read [object] later
        'Naa koy gusto mo_____.', // I want to [verb]
        'Wala ko mo_____ ganina.', // I didn't [verb] earlier
      ];
      
      final object = _getAppropriateObject(english.toLowerCase());
      final random = DateTime.now().millisecondsSinceEpoch % verbTemplates.length;
      sentence = verbTemplates[random].replaceAll('{object}', object).replaceAll('_____', '_____');
      
      // Determine correct answer based on sentence pattern
      if (sentence.contains('mo_____') || sentence.contains('mokaon') || sentence.contains('mopalit') || sentence.contains('mobasa')) {
        correctAnswer = infinitiveForm;
      } else if (sentence.contains('nag_____') || sentence.contains('Nag_____')) {
        correctAnswer = presentForm;
      } else if (sentence.contains('Gikaon') || sentence.contains('gikaon')) {
        correctAnswer = pastForm;
      } else {
        correctAnswer = infinitiveForm;
      }
      
      // Get wrong options from dataset (similar verbs)
      final allEntries = _datasetService.getAllEntries();
      final verbEntries = allEntries.where((e) {
        final pos = (e['partOfSpeech'] as String? ?? '').toLowerCase();
        return pos.contains('verb') && e['bisaya'] != bisaya;
      }).toList()..shuffle();
      
      // Create diverse options based on sentence pattern
      options = [correctAnswer];
      
      // Add other verb forms as wrong options
      if (correctAnswer != infinitiveForm) options.add(infinitiveForm);
      if (correctAnswer != pastForm) options.add(pastForm);
      if (correctAnswer != presentForm) options.add(presentForm);
      if (correctAnswer != baseWord) options.add(baseWord);
      
      // Add 1-2 wrong verbs from dataset
      for (final verbEntry in verbEntries.take(2)) {
        final wrongVerb = verbEntry['bisaya'] as String? ?? '';
        if (wrongVerb.isNotEmpty && wrongVerb != bisaya && !options.contains(wrongVerb)) {
          options.add(wrongVerb);
          break;
        }
      }
      
      // Ensure we have at least 3 options
      while (options.length < 3) {
        final wrongForm = baseWord.endsWith('on') ? baseWord.replaceAll('on', 'an') : '${baseWord}na';
        if (!options.contains(wrongForm)) {
          options.add(wrongForm);
        } else {
          break;
        }
      }
      options = options.take(4).toList()..shuffle();
      
      // Generate appropriate feedback and translation based on sentence
      if (sentence.contains('Gusto ko') || sentence.contains('Naa koy gusto')) {
        feedback = 'Great! \'$correctAnswer\' is used when expressing desire or future actions.';
        translation = _generateTranslation(sentence, english, object);
      } else if (sentence.contains('Asa ka') || sentence.contains('Kanus-a')) {
        feedback = 'Correct! \'$correctAnswer\' is the appropriate form for questions about actions.';
        translation = _generateTranslation(sentence, english, object);
      } else if (sentence.contains('Nag_____') || sentence.contains('nag_____')) {
        feedback = 'Well done! \'$correctAnswer\' indicates an ongoing or recent action.';
        translation = _generateTranslation(sentence, english, object);
      } else if (sentence.contains('Gikaon') || sentence.contains('gikaon')) {
        feedback = 'Excellent! \'$correctAnswer\' is the past tense form.';
        translation = _generateTranslation(sentence, english, object);
      } else {
        feedback = 'Great! \'$correctAnswer\' is the correct form for this sentence.';
        translation = _generateTranslation(sentence, english, object);
      }
      
    } else if (partOfSpeech.contains('noun')) {
      // For nouns: Diverse sentence patterns
      final sentenceTemplates = [
        'Gusto ko ug _____.', // I want [noun]
        'Naa koy _____.', // I have [noun]
        'Asa ang _____?', // Where is the [noun]?
        'Kining _____ kay nindot.', // This [noun] is beautiful
        'Wala koy _____.', // I don't have [noun]
        'Pila ang _____?', // How much is the [noun]?
        'Unsa ang _____?', // What is the [noun]?
        'Ang _____ kay dako.', // The [noun] is big
        'Nindot ang _____.', // The [noun] is beautiful
        'Gipalit nako ang _____.', // I bought the [noun]
        'Gihigugma ko ang _____.', // I love the [noun]
        'Kining _____ kay akoa.', // This [noun] is mine
        'Naa sa _____ ang libro.', // The book is in the [noun]
        'Gikan sa _____ ko.', // I'm from [noun]
      ];
      final random = DateTime.now().millisecondsSinceEpoch % sentenceTemplates.length;
      sentence = sentenceTemplates[random].replaceAll('_____', '_____');
      correctAnswer = bisaya;
      
      // Get wrong options from dataset (other nouns)
      final allEntries = _datasetService.getAllEntries();
      final nounEntries = allEntries.where((e) {
        final pos = (e['partOfSpeech'] as String? ?? '').toLowerCase();
        return pos.contains('noun') && e['bisaya'] != bisaya;
      }).toList()..shuffle();
      
      options = [correctAnswer];
      for (final nounEntry in nounEntries.take(3)) {
        final wrongNoun = nounEntry['bisaya'] as String? ?? '';
        if (wrongNoun.isNotEmpty && !options.contains(wrongNoun)) {
          options.add(wrongNoun);
        }
      }
      
      // Ensure we have at least 3 options
      while (options.length < 3) {
        final similarWord = '${bisaya}na';
        if (!options.contains(similarWord)) {
          options.add(similarWord);
        } else {
          break;
        }
      }
      options = options.take(4).toList()..shuffle();
      
      // Generate appropriate feedback and translation
      feedback = 'Correct! \'$bisaya\' means \'$english\'.';
      translation = _generateTranslation(sentence, english, '');
      
    } else {
      // For adjectives/adverbs: Diverse descriptive sentences
      final sentenceTemplates = [
        'Ang saging kay _____.', // The banana is [adjective]
        'Kining tawo kay _____.', // This person is [adjective]
        'Ang balay kay _____.', // The house is [adjective]
        'Siya kay _____ kaayo.', // He/She is very [adjective]
        'Nindot kaayo ang _____.', // The [noun] is very beautiful
        'Dako ang _____.', // The [noun] is big
        'Gamay ang _____.', // The [noun] is small
        'Maayo ang _____.', // The [noun] is good
        'Kining _____ kay init.', // This [noun] is hot
        'Bugnaw ang _____.', // The [noun] is cold
        'Gwapa kaayo si _____.', // [Name] is very beautiful
        'Taas ang _____.', // The [noun] is tall
        'Hinlo ang _____.', // The [noun] is clean
        'Hugaw ang _____.', // The [noun] is dirty
      ];
      final random = DateTime.now().millisecondsSinceEpoch % sentenceTemplates.length;
      sentence = sentenceTemplates[random].replaceAll('_____', '_____');
      correctAnswer = bisaya;
      
      // Get wrong options from dataset (other adjectives/adverbs)
      final allEntries = _datasetService.getAllEntries();
      final adjEntries = allEntries.where((e) {
        final pos = (e['partOfSpeech'] as String? ?? '').toLowerCase();
        return (pos.contains('adjective') || pos.contains('adverb')) && e['bisaya'] != bisaya;
      }).toList()..shuffle();
      
      options = [correctAnswer];
      for (final adjEntry in adjEntries.take(3)) {
        final wrongAdj = adjEntry['bisaya'] as String? ?? '';
        if (wrongAdj.isNotEmpty && !options.contains(wrongAdj)) {
          options.add(wrongAdj);
        }
      }
      
      // Ensure we have at least 3 options
      while (options.length < 3) {
        final similarWord = '${bisaya}na';
        if (!options.contains(similarWord)) {
          options.add(similarWord);
        } else {
          break;
        }
      }
      options = options.take(4).toList()..shuffle();
      
      // Generate appropriate feedback and translation
      feedback = category.isNotEmpty 
          ? 'Well done! \'$bisaya\' means \'$english\' (category: $category).'
          : 'Well done! \'$bisaya\' means \'$english\'.';
      translation = _generateTranslation(sentence, english, '');
    }

    return {
      'sentence': sentence,
      'correctAnswer': correctAnswer,
      'options': options,
      'feedback': feedback,
      'translation': translation,
    };
  }

  /// Get base form of verb (remove prefixes)
  String _getBaseForm(String word) {
    // Common Bisaya verb prefixes to remove
    final prefixes = ['mo', 'nag', 'gi', 'mag', 'na', 'ka'];
    String base = word.toLowerCase();
    
    for (final prefix in prefixes) {
      if (base.startsWith(prefix)) {
        base = base.substring(prefix.length);
        break;
      }
    }
    
    return base.isEmpty ? word.toLowerCase() : base;
  }

  /// Get infinitive form (mo- prefix)
  String _getInfinitiveForm(String baseWord) {
    if (baseWord.startsWith('mo')) return baseWord;
    return 'mo$baseWord';
  }

  /// Get past form (gi- prefix)
  String _getPastForm(String baseWord) {
    if (baseWord.startsWith('gi')) return baseWord;
    return 'gi$baseWord';
  }

  /// Generate translation for a sentence
  String _generateTranslation(String sentence, String meaning, String object) {
    if (sentence.contains('Gusto ko')) {
      return object.isNotEmpty ? 'I want to $meaning $object.' : 'I want $meaning.';
    } else if (sentence.contains('Naa koy')) {
      return 'I have $meaning.';
    } else if (sentence.contains('Wala koy')) {
      return 'I don\'t have $meaning.';
    } else if (sentence.contains('Asa ang') || sentence.contains('Asa ka')) {
      return 'Where is the $meaning?';
    } else if (sentence.contains('Pila ang')) {
      return 'How much is the $meaning?';
    } else if (sentence.contains('Unsa ang')) {
      return 'What is the $meaning?';
    } else if (sentence.contains('Kanus-a')) {
      return 'When will you $meaning?';
    } else if (sentence.contains('Nag_____') || sentence.contains('nag_____')) {
      return object.isNotEmpty ? 'I $meaning $object earlier.' : 'I $meaning earlier.';
    } else if (sentence.contains('Gikaon') || sentence.contains('gikaon') || sentence.contains('Gipalit')) {
      return object.isNotEmpty ? 'I $meaning the $object.' : 'I $meaning it.';
    } else if (sentence.contains('kay nindot') || sentence.contains('kay dako') || sentence.contains('kay gamay')) {
      return 'The $meaning is beautiful/big/small.';
    } else if (sentence.contains('kaayo')) {
      return 'He/She is very $meaning.';
    } else if (sentence.contains('Ang ') && sentence.contains(' kay')) {
      return 'The $meaning is [adjective].';
    } else {
      return 'Translation: $sentence';
    }
  }

  /// Create basic metadata for a word (used for dummy flashcards)
  Map<String, dynamic>? _createBasicMetadataForWord(String word) {
    // Map of dummy words to their metadata
    final dummyWordsMap = {
      'Kaon': {'bisaya': 'Kaon', 'english': 'To eat', 'partOfSpeech': 'Verb', 'pronunciation': 'kah-ON'},
      'Tubig': {'bisaya': 'Tubig', 'english': 'Water', 'partOfSpeech': 'Noun', 'pronunciation': 'TOO-big'},
      'Maayo': {'bisaya': 'Maayo', 'english': 'Good', 'partOfSpeech': 'Adjective', 'pronunciation': 'mah-AH-yo'},
      'Amahan': {'bisaya': 'Amahan', 'english': 'Father', 'partOfSpeech': 'Noun', 'pronunciation': 'ah-MAH-han'},
      'Mopalit': {'bisaya': 'Mopalit', 'english': 'To buy', 'partOfSpeech': 'Verb', 'pronunciation': 'moh-pah-LEET'},
      'Gwapa': {'bisaya': 'Gwapa', 'english': 'Beautiful', 'partOfSpeech': 'Adjective', 'pronunciation': 'GWAH-pah'},
      'Balay': {'bisaya': 'Balay', 'english': 'House', 'partOfSpeech': 'Noun', 'pronunciation': 'BAH-lay'},
      'Mokaon': {'bisaya': 'Mokaon', 'english': 'Will eat', 'partOfSpeech': 'Verb', 'pronunciation': 'moh-kah-ON'},
      'Lima': {'bisaya': 'Lima', 'english': 'Five', 'partOfSpeech': 'Number', 'pronunciation': 'LEE-mah'},
      'Gutom': {'bisaya': 'Gutom', 'english': 'Hungry', 'partOfSpeech': 'Adjective', 'pronunciation': 'GOO-tom'},
      'Salamat': {'bisaya': 'Salamat', 'english': 'Thank you', 'partOfSpeech': 'Expression', 'pronunciation': 'sah-LAH-maht'},
      'Kumusta': {'bisaya': 'Kumusta', 'english': 'Hello', 'partOfSpeech': 'Expression', 'pronunciation': 'koo-MOOS-tah'},
      'Inahan': {'bisaya': 'Inahan', 'english': 'Mother', 'partOfSpeech': 'Noun', 'pronunciation': 'ee-NAH-han'},
      'Libro': {'bisaya': 'Libro', 'english': 'Book', 'partOfSpeech': 'Noun', 'pronunciation': 'LEE-broh'},
      'Mobasa': {'bisaya': 'Mobasa', 'english': 'To read', 'partOfSpeech': 'Verb', 'pronunciation': 'moh-BAH-sah'},
    };
    
    final wordLower = word.toLowerCase();
    for (final entry in dummyWordsMap.entries) {
      if (entry.key.toLowerCase() == wordLower) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Generate dummy flashcards for testing/demo purposes
  List<Map<String, dynamic>> generateDummyFlashcards({int count = 10}) {
    final dummyData = [
      {
        'word': 'Kaon',
        'pronunciation': 'kah-ON',
        'meaning': 'To eat',
        'partOfSpeech': 'Verb',
        'difficulty': 2,
        'imageEmoji': '🍽️',
      },
      {
        'word': 'Tubig',
        'pronunciation': 'TOO-big',
        'meaning': 'Water',
        'partOfSpeech': 'Noun',
        'difficulty': 1,
        'imageEmoji': '💧',
      },
      {
        'word': 'Maayo',
        'pronunciation': 'mah-AH-yo',
        'meaning': 'Good',
        'partOfSpeech': 'Adjective',
        'difficulty': 1,
        'imageEmoji': '👍',
      },
      {
        'word': 'Amahan',
        'pronunciation': 'ah-MAH-han',
        'meaning': 'Father',
        'partOfSpeech': 'Noun',
        'difficulty': 2,
        'imageEmoji': '👨',
      },
      {
        'word': 'Mopalit',
        'pronunciation': 'moh-pah-LEET',
        'meaning': 'To buy',
        'partOfSpeech': 'Verb',
        'difficulty': 3,
        'imageEmoji': '🛒',
      },
      {
        'word': 'Gwapa',
        'pronunciation': 'GWAH-pah',
        'meaning': 'Beautiful',
        'partOfSpeech': 'Adjective',
        'difficulty': 1,
        'imageEmoji': '✨',
      },
      {
        'word': 'Balay',
        'pronunciation': 'BAH-lay',
        'meaning': 'House',
        'partOfSpeech': 'Noun',
        'difficulty': 1,
        'imageEmoji': '🏠',
      },
      {
        'word': 'Mokaon',
        'pronunciation': 'moh-kah-ON',
        'meaning': 'Will eat / To eat (infinitive)',
        'partOfSpeech': 'Verb',
        'difficulty': 3,
        'imageEmoji': '🍴',
      },
      {
        'word': 'Lima',
        'pronunciation': 'LEE-mah',
        'meaning': 'Five',
        'partOfSpeech': 'Number',
        'difficulty': 1,
        'imageEmoji': '5️⃣',
      },
      {
        'word': 'Gutom',
        'pronunciation': 'GOO-tom',
        'meaning': 'Hungry',
        'partOfSpeech': 'Adjective',
        'difficulty': 2,
        'imageEmoji': '🍔',
      },
      {
        'word': 'Salamat',
        'pronunciation': 'sah-LAH-maht',
        'meaning': 'Thank you',
        'partOfSpeech': 'Expression',
        'difficulty': 1,
        'imageEmoji': '🙏',
      },
      {
        'word': 'Kumusta',
        'pronunciation': 'koo-MOOS-tah',
        'meaning': 'Hello / How are you',
        'partOfSpeech': 'Expression',
        'difficulty': 2,
        'imageEmoji': '👋',
      },
      {
        'word': 'Inahan',
        'pronunciation': 'ee-NAH-han',
        'meaning': 'Mother',
        'partOfSpeech': 'Noun',
        'difficulty': 2,
        'imageEmoji': '👩',
      },
      {
        'word': 'Libro',
        'pronunciation': 'LEE-broh',
        'meaning': 'Book',
        'partOfSpeech': 'Noun',
        'difficulty': 1,
        'imageEmoji': '📚',
      },
      {
        'word': 'Mobasa',
        'pronunciation': 'moh-BAH-sah',
        'meaning': 'To read',
        'partOfSpeech': 'Verb',
        'difficulty': 3,
        'imageEmoji': '📖',
      },
    ];

    // Return requested count, cycling through dummy data if needed
    final flashcards = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final data = dummyData[i % dummyData.length];
      flashcards.add({
        'word': data['word'] as String,
        'pronunciation': data['pronunciation'] as String,
        'meaning': data['meaning'] as String,
        'partOfSpeech': data['partOfSpeech'] as String,
        'difficulty': data['difficulty'] as int,
        'originalWord': data['word'] as String,
        'imageEmoji': data['imageEmoji'] as String,
      });
    }

    return flashcards;
  }

  /// Get appropriate object for verb sentence
  String _getAppropriateObject(String englishVerb) {
    // Map common verbs to appropriate objects
    final verbObjectMap = {
      'eat': 'saging',
      'drink': 'tubig',
      'buy': 'tinapay',
      'read': 'libro',
      'write': 'sulat',
      'see': 'pelikula',
      'hear': 'musika',
      'play': 'dula',
      'sing': 'kanta',
      'dance': 'sayaw',
      'cook': 'pagkaon',
      'wash': 'sinina',
      'clean': 'balay',
      'open': 'pultahan',
      'close': 'bintana',
      'give': 'regalo',
      'take': 'gamit',
      'bring': 'bag',
      'send': 'mensahe',
    };

    // Check if verb contains any of the mapped words
    for (final entry in verbObjectMap.entries) {
      if (englishVerb.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default objects
    return 'butang'; // "thing" in Bisaya
  }

  /// Get user's learning streak
  Future<Map<String, dynamic>> getLearningStreak() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'lastActivityDate': null,
      };
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final currentStreak = (data?['currentStreak'] as num?)?.toInt() ?? 0;
      final longestStreak = (data?['longestStreak'] as num?)?.toInt() ?? 0;
      final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
      final lastActivityDate = lastActivityTimestamp?.toDate();

      return {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': lastActivityDate,
      };
    } catch (e) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'lastActivityDate': null,
      };
    }
  }

  /// Update learning streak
  /// [useFreeze] - Whether to use a streak freeze if available
  Future<Map<String, dynamic>> updateLearningStreak({bool useFreeze = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'streakMaintained': false,
        'streakFrozen': false,
        'milestoneReached': null,
      };
    }

    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
      final lastActivityDate = lastActivityTimestamp?.toDate();
      final currentStreak = (data?['currentStreak'] as num?)?.toInt() ?? 0;
      final longestStreak = (data?['longestStreak'] as num?)?.toInt() ?? 0;
      final streakFreezes = (data?['streakFreezes'] as num?)?.toInt() ?? 0;

      int newStreak = currentStreak;
      bool streakMaintained = true;
      bool streakFrozen = false;
      String? milestoneReached;

      if (lastActivityDate == null) {
        // First time
        newStreak = 1;
      } else {
        final lastActivityStart = DateTime(
          lastActivityDate.year,
          lastActivityDate.month,
          lastActivityDate.day,
        );
        final daysDifference = todayStart.difference(lastActivityStart).inDays;

        if (daysDifference == 0) {
          // Same day, keep streak
          newStreak = currentStreak;
        } else if (daysDifference == 1) {
          // Consecutive day, increment streak
          newStreak = currentStreak + 1;
        } else if (daysDifference == 2 && useFreeze && streakFreezes > 0) {
          // Streak freeze: missed one day, use freeze to maintain
          newStreak = currentStreak;
          streakFrozen = true;
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'streakFreezes': streakFreezes - 1,
          });
        } else {
          // Streak broken, reset to 1
          newStreak = 1;
          streakMaintained = false;
        }
      }

      // Check for milestones
      final milestones = [7, 14, 30, 60, 100, 200, 365];
      for (final milestone in milestones) {
        if (currentStreak < milestone && newStreak >= milestone) {
          milestoneReached = milestone.toString();
          break;
        }
      }

      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'lastActivityDate': Timestamp.now(),
      });

      return {
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'streakMaintained': streakMaintained,
        'streakFrozen': streakFrozen,
        'milestoneReached': milestoneReached,
      };
    } catch (e) {
      debugPrint('Error updating learning streak: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'streakMaintained': false,
        'streakFrozen': false,
        'milestoneReached': null,
      };
    }
  }

  /// Get streak freeze count
  Future<int> getStreakFreezes() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      return (data?['streakFreezes'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting streak freezes: $e');
      return 0;
    }
  }

  /// Add streak freeze (earned through achievements or purchases)
  Future<void> addStreakFreeze({int amount = 1}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final currentFreezes = await getStreakFreezes();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'streakFreezes': currentFreezes + amount,
      });
    } catch (e) {
      debugPrint('Error adding streak freeze: $e');
    }
  }

  /// Recover streak (for users who lost streak but want to restore it)
  /// Requires streak recovery item or special achievement
  Future<bool> recoverStreak() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final currentStreak = (data?['currentStreak'] as num?)?.toInt() ?? 0;
      final longestStreak = (data?['longestStreak'] as num?)?.toInt() ?? 0;
      final streakRecoveries = (data?['streakRecoveries'] as num?)?.toInt() ?? 0;

      // Can only recover if streak was recently lost (within 7 days) and has recovery item
      if (currentStreak == 0 && longestStreak > 0 && streakRecoveries > 0) {
        final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
        if (lastActivityTimestamp != null) {
          final daysSince = DateTime.now().difference(lastActivityTimestamp.toDate()).inDays;
          if (daysSince <= 7) {
            // Restore to previous longest streak
            await _firestore
                .collection('users')
                .doc(user.uid)
                .update({
              'currentStreak': longestStreak,
              'streakRecoveries': streakRecoveries - 1,
              'lastActivityDate': Timestamp.now(),
            });
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error recovering streak: $e');
      return false;
    }
  }

  /// Get category breakdown for progress
  Future<Map<String, Map<String, dynamic>>> getCategoryBreakdown() async {
    // This would typically come from word metadata or user progress
    // For now, return sample data structure
    return {
      'Greetings': {'progress': 100, 'total': 20, 'learned': 20},
      'Food & Dining': {'progress': 75, 'total': 40, 'learned': 30},
      'Family': {'progress': 60, 'total': 30, 'learned': 18},
      'Numbers': {'progress': 45, 'total': 40, 'learned': 18},
      'Market/Shopping': {'progress': 25, 'total': 40, 'learned': 10},
    };
  }
}

