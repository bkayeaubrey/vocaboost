import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/dataset_service.dart';

/// Service for generating six-level progressive learning content
/// Builds progressively complex sentences from a single dataset row
class ProgressiveLearningService {
  static final ProgressiveLearningService _instance =
      ProgressiveLearningService._internal();

  factory ProgressiveLearningService() {
    return _instance;
  }

  ProgressiveLearningService._internal();

  final DatasetService _datasetService = DatasetService.instance;

  void _safeDebug(String msg) {
    try {
      final sanitized = msg.replaceAll('\uFFFD', '');
      debugPrint(sanitized);
    } catch (e) {
      debugPrint('[sanitized debug message]');
    }
  }

  /// Generate complete six-level learning progression from a single dataset row
  /// Returns null if the row doesn't have enough data to create 6 levels
  Map<String, dynamic>? generateSixLevelProgression(
    Map<String, dynamic> datasetRow,
  ) {
    try {
      final bisaya = (datasetRow['bisaya'] as String? ?? '').trim();
      final english = (datasetRow['english'] as String? ?? '').trim();
      final tagalog = (datasetRow['tagalog'] as String? ?? '').trim();
      final pronunciation = (datasetRow['pronunciation'] as String? ?? '').trim();
      final partOfSpeech = (datasetRow['partOfSpeech'] as String? ?? '').trim();
      final category = (datasetRow['category'] as String? ?? '').trim();

      if (bisaya.isEmpty || english.isEmpty) {
        _safeDebug('⚠️ Skipping row: Missing bisaya or english for: $bisaya');
        return null;
      }

        // Get example sentences and translations from dataset
        final beginnerExample = (datasetRow['beginnerExample'] as String? ?? '').trim();
        final beginnerEnglish = (datasetRow['beginnerEnglish'] as String? ?? '').trim();
        final beginnerTagalog = (datasetRow['beginnerTagalog'] as String? ?? '').trim();
        final intermediateExample = (datasetRow['intermediateExample'] as String? ?? '').trim();
        final intermediateEnglish = (datasetRow['intermediateEnglish'] as String? ?? '').trim();
        final intermediateTagalog = (datasetRow['intermediateTagalog'] as String? ?? '').trim();
        final advancedExample = (datasetRow['advancedExample'] as String? ?? '').trim();
        final advancedEnglish = (datasetRow['advancedEnglish'] as String? ?? '').trim();
        final advancedTagalog = (datasetRow['advancedTagalog'] as String? ?? '').trim();

        // Validate per-row: check that each level has complete translations
        if (beginnerExample.isEmpty || beginnerEnglish.isEmpty || beginnerTagalog.isEmpty) {
          _safeDebug('⚠️ Skipping row $bisaya: Missing beginner translations (example=$beginnerExample, en=$beginnerEnglish, tl=$beginnerTagalog)');
          return null;
        }
        if (intermediateExample.isEmpty || intermediateEnglish.isEmpty || intermediateTagalog.isEmpty) {
          _safeDebug('⚠️ Skipping row $bisaya: Missing intermediate translations (example=$intermediateExample, en=$intermediateEnglish, tl=$intermediateTagalog)');
          return null;
        }
        if (advancedExample.isEmpty || advancedEnglish.isEmpty || advancedTagalog.isEmpty) {
          _safeDebug('⚠️ Skipping row $bisaya: Missing advanced translations (example=$advancedExample, en=$advancedEnglish, tl=$advancedTagalog)');
          return null;
        }

      final levels = <Map<String, dynamic>>[];

      // Level 1: Bisaya word
      final level1 = _createLevel(
        1,
        bisaya,
        english,
        tagalog,
        bisaya,
        datasetRow,
        'Foundations',
      );

      if (level1 == null) return null;
      levels.add(level1);

      // Level 2: Beginner Example (Bisaya)
      final level2 = _createLevel(
        2,
        bisaya,
        beginnerEnglish,
        beginnerTagalog,
        beginnerExample,
        datasetRow,
        'Basics',
      );

      if (level2 == null) return null;
      levels.add(level2);

      // Level 3: Beginner Example (Bisaya) - same as Level 2
      final level3 = _createLevel(
        3,
        bisaya,
        beginnerEnglish,
        beginnerTagalog,
        beginnerExample,
        datasetRow,
        'Developing',
      );

      if (level3 == null) return null;
      levels.add(level3);

      // Level 4: Intermediate Example (Bisaya)
      final level4 = _createLevel(
        4,
        bisaya,
        intermediateEnglish,
        intermediateTagalog,
        intermediateExample,
        datasetRow,
        'Skilled',
      );

      if (level4 == null) return null;
      levels.add(level4);

      // Level 5: Intermediate Example (Bisaya) - same as Level 4
      final level5 = _createLevel(
        5,
        bisaya,
        intermediateEnglish,
        intermediateTagalog,
        intermediateExample,
        datasetRow,
        'Advanced',
      );

      if (level5 == null) return null;
      levels.add(level5);

      // Level 6: Advanced Example (Bisaya)
      final level6 = _createLevel(
        6,
        bisaya,
        advancedEnglish,
        advancedTagalog,
        advancedExample,
        datasetRow,
        'Mastery',
      );

      if (level6 == null) return null;
      levels.add(level6);

      // All levels created successfully
      return {
        'word': bisaya,
        'english': english,
        'tagalog': tagalog,
        'pronunciation': pronunciation,
        'partOfSpeech': partOfSpeech,
        'category': category,
        'levels': levels,
        'unlockedLevel': 1, // User starts at level 1
      };
    } catch (e) {
      _safeDebug('❌ Error generating six-level progression: $e');
      return null;
    }
  }

  /// Create a single level with all required fields
  Map<String, dynamic>? _createLevel(
    int levelNumber,
    String bisaya,
    String english,
    String tagalog,
    String sentence,
    Map<String, dynamic> datasetRow,
    String variant,
  ) {
    if (sentence.isEmpty) {
      _safeDebug('⚠️ Level $levelNumber: Empty sentence');
      return null;
    }

    // Prefer the dataset root (bisaya column); fallback to extracted root from sentence
    final datasetRoot = bisaya.trim();
    final extractedWord = _extractRootWordFromSentence(sentence, bisaya).trim();
    final rootWord = datasetRoot.isNotEmpty ? datasetRoot : extractedWord;

    if (rootWord.isEmpty) {
      _safeDebug('⚠️ Level $levelNumber: Could not extract root word from sentence: "$sentence"');
      return null;
    }

    // Use the root word as the correct answer
    final correctAnswer = rootWord;
    
    // Replace the root word with blank in the sentence (case-insensitive); fallback to prepended blank
    String blankSentence;
    final regex = RegExp(RegExp.escape(rootWord), caseSensitive: false);
    if (regex.hasMatch(sentence)) {
      blankSentence = sentence.replaceFirst(regex, '____');
    } else {
      blankSentence = '____ $sentence';
    }

    // Generate 3 choices (correct + 2 distractors)
    final choices =
        _generateThreeChoices(bisaya, correctAnswer, datasetRow);

    if (choices.length < 2) {
      _safeDebug('⚠️ Level $levelNumber: Not enough choices generated');
      return null;
    }

    // Use the English and Tagalog translations passed from the dataset directly
    // (no generation needed—these come from the dataset columns)
    final englishTranslation = english;
    final tagalogTranslation = tagalog;

    return {
      'level': levelNumber,
      'variant': variant,
      'bisayaSentence': sentence,
      'englishTranslation': englishTranslation,
      'tagalogTranslation': tagalogTranslation,
      'fillInBlank': blankSentence,
      'correctAnswer': correctAnswer,
      'choices': choices,
      'isLocked': levelNumber > 1,
      'perfectScoreRequired': true,
    };
  }

  /// Extract root word from sentence by finding the first meaningful word
  /// Attempts to match against the target bisaya word and its variations
  String _extractRootWordFromSentence(String sentence, String bisaya) {
    final bisayaLower = bisaya.toLowerCase().trim();

    // Common Bisaya verb/word prefixes and suffixes to strip
    final prefixes = ['mo', 'mag', 'nag', 'gi', 'ka', 'maka', 'makaka', 'mi', 'kami', 'ta'];
    final suffixes = ['ay', 'a', 'ang', 'nin', 'ing'];

    // Get all words from the sentence
    final words = RegExp(r'\b\w+\b').allMatches(sentence);
    
    for (final match in words) {
      final word = sentence.substring(match.start, match.end);
      final wordLower = word.toLowerCase();

      // Check if this word matches the bisaya word directly
      if (wordLower == bisayaLower) {
        return word;
      }

      // Check if this word contains the bisaya root (with or without affixes)
      if (wordLower.contains(bisayaLower)) {
        return word;
      }

      // Check if the bisaya word contains this word (this word is a root)
      if (bisayaLower.contains(wordLower) && wordLower.length > 2) {
        return word;
      }

      // Try stripping affixes from the word and checking against bisaya
      String stripped = wordLower;
      for (final prefix in prefixes) {
        if (stripped.startsWith(prefix)) {
          stripped = stripped.substring(prefix.length);
          break;
        }
      }
      for (final suffix in suffixes) {
        if (stripped.endsWith(suffix) && stripped.length > 3) {
          stripped = stripped.substring(0, stripped.length - suffix.length);
          break;
        }
      }

      if (stripped == bisayaLower && stripped.length > 2) {
        return word;
      }
    }

    // If no good match, return the first non-trivial word from the sentence
    for (final match in words) {
      final word = sentence.substring(match.start, match.end);
      if (word.length > 2 && !word.toLowerCase().contains('.') && !word.toLowerCase().contains(',')) {
        return word;
      }
    }

    return '';
  }

  /// Find word in sentence and return found form and blank version
  // ignore: unused_element
  Map<String, dynamic>? _findWordInSentence(
    String sentence,
    String targetWord,
  ) {
    final wordLower = targetWord.toLowerCase().trim();
    final sentenceLower = sentence.toLowerCase();

    // Common Bisaya verb forms to check
    final wordForms = [
      targetWord,
      wordLower,
      'mo$wordLower',
      'mag$wordLower',
      'nag$wordLower',
      'gi$wordLower',
      'ka$wordLower',
      'maka$wordLower',
      'makaka$wordLower',
    ];

    String? foundForm;
    int foundIndex = -1;
    int foundLength = 0;

    for (final form in wordForms) {
      if (form.isEmpty) continue;
      final formLower = form.toLowerCase();
      int index = sentenceLower.indexOf(formLower);

      while (index != -1) {
        final before = index > 0 ? sentenceLower[index - 1] : ' ';
        final after = index + form.length < sentenceLower.length
            ? sentenceLower[index + form.length]
            : ' ';

        if (!_isLetter(before) && !_isLetter(after)) {
          foundForm = sentence.substring(index, index + form.length);
          foundIndex = index;
          foundLength = form.length;
          break;
        }
        index = sentenceLower.indexOf(formLower, index + 1);
      }
      if (foundIndex != -1) break;
    }

    if (foundIndex == -1) {
      return null;
    }

    final blankSentence =
        '${sentence.substring(0, foundIndex)}____${sentence.substring(foundIndex + foundLength)}';

    return {
      'foundForm': foundForm,
      'blankSentence': blankSentence,
      'originalSentence': sentence,
    };
  }

  /// Generate exactly 3 choices: 1 correct + 2 distractors
  List<String> _generateThreeChoices(
    String bisaya,
    String correctAnswer,
    Map<String, dynamic> datasetRow,
  ) {
    final choices = <String>[correctAnswer];

    // Get all words from dataset to use as distractors
    final allEntries = _datasetService.getAllEntries();
    final otherWords = allEntries
        .where((e) {
          final entryBisaya = (e['bisaya'] as String? ?? '').trim();
          return entryBisaya.isNotEmpty &&
              entryBisaya.toLowerCase() != bisaya.toLowerCase() &&
              entryBisaya.toLowerCase() != correctAnswer.toLowerCase();
        })
        .map((e) => (e['bisaya'] as String? ?? '').trim())
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList()
      ..shuffle();

    // Add 2 distractors
    for (final word in otherWords) {
      if (choices.length >= 3) break;
      if (!choices.any((c) => c.toLowerCase() == word.toLowerCase())) {
        choices.add(word);
      }
    }

    // If we couldn't find enough distractors, use variations
    if (choices.length < 3) {
      // Try using verb variations as distractors
      final baseWord = _getBaseWord(correctAnswer);
      if (baseWord.isNotEmpty && baseWord != correctAnswer.toLowerCase()) {
        if (!choices.any((c) => c.toLowerCase() == baseWord)) {
          choices.add(baseWord);
        }
      }
    }

    // Shuffle and ensure correct answer is in the list
    choices.shuffle();

    // Verify correct answer is still there
    if (!choices.contains(correctAnswer) &&
        !choices.any((c) => c.toLowerCase() == correctAnswer.toLowerCase())) {
      choices[0] = correctAnswer; // Put it at start then shuffle
    }

    return choices.take(3).toList();
  }

  /// Expand sentence with different complexity levels
  // ignore: unused_element
  String _expandSentence(String sentence, String expansionType) {
    if (sentence.isEmpty) return sentence;

    // Simple expansion strategies - maintain fidelity to dataset
    switch (expansionType) {
      case 'slight':
        // Add a simple adverb
        return '$sentence kaayo.';
      case 'descriptive':
        // Add more descriptive elements
        return 'Ang tanan ay $sentence';
      case 'intermediate':
        // Combine with another simple phrase
        return '$sentence karon.';
      case 'deeper':
        // More complex structure
        return 'Sigurado ko na $sentence';
      case 'advanced':
        // Full complex sentence
        return 'Tungod sa malinong kalaguhan, $sentence';
      default:
        return sentence;
    }
  }

  /// Generate translation for a sentence
  // ignore: unused_element
  String _generateTranslation(
    String sentence,
    String wordTranslation,
    String targetLanguage,
  ) {
    // Simple translation strategy - maintain dataset fidelity
    // Replace the target word with its translation
    final translation = sentence
        .replaceAll(RegExp(r'mo\w+'), wordTranslation)
        .replaceAll(RegExp(r'nag\w+'), wordTranslation)
        .replaceAll(RegExp(r'gi\w+'), wordTranslation);

    if (targetLanguage == 'english') {
      return _englishTranslationTemplate(translation, wordTranslation);
    } else {
      return _tagalogTranslationTemplate(translation, wordTranslation);
    }
  }

  String _englishTranslationTemplate(
      String sentence, String wordTranslation) {
    if (sentence.toLowerCase().contains('gusto')) {
      return 'I want to $wordTranslation';
    } else if (sentence.toLowerCase().contains('kaon')) {
      return 'To $wordTranslation';
    } else {
      return 'To $wordTranslation or related to $wordTranslation';
    }
  }

  String _tagalogTranslationTemplate(
      String sentence, String wordTranslation) {
    if (sentence.toLowerCase().contains('gusto')) {
      return 'Gusto ko ang $wordTranslation';
    } else if (sentence.toLowerCase().contains('kaon')) {
      return 'Kumain ng $wordTranslation';
    } else {
      return 'Tungkol sa $wordTranslation';
    }
  }

  /// Get base word by removing prefixes
  String _getBaseWord(String word) {
    final prefixes = ['mo', 'nag', 'gi', 'mag', 'na', 'ka', 'maka', 'makaka'];
    String base = word.toLowerCase();

    for (final prefix in prefixes) {
      if (base.startsWith(prefix) && base.length > prefix.length) {
        base = base.substring(prefix.length);
        break;
      }
    }

    return base;
  }

  /// Check if character is a letter
  bool _isLetter(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 192 && code <= 255);
  }

  /// Check if a level is unlocked based on previous level performance
  bool isLevelUnlocked(
    Map<String, dynamic> progressionData,
    int levelNumber,
  ) {
    if (levelNumber <= 1) return true;

    final unlockedLevel = progressionData['unlockedLevel'] as int? ?? 1;
    return levelNumber <= unlockedLevel;
  }

  /// Unlock next level after perfect score
  void unlockNextLevel(Map<String, dynamic> progressionData) {
    final currentUnlocked = progressionData['unlockedLevel'] as int? ?? 1;
    if (currentUnlocked < 6) {
      progressionData['unlockedLevel'] = currentUnlocked + 1;
    }
  }
}
