import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/dataset_service.dart';

/// Translation service that uses dataset for translations and examples
class AITranslationService {
  final NLPModelService _nlpService = NLPModelService.instance;
  final DatasetService _datasetService = DatasetService.instance;

  /// Get enhanced translation with dataset examples first, then AI-generated contextual examples
  Future<Map<String, dynamic>> getEnhancedTranslation(String word) async {
    // First, get base data from dataset (primary source)
    Map<String, dynamic>? metadata = _datasetService.getWordMetadata(word);
    
    // Fallback to NLP service if not found in dataset
    metadata ??= _nlpService.getWordMetadata(word);
    
    if (metadata == null) {
      return {
        'word': word,
        'translation': '',
        'pronunciation': '',
        'partOfSpeech': 'Unknown',
        'contextualExamples': {
          'beginner': [],
          'intermediate': [],
          'advanced': [],
        },
        'imageEmoji': '📚',
      };
    }

    final bisaya = metadata['bisaya'] as String? ?? word;
    final english = metadata['english'] as String? ?? '';
    final pronunciation = metadata['pronunciation'] as String? ?? '';
    final partOfSpeech = metadata['partOfSpeech'] as String? ?? 'Verb';

    // Use dataset examples directly (from new model)
    final datasetExamples = _getDatasetExamples(metadata);
    Map<String, List<String>> contextualExamples;
    
    if (datasetExamples.isNotEmpty) {
      debugPrint('✅ Using dataset examples for: $word');
      contextualExamples = datasetExamples;
    } else {
      // Fallback to pattern-based examples
      contextualExamples = _generateFallbackExamples(bisaya, english);
    }

    // Get appropriate image emoji
    final imageEmoji = _getImageEmoji(bisaya, english);

    return {
      'word': bisaya,
      'translation': english,
      'pronunciation': pronunciation,
      'partOfSpeech': partOfSpeech,
      'contextualExamples': contextualExamples,
      'imageEmoji': imageEmoji,
      'originalWord': word,
    };
  }

  /// Extract and format examples from dataset metadata
  Map<String, List<String>> _getDatasetExamples(Map<String, dynamic> metadata) {
    final examples = <String, List<String>>{
      'beginner': [],
      'intermediate': [],
      'advanced': [],
    };

    // Beginner examples
    final beginnerBisaya = metadata['beginnerExample'] as String? ?? '';
    final beginnerEnglish = metadata['beginnerEnglish'] as String? ?? '';
    final beginnerTagalog = metadata['beginnerTagalog'] as String? ?? '';
    
    if (beginnerBisaya.isNotEmpty && beginnerEnglish.isNotEmpty) {
      if (beginnerTagalog.isNotEmpty) {
        examples['beginner']!.add('$beginnerBisaya → "$beginnerEnglish" | "$beginnerTagalog"');
      } else {
        examples['beginner']!.add('$beginnerBisaya → "$beginnerEnglish"');
      }
    }

    // Intermediate examples
    final intermediateBisaya = metadata['intermediateExample'] as String? ?? '';
    final intermediateEnglish = metadata['intermediateEnglish'] as String? ?? '';
    final intermediateTagalog = metadata['intermediateTagalog'] as String? ?? '';
    
    if (intermediateBisaya.isNotEmpty && intermediateEnglish.isNotEmpty) {
      if (intermediateTagalog.isNotEmpty) {
        examples['intermediate']!.add('$intermediateBisaya → "$intermediateEnglish" | "$intermediateTagalog"');
      } else {
        examples['intermediate']!.add('$intermediateBisaya → "$intermediateEnglish"');
      }
    }

    // Advanced examples
    final advancedBisaya = metadata['advancedExample'] as String? ?? '';
    final advancedEnglish = metadata['advancedEnglish'] as String? ?? '';
    final advancedTagalog = metadata['advancedTagalog'] as String? ?? '';
    
    if (advancedBisaya.isNotEmpty && advancedEnglish.isNotEmpty) {
      if (advancedTagalog.isNotEmpty) {
        examples['advanced']!.add('$advancedBisaya → "$advancedEnglish" | "$advancedTagalog"');
      } else {
        examples['advanced']!.add('$advancedBisaya → "$advancedEnglish"');
      }
    }

    // Return examples only if at least one level has examples
    final hasExamples = examples['beginner']!.isNotEmpty || 
                       examples['intermediate']!.isNotEmpty || 
                       examples['advanced']!.isNotEmpty;
    
    return hasExamples ? examples : <String, List<String>>{};
  }


  /// Generate fallback examples from dataset patterns
  Map<String, List<String>> _generateFallbackExamples(
    String bisayaWord,
    String englishTranslation,
  ) {
    final lowerWord = bisayaWord.toLowerCase();
    final lowerMeaning = englishTranslation.toLowerCase();

    List<String> beginner = [];
    List<String> intermediate = [];
    List<String> advanced = [];

    // Pattern-based examples
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
        '$bisayaWord na. → "$englishTranslation now."',
        'Gusto ko $bisayaWord. → "I want $englishTranslation."',
      ];
      intermediate = [
        'Naka$bisayaWord na ba ka? → "Have you $englishTranslation already?"',
        'Mag$bisayaWord ta. → "Let\'s $englishTranslation."',
      ];
      advanced = [
        'Gi$bisayaWord nako ang tanan. → "I $englishTranslation everything."',
        'Kinahanglan nga $bisayaWord ka. → "You need to $englishTranslation."',
      ];
    }

    return {
      'beginner': beginner,
      'intermediate': intermediate,
      'advanced': advanced,
    };
  }

  /// Get appropriate image emoji based on word meaning (public for fast access)
  String getImageEmoji(String bisayaWord, String englishTranslation) {
    return _getImageEmoji(bisayaWord, englishTranslation);
  }

  /// Get appropriate image emoji based on word meaning
  String _getImageEmoji(String bisayaWord, String englishTranslation) {
    final lowerWord = bisayaWord.toLowerCase();
    final lowerMeaning = englishTranslation.toLowerCase();

    // Food related
    if (lowerWord.contains('kaon') || lowerMeaning.contains('eat')) return '🍽️';
    if (lowerWord.contains('tubig') || lowerMeaning.contains('water')) return '💧';
    if (lowerMeaning.contains('food') || lowerMeaning.contains('rice')) return '🍚';
    if (lowerMeaning.contains('bread')) return '🍞';
    if (lowerMeaning.contains('fruit')) return '🍎';
    if (lowerMeaning.contains('meat')) return '🍖';

    // Actions
    if (lowerWord.contains('tulog') || lowerMeaning.contains('sleep')) return '😴';
    if (lowerWord.contains('lakaw') || lowerMeaning.contains('walk')) return '🚶';
    if (lowerMeaning.contains('run') || lowerMeaning.contains('go')) return '🏃';
    if (lowerMeaning.contains('sit')) return '🪑';
    if (lowerMeaning.contains('stand')) return '🧍';
    if (lowerMeaning.contains('dance')) return '💃';

    // Greetings & Social
    if (lowerWord.contains('kumusta') || lowerWord.contains('salamat')) return '👋';
    if (lowerWord.contains('maayong') || lowerMeaning.contains('good')) return '☀️';
    if (lowerMeaning.contains('hello') || lowerMeaning.contains('hi')) return '👋';
    if (lowerMeaning.contains('thank')) return '🙏';

    // Emotions
    if (lowerMeaning.contains('happy') || lowerMeaning.contains('glad')) return '😊';
    if (lowerMeaning.contains('sad') || lowerMeaning.contains('sorry')) return '😢';
    if (lowerMeaning.contains('love') || lowerMeaning.contains('like')) return '❤️';
    if (lowerMeaning.contains('angry')) return '😠';
    if (lowerMeaning.contains('tired')) return '😫';

    // Family
    if (lowerMeaning.contains('mother') || lowerMeaning.contains('mom')) return '👩';
    if (lowerMeaning.contains('father') || lowerMeaning.contains('dad')) return '👨';
    if (lowerMeaning.contains('family')) return '👪';
    if (lowerMeaning.contains('child') || lowerMeaning.contains('baby')) return '👶';
    if (lowerMeaning.contains('brother') || lowerMeaning.contains('sister')) return '👫';

    // Time
    if (lowerMeaning.contains('morning') || lowerMeaning.contains('day')) return '🌅';
    if (lowerMeaning.contains('night') || lowerMeaning.contains('evening')) return '🌙';
    if (lowerMeaning.contains('noon') || lowerMeaning.contains('afternoon')) return '☀️';

    // Body parts
    if (lowerMeaning.contains('hand')) return '✋';
    if (lowerMeaning.contains('head')) return '👤';
    if (lowerMeaning.contains('eye')) return '👁️';
    if (lowerMeaning.contains('mouth')) return '👄';

    // Numbers
    if (RegExp(r'^\d+$').hasMatch(bisayaWord) || lowerMeaning.contains('number')) return '🔢';

    // Default
    return '📚';
  }

  /// Get enhanced pronunciation guide with stress indication
  String getPronunciationGuide(String pronunciation) {
    // Format: "kah-ON" -> emphasize stressed syllable
    final parts = pronunciation.split('-');
    final stressedParts = parts.map((part) {
      if (part == part.toUpperCase() || part.contains(RegExp(r'[A-Z]'))) {
        return part.toUpperCase();
      }
      return part.toLowerCase();
    }).join('-');
    
    return stressedParts;
  }

  /// Get stress syllable from pronunciation
  String getStressedSyllable(String pronunciation) {
    final parts = pronunciation.split('-');
    for (var part in parts) {
      if (part == part.toUpperCase() || part.contains(RegExp(r'[A-Z]'))) {
        return part;
      }
    }
    return 'second syllable';
  }
}

