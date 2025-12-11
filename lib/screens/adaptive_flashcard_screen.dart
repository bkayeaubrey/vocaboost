import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/flashcard_service.dart';
import 'package:vocaboost/services/learning_accuracy_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Adaptive Flashcard System with Contextual Learning
class AdaptiveFlashcardScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const AdaptiveFlashcardScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<AdaptiveFlashcardScreen> createState() => _AdaptiveFlashcardScreenState();
}

class _AdaptiveFlashcardScreenState extends State<AdaptiveFlashcardScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final NLPModelService _nlpService = NLPModelService.instance;
  final DatasetService _datasetService = DatasetService.instance;
  final FlashcardService _flashcardService = FlashcardService();
  final LearningAccuracyService _accuracyService = LearningAccuracyService();
  DateTime? _cardStartTime;

  // State variables
  int _currentCardIndex = 0;
  bool _isCardFlipped = false;
  bool _isLoading = true;
  bool _modelLoaded = false;
  List<Map<String, dynamic>> _flashcards = [];
  final Map<String, int> _wordDifficulties = {}; // word -> difficulty (1-5)
  final Map<String, Map<String, List<String>>> _contextualExamples = {};

  // Voice recognition
  late stt.SpeechToText _speech;
  Timer? _silenceTimer;

  // TTS - Using same setup as AI Assistant (voice_translation_screen.dart)
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;

  // Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Progress tracking (removed - analytics moved to Progress Screen)


  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeTts();
    _initializeAnimation();
    _loadModelAndGenerateFlashcards();
  }

  void _initializeAnimation() {
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  Future<void> _initializeTts() async {
    // Use the same TTS setup as AI Assistant (voice_translation_screen.dart)
    try {
      _flutterTts = FlutterTts();
      
      // Try to set Bisaya/Filipino language with fallbacks (same as AI Assistant)
      List<String> languageCodes = ['fil-PH', 'tl-PH', 'fil', 'tl', 'ceb-PH', 'ceb'];
      String? selectedLanguage;
      
      // Get available languages
      List<dynamic> languages = await _flutterTts.getLanguages;
      
      // Try to find Bisaya/Filipino language
      for (String code in languageCodes) {
        if (languages.contains(code)) {
          selectedLanguage = code;
          break;
        }
      }
      
      // If no Filipino/Bisaya found, try to find any Philippine language
      if (selectedLanguage == null) {
        for (dynamic lang in languages) {
          String langStr = lang.toString().toLowerCase();
          if (langStr.contains('ph') || langStr.contains('filipino') || 
              langStr.contains('tagalog') || langStr.contains('bisaya') ||
              langStr.contains('cebuano')) {
            selectedLanguage = lang.toString();
            break;
          }
        }
      }
      
      // Set language (use selected or default to en-US)
      await _flutterTts.setLanguage(selectedLanguage ?? 'en-US');
      if (selectedLanguage != null) {
        debugPrint('✅ TTS language set to: $selectedLanguage (Native Bisaya speaker)');
      } else {
        debugPrint('⚠️ Using default English TTS (Bisaya not available on this device)');
      }
      
      // Use same settings as AI Assistant
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      // Fallback to English if initialization fails
      try {
        await _flutterTts.setLanguage('en-US');
        _isTtsInitialized = true;
      } catch (e2) {
        _isTtsInitialized = false;
      }
    }
  }

  Future<void> _speakWord(String text) async {
    // Use the same TTS method as AI Assistant (simpler, no Cloud TTS)
    if (!_isTtsInitialized) {
      await _initializeTts();
    }
    
    try {
      await _flutterTts.speak(text);
      debugPrint('✅ Played word using AI Assistant TTS: $text');
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _loadModelAndGenerateFlashcards() async {
    try {
      setState(() => _isLoading = true);

      // Load local data FIRST for immediate display
      debugPrint('🔄 Loading flashcards from local data (fast)...');
      
      // Load dataset first (primary source) - should be fast if pre-loaded
      try {
        if (!_datasetService.isLoaded) {
          await _datasetService.loadDataset().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('⚠️ Dataset loading timeout');
            },
          );
        }
        debugPrint('✅ Dataset ready');
      } catch (e) {
        debugPrint('⚠️ Dataset loading failed: $e');
      }

      // Load NLP model in background (non-blocking)
      if (!_nlpService.isLoaded) {
        _nlpService.loadModel().catchError((e) {
          debugPrint('Warning: NLP model not loaded: $e');
        });
      }
      
      setState(() => _modelLoaded = true);

      // Generate flashcards immediately from local data
      await _generateFlashcards();
    } catch (e) {
      debugPrint('Error loading: $e');
      // Even if loading fails, try to generate dummy flashcards
      setState(() => _modelLoaded = true);
      await _generateFlashcards();
    }
  }

  Future<void> _generateFlashcards() async {
    try {
      final flashcards = <Map<String, dynamic>>[];
      
      // Ensure dataset is loaded
      if (!_datasetService.isLoaded) {
        debugPrint('🔄 Dataset not loaded, loading now...');
        try {
          await _datasetService.loadDataset().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ Dataset loading timeout');
            },
          );
        } catch (e) {
          debugPrint('⚠️ Failed to load dataset: $e');
        }
      }
      
      // Get random words from dataset (primary source) - reduced count for faster loading
      List<String> allWords = [];
      try {
        if (_datasetService.isLoaded) {
          allWords = _datasetService.getRandomWords(count: 10); // Reduced from 20 to 10 for faster loading
          debugPrint('📚 Got ${allWords.length} words from dataset');
          
          // If still empty, try getting all entries
          if (allWords.isEmpty) {
            final allEntries = _datasetService.getAllEntries();
            debugPrint('📚 Dataset has ${allEntries.length} total entries');
            if (allEntries.isNotEmpty) {
              // Get Bisaya words from all entries
              for (final entry in allEntries.take(20)) {
                final bisaya = entry['bisaya'] as String? ?? '';
                if (bisaya.isNotEmpty) {
                  allWords.add(bisaya);
                }
              }
              debugPrint('📚 Extracted ${allWords.length} words from entries');
            }
          }
        } else {
          debugPrint('⚠️ Dataset service is not loaded');
        }
      } catch (e) {
        debugPrint('⚠️ Error getting words from dataset: $e');
      }
      
      // Fallback to NLP service if dataset is empty
      if (allWords.isEmpty && _nlpService.isLoaded) {
        try {
          allWords = _nlpService.getRandomWords(count: 10);
          debugPrint('📚 Got ${allWords.length} words from NLP service');
        } catch (e) {
          debugPrint('⚠️ Error getting words from NLP service: $e');
        }
      }

    // If no words available, show empty state
    if (allWords.isEmpty) {
      debugPrint('⚠️ No words found in dataset or NLP service');
      debugPrint('📊 Dataset loaded: ${_datasetService.isLoaded}');
      debugPrint('📊 Dataset entries: ${_datasetService.isLoaded ? _datasetService.getAllEntries().length : 0}');
      // COMMENTED OUT: Dummy flashcards fallback
      // if (allWords.isEmpty) {
      //   debugPrint('⚠️ No words found, using dummy flashcards');
      //   final dummyFlashcards = _flashcardService.generateDummyFlashcards(count: 10);
      //   ...
      // }
      
      setState(() {
        _flashcards = [];
        _isLoading = false;
      });
      return;
    }

    // First, quickly generate flashcards from dataset (fast - no async operations per word)
    for (final word in allWords) {
      // Try dataset service first, then fallback to NLP service
      Map<String, dynamic>? metadata = _datasetService.getWordMetadata(word);
      metadata ??= _nlpService.getWordMetadata(word);
      
      // If metadata is null, create a basic flashcard from the word itself
      if (metadata == null) {
        debugPrint('⚠️ No metadata found for "$word", creating basic flashcard');
        flashcards.add({
          'word': word,
          'pronunciation': word,
          'meaning': word,
          'partOfSpeech': 'Noun',
          'difficulty': 3,
          'originalWord': word,
          'imageEmoji': '📚',
        });
        continue;
      }

      final bisaya = metadata['bisaya'] as String? ?? word;
      final english = metadata['english'] as String? ?? '';
      final pronunciation = metadata['pronunciation'] as String? ?? '';

      // Skip only if both English and Bisaya are empty
      if (english.isEmpty && bisaya.isEmpty) {
        debugPrint('⚠️ Skipping word with no translation: $word');
        continue;
      }
      
      // Use word as pronunciation if not available
      final finalPronunciation = pronunciation.isEmpty ? bisaya : pronunciation;

      // Calculate difficulty synchronously (fast, no Firestore call during generation)
      final difficulty = _calculateDifficultyFast(word, metadata);
      _wordDifficulties[word] = difficulty;

      // Get image emoji from dataset metadata or use default
      final imageEmoji = _getImageEmojiFromMetadata(metadata) ?? '📚';

      // DON'T load examples here - load on-demand when card is flipped
      // This significantly speeds up flashcard generation
      
      // DON'T generate fill-in-the-blank here - generate on-demand when needed

      flashcards.add({
        'word': bisaya,
        'pronunciation': finalPronunciation,
        'meaning': english.isNotEmpty ? english : bisaya,
        'partOfSpeech': metadata['partOfSpeech'] as String? ?? 'Verb',
        'difficulty': difficulty,
        'originalWord': word,
        'imageEmoji': imageEmoji,
      });
    }

    // Show flashcards immediately (fast loading)
    // If no flashcards were generated, show empty state
    if (flashcards.isEmpty) {
      debugPrint('⚠️ No flashcards generated from dataset');
      debugPrint('📊 Debug info:');
      debugPrint('  - Dataset loaded: ${_datasetService.isLoaded}');
      if (_datasetService.isLoaded) {
        final allEntries = _datasetService.getAllEntries();
        debugPrint('  - Total entries: ${allEntries.length}');
        if (allEntries.isNotEmpty) {
          debugPrint('  - Sample entry: ${allEntries.first}');
        }
      }
      // COMMENTED OUT: Dummy flashcards fallback
      // if (flashcards.isEmpty) {
      //   debugPrint('⚠️ No flashcards generated from data, using dummy flashcards');
      //   final dummyFlashcards = _flashcardService.generateDummyFlashcards(count: 10);
      //   ...
      // }
      
      setState(() {
        _flashcards = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _flashcards = flashcards;
      _isLoading = false;
    });
    } catch (e) {
      debugPrint('Error generating flashcards: $e');
      // COMMENTED OUT: Dummy flashcards fallback
      // final dummyFlashcards = _flashcardService.generateDummyFlashcards(count: 10);
      // setState(() {
      //   _flashcards = dummyFlashcards;
      //   _isLoading = false;
      // });
      setState(() {
        _flashcards = [];
        _isLoading = false;
      });
    }
  }

  /// Calculate difficulty quickly without Firestore calls
  int _calculateDifficultyFast(String word, Map<String, dynamic> metadata) {
    int difficulty = 1; // Start with easiest

    // Factor 1: Word length (longer = harder)
    if (word.length > 8) difficulty += 1;
    if (word.length > 12) difficulty += 1;

    // Factor 2: Phonetic complexity for English speakers
    final difficultPatterns = ['ng', 'nga', 'kaon', 'gikaon', 'nag'];
    for (var pattern in difficultPatterns) {
      if (word.toLowerCase().contains(pattern)) {
        difficulty += 1;
        break;
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

    // Clamp between 1 and 5
    return difficulty.clamp(1, 5);
  }

  /// Load examples for a word if not already cached
  Future<void> _loadExamplesForWord(String word) async {
    if (word.isEmpty) return;
    
    // Check if already loaded
    if (_contextualExamples.containsKey(word) && 
        (_contextualExamples[word]!['beginner']!.isNotEmpty || 
         _contextualExamples[word]!['intermediate']!.isNotEmpty || 
         _contextualExamples[word]!['advanced']!.isNotEmpty)) {
      return;
    }
    
    try {
      debugPrint('🔄 Loading examples for word: "$word"');
      final examples = await _flashcardService.generateContextualExamples(word)
          .timeout(const Duration(seconds: 3));
      
      if (mounted) {
        setState(() {
          _contextualExamples[word] = examples;
        });
        debugPrint('✅ Loaded examples for "$word": ${examples['beginner']!.length} beginner, ${examples['intermediate']!.length} intermediate, ${examples['advanced']!.length} advanced');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading examples for "$word": $e');
    }
  }

  /// Get image emoji from metadata based on English translation only
  String? _getImageEmojiFromMetadata(Map<String, dynamic> metadata) {
    final english = (metadata['english'] as String? ?? '').toLowerCase();

    // Food & Drinks
    if (english.contains('eat') || english.contains('eating')) return '🍽️';
    if (english.contains('water')) return '💧';
    if (english.contains('rice')) return '🍚';
    if (english.contains('bread')) return '🍞';
    if (english.contains('fruit')) return '🍎';
    if (english.contains('meat') || english.contains('chicken') || english.contains('pork')) return '🍖';
    if (english.contains('fish')) return '🐟';
    if (english.contains('vegetable')) return '🥬';
    if (english.contains('drink') || english.contains('juice')) return '🧃';
    if (english.contains('coffee')) return '☕';
    if (english.contains('food') || english.contains('meal')) return '🍲';
    if (english.contains('cook') || english.contains('cooking')) return '👨‍🍳';
    if (english.contains('hungry')) return '😋';
    if (english.contains('thirsty')) return '🥵';

    // Actions & Verbs
    if (english.contains('sleep') || english.contains('sleeping')) return '😴';
    if (english.contains('walk') || english.contains('walking')) return '🚶';
    if (english.contains('run') || english.contains('running')) return '🏃';
    if (english.contains('sit') || english.contains('sitting')) return '🪑';
    if (english.contains('stand') || english.contains('standing')) return '🧍';
    if (english.contains('dance') || english.contains('dancing')) return '💃';
    if (english.contains('sing') || english.contains('singing')) return '🎤';
    if (english.contains('read') || english.contains('reading')) return '📖';
    if (english.contains('write') || english.contains('writing')) return '✍️';
    if (english.contains('work') || english.contains('working')) return '💼';
    if (english.contains('play') || english.contains('playing')) return '🎮';
    if (english.contains('swim') || english.contains('swimming')) return '🏊';
    if (english.contains('buy') || english.contains('buying')) return '🛒';
    if (english.contains('sell') || english.contains('selling')) return '💰';
    if (english.contains('give') || english.contains('giving')) return '🎁';
    if (english.contains('take') || english.contains('taking')) return '✊';
    if (english.contains('see') || english.contains('look') || english.contains('watch')) return '👀';
    if (english.contains('hear') || english.contains('listen')) return '👂';
    if (english.contains('speak') || english.contains('talk') || english.contains('say')) return '🗣️';
    if (english.contains('think') || english.contains('thinking')) return '🤔';
    if (english.contains('know') || english.contains('understand')) return '💡';
    if (english.contains('learn') || english.contains('study')) return '📚';
    if (english.contains('teach') || english.contains('teaching')) return '👨‍🏫';
    if (english.contains('wait') || english.contains('waiting')) return '⏳';
    if (english.contains('come') || english.contains('arrive')) return '🚪';
    if (english.contains('leave') || english.contains('go away')) return '👋';
    if (english.contains('return') || english.contains('back')) return '🔙';
    if (english.contains('open')) return '📂';
    if (english.contains('close') || english.contains('shut')) return '📁';
    if (english.contains('clean') || english.contains('cleaning')) return '🧹';
    if (english.contains('wash') || english.contains('washing')) return '🧼';
    if (english.contains('drive') || english.contains('driving')) return '🚗';

    // Greetings & Social
    if (english.contains('hello') || english.contains('hi') || english.contains('greet')) return '👋';
    if (english.contains('goodbye') || english.contains('bye')) return '👋';
    if (english.contains('thank') || english.contains('thanks')) return '🙏';
    if (english.contains('please')) return '🙏';
    if (english.contains('sorry') || english.contains('apologize')) return '😔';
    if (english.contains('welcome')) return '🤗';
    if (english.contains('friend')) return '🤝';
    if (english.contains('meet') || english.contains('meeting')) return '🤝';

    // Emotions & Feelings
    if (english.contains('happy') || english.contains('joy') || english.contains('glad')) return '😊';
    if (english.contains('sad') || english.contains('unhappy')) return '😢';
    if (english.contains('love')) return '❤️';
    if (english.contains('like')) return '👍';
    if (english.contains('angry') || english.contains('mad')) return '😠';
    if (english.contains('tired') || english.contains('exhausted')) return '😫';
    if (english.contains('scared') || english.contains('afraid') || english.contains('fear')) return '😨';
    if (english.contains('surprise') || english.contains('shock')) return '😲';
    if (english.contains('worry') || english.contains('worried')) return '😟';
    if (english.contains('excited') || english.contains('excitement')) return '🤩';
    if (english.contains('bored') || english.contains('boring')) return '😑';
    if (english.contains('sick') || english.contains('ill')) return '🤒';
    if (english.contains('pain') || english.contains('hurt')) return '🤕';

    // Family & People
    if (english.contains('mother') || english.contains('mom') || english.contains('mama')) return '👩';
    if (english.contains('father') || english.contains('dad') || english.contains('papa')) return '👨';
    if (english.contains('parent')) return '👨‍👩‍👧';
    if (english.contains('family')) return '👪';
    if (english.contains('child') || english.contains('kid')) return '🧒';
    if (english.contains('baby')) return '👶';
    if (english.contains('brother')) return '👦';
    if (english.contains('sister')) return '👧';
    if (english.contains('grandmother') || english.contains('grandma')) return '👵';
    if (english.contains('grandfather') || english.contains('grandpa')) return '👴';
    if (english.contains('husband') || english.contains('wife') || english.contains('spouse')) return '💑';
    if (english.contains('man') || english.contains('male')) return '👨';
    if (english.contains('woman') || english.contains('female')) return '👩';
    if (english.contains('person') || english.contains('people')) return '🧑';
    if (english.contains('boy')) return '👦';
    if (english.contains('girl')) return '👧';

    // Time & Weather
    if (english.contains('morning')) return '🌅';
    if (english.contains('afternoon') || english.contains('noon')) return '☀️';
    if (english.contains('evening') || english.contains('night')) return '🌙';
    if (english.contains('today')) return '📅';
    if (english.contains('tomorrow')) return '📆';
    if (english.contains('yesterday')) return '⏪';
    if (english.contains('now')) return '⏰';
    if (english.contains('later') || english.contains('soon')) return '🔜';
    if (english.contains('always')) return '♾️';
    if (english.contains('never')) return '🚫';
    if (english.contains('sometimes')) return '🔄';
    if (english.contains('rain') || english.contains('raining')) return '🌧️';
    if (english.contains('sun') || english.contains('sunny')) return '☀️';
    if (english.contains('cloud') || english.contains('cloudy')) return '☁️';
    if (english.contains('hot') || english.contains('warm')) return '🥵';
    if (english.contains('cold') || english.contains('cool')) return '🥶';
    if (english.contains('wind') || english.contains('windy')) return '💨';

    // Body Parts
    if (english.contains('hand')) return '✋';
    if (english.contains('head')) return '🗣️';
    if (english.contains('eye')) return '👁️';
    if (english.contains('mouth') || english.contains('lips')) return '👄';
    if (english.contains('nose')) return '👃';
    if (english.contains('ear')) return '👂';
    if (english.contains('face')) return '😊';
    if (english.contains('hair')) return '💇';
    if (english.contains('foot') || english.contains('feet') || english.contains('leg')) return '🦶';
    if (english.contains('arm')) return '💪';
    if (english.contains('finger')) return '👆';
    if (english.contains('heart')) return '❤️';
    if (english.contains('stomach') || english.contains('belly')) return '🤰';

    // Places & Locations
    if (english.contains('house') || english.contains('home')) return '🏠';
    if (english.contains('school')) return '🏫';
    if (english.contains('church')) return '⛪';
    if (english.contains('market') || english.contains('store') || english.contains('shop')) return '🏪';
    if (english.contains('hospital') || english.contains('clinic')) return '🏥';
    if (english.contains('road') || english.contains('street')) return '🛣️';
    if (english.contains('city') || english.contains('town')) return '🏙️';
    if (english.contains('beach') || english.contains('sea') || english.contains('ocean')) return '🏖️';
    if (english.contains('mountain') || english.contains('hill')) return '⛰️';
    if (english.contains('river') || english.contains('lake')) return '🏞️';
    if (english.contains('farm') || english.contains('field')) return '🌾';
    if (english.contains('forest') || english.contains('tree')) return '🌳';

    // Animals
    if (english.contains('dog')) return '🐕';
    if (english.contains('cat')) return '🐈';
    if (english.contains('bird')) return '🐦';
    if (english.contains('pig')) return '🐷';
    if (english.contains('cow') || english.contains('carabao')) return '🐄';
    if (english.contains('horse')) return '🐴';
    if (english.contains('goat')) return '🐐';
    if (english.contains('chicken') || english.contains('rooster')) return '🐔';
    if (english.contains('snake')) return '🐍';
    if (english.contains('frog')) return '🐸';
    if (english.contains('monkey')) return '🐒';
    if (english.contains('animal')) return '🐾';

    // Objects & Things
    if (english.contains('book')) return '📖';
    if (english.contains('pen') || english.contains('pencil')) return '✏️';
    if (english.contains('phone') || english.contains('cellphone')) return '📱';
    if (english.contains('computer')) return '💻';
    if (english.contains('money')) return '💵';
    if (english.contains('clothes') || english.contains('shirt') || english.contains('dress')) return '👕';
    if (english.contains('shoe') || english.contains('shoes')) return '👟';
    if (english.contains('bag')) return '👜';
    if (english.contains('car') || english.contains('vehicle')) return '🚗';
    if (english.contains('boat') || english.contains('ship')) return '🚢';
    if (english.contains('door')) return '🚪';
    if (english.contains('window')) return '🪟';
    if (english.contains('table')) return '🪑';
    if (english.contains('bed')) return '🛏️';
    if (english.contains('key')) return '🔑';
    if (english.contains('light') || english.contains('lamp')) return '💡';

    // Colors
    if (english.contains('red')) return '🔴';
    if (english.contains('blue')) return '🔵';
    if (english.contains('green')) return '🟢';
    if (english.contains('yellow')) return '🟡';
    if (english.contains('white')) return '⚪';
    if (english.contains('black')) return '⚫';
    if (english.contains('color') || english.contains('colour')) return '🎨';

    // Numbers & Quantities
    if (english.contains('one') || english.contains('first')) return '1️⃣';
    if (english.contains('two') || english.contains('second')) return '2️⃣';
    if (english.contains('three') || english.contains('third')) return '3️⃣';
    if (english.contains('many') || english.contains('much') || english.contains('lot')) return '📊';
    if (english.contains('few') || english.contains('little') || english.contains('small')) return '🤏';
    if (english.contains('big') || english.contains('large')) return '🦣';
    if (english.contains('all') || english.contains('every')) return '💯';
    if (english.contains('number')) return '🔢';

    // Directions & Positions
    if (english.contains('here')) return '📍';
    if (english.contains('there')) return '👉';
    if (english.contains('up') || english.contains('above')) return '⬆️';
    if (english.contains('down') || english.contains('below')) return '⬇️';
    if (english.contains('left')) return '⬅️';
    if (english.contains('right')) return '➡️';
    if (english.contains('front') || english.contains('forward')) return '🔜';
    if (english.contains('back') || english.contains('behind')) return '🔙';
    if (english.contains('inside') || english.contains('in')) return '📥';
    if (english.contains('outside') || english.contains('out')) return '📤';
    if (english.contains('near') || english.contains('close')) return '🔍';
    if (english.contains('far') || english.contains('distant')) return '🔭';

    // Questions & Basic Words
    if (english.contains('what')) return '❓';
    if (english.contains('where')) return '📍';
    if (english.contains('when')) return '⏰';
    if (english.contains('who')) return '👤';
    if (english.contains('why')) return '🤷';
    if (english.contains('how')) return '🔧';
    if (english.contains('yes')) return '✅';
    if (english.contains('no') || english.contains('not')) return '❌';
    if (english.contains('good') || english.contains('nice') || english.contains('well')) return '👍';
    if (english.contains('bad') || english.contains('wrong')) return '👎';
    if (english.contains('beautiful') || english.contains('pretty') || english.contains('handsome')) return '😍';
    if (english.contains('ugly')) return '😬';
    if (english.contains('new')) return '✨';
    if (english.contains('old')) return '🏚️';
    if (english.contains('fast') || english.contains('quick')) return '⚡';
    if (english.contains('slow')) return '🐌';
    if (english.contains('easy')) return '😌';
    if (english.contains('hard') || english.contains('difficult')) return '😓';
    if (english.contains('true') || english.contains('correct')) return '✔️';
    if (english.contains('false') || english.contains('wrong')) return '✖️';
    if (english.contains('same')) return '🟰';
    if (english.contains('different')) return '🔀';

    return null; // Will use default '📚'
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_isCardFlipped) {
      _flipController.reverse();
      // Record interaction when card is flipped back
      if (_flashcards.isNotEmpty) {
        final currentCard = _flashcards[_currentCardIndex];
        final word = currentCard['originalWord'] as String? ?? currentCard['word'] as String;
        final timeSpent = _cardStartTime != null
            ? DateTime.now().difference(_cardStartTime!).inSeconds
            : 0;
        
        // Record as viewed (not necessarily correct, but interacted with)
        _accuracyService.recordFlashcardInteraction(
          word: word,
          isCorrect: true, // Flipping back means they saw the answer
          timeSpent: timeSpent,
          attempts: 1,
        ).catchError((e) {
          debugPrint('Error recording flashcard interaction: $e');
        });
      }
    } else {
      // Start timer when card is first shown
      _cardStartTime = DateTime.now();
      _flipController.forward();
      
      // Load examples on-demand when flipping to back (for faster initial loading)
      if (_flashcards.isNotEmpty) {
        final currentCard = _flashcards[_currentCardIndex];
        final word = currentCard['originalWord'] as String? ?? currentCard['word'] as String;
        // Load examples asynchronously (won't block the flip animation)
        _loadExamplesForWord(word);
      }
    }
    setState(() => _isCardFlipped = !_isCardFlipped);
  }

  void _nextCard() {
    if (_currentCardIndex < _flashcards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isCardFlipped = false;
        _flipController.reset();
        _cardStartTime = DateTime.now(); // Reset timer for new card
      });
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _isCardFlipped = false;
        _flipController.reset();
        _cardStartTime = DateTime.now(); // Reset timer for new card
      });
    }
  }






  Widget _buildFlashcardFront(Map<String, dynamic> card, Color cardColor, Color textColor) {
    final difficulty = card['difficulty'] as int;
    final difficultyColor = _flashcardService.getDifficultyColor(difficulty);
    final word = card['word'] as String;
    
    // Get image emoji from card data (set by AI translation service)
    String imageEmoji = card['imageEmoji'] as String? ?? '📚';

    // Difficulty label
    String difficultyLabel = difficulty <= 2 
        ? 'Easy' 
        : difficulty <= 3 
            ? 'Medium' 
            : 'Hard';

    return Container(
      height: 500,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withValues(alpha: 0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: difficultyColor.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: difficultyColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: difficultyColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF3B5FAE).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Difficulty badge with modern styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [difficultyColor.withValues(alpha: 0.2), difficultyColor.withValues(alpha: 0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: difficultyColor.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (i) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          i < difficulty ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: difficultyColor,
                        ),
                      )),
                      const SizedBox(width: 8),
                      Text(
                        difficultyLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: difficultyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                
                // Emoji with animated glow effect
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        difficultyColor.withValues(alpha: 0.15),
                        difficultyColor.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      imageEmoji,
                      style: const TextStyle(fontSize: 70),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Word with gradient text effect (simulated)
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF3B5FAE), Color(0xFF2666B4)],
                  ).createShader(bounds),
                  child: Text(
                    word,
                    style: GoogleFonts.poppins(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Audio button with modern styling
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B5FAE), Color(0xFF2666B4)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B5FAE).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 32),
                    color: Colors.white,
                    onPressed: () => _speakWord(word),
                    tooltip: 'Hear pronunciation',
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '🔊 Tap to hear pronunciation',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFlashcardBack(Map<String, dynamic> card, Color cardColor, Color textColor) {
    // Try to get examples using originalWord first, then try the actual word
    final originalWord = card['originalWord'] as String? ?? '';
    final word = card['word'] as String? ?? '';
    
    // Try both keys to find examples
    Map<String, List<String>>? examples = _contextualExamples[originalWord];
    examples ??= _contextualExamples[word];
    
    // If still no examples, try to load them on the fly
    if (examples == null || (examples['beginner']!.isEmpty && examples['intermediate']!.isEmpty && examples['advanced']!.isEmpty)) {
      debugPrint('⚠️ No examples in cache for word: "$originalWord" or "$word", attempting to load...');
      // Try to load examples asynchronously (this will update on next rebuild)
      _loadExamplesForWord(originalWord.isNotEmpty ? originalWord : word);
      examples = {
        'beginner': [],
        'intermediate': [],
        'advanced': [],
      };
    }
    
    final finalExamples = examples;

    return Container(
      height: 500, // Fixed height for consistent card size (same as front)
      width: double.infinity, // Ensure full width
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 452), // 500 - 48 (padding)
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
            // Translation
            Text(
              'Translation:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '"${card['meaning'] as String}"',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3B5FAE),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Pronunciation guide with stress indication
            Text(
              'Pronunciation guide:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"${card['pronunciation'] as String}"',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3B5FAE),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '(stress on ${_getStressedSyllable(card['pronunciation'] as String)})',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Part of speech
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B5FAE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B5FAE).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, size: 16, color: const Color(0xFF3B5FAE)),
                    const SizedBox(width: 6),
                    Text(
                      'Part of speech: ${card['partOfSpeech'] as String}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B5FAE),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Contextual Examples
            if (finalExamples['beginner']!.isNotEmpty || 
                finalExamples['intermediate']!.isNotEmpty || 
                finalExamples['advanced']!.isNotEmpty) ...[
              Text(
                'Contextual Examples:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Beginner
              if (finalExamples['beginner']!.isNotEmpty) ...[
                _buildExampleSection('Beginner', finalExamples['beginner']!, Colors.green, textColor),
                const SizedBox(height: 12),
              ],
              
              // Intermediate
              if (finalExamples['intermediate']!.isNotEmpty) ...[
                _buildExampleSection('Intermediate', finalExamples['intermediate']!, Colors.orange, textColor),
                const SizedBox(height: 12),
              ],
              
              // Advanced
              if (finalExamples['advanced']!.isNotEmpty)
                _buildExampleSection('Advanced', finalExamples['advanced']!, Colors.red, textColor),
            ] else ...[
              // Show message if no examples available
              Text(
                'No examples available for this word.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExampleSection(String level, List<String> examples, Color color, Color textColor) {
    if (examples.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            level,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ...examples.map((example) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $example',
              style: GoogleFonts.poppins(fontSize: 13, color: textColor),
              textAlign: TextAlign.center,
            ),
          )),
        ],
      ),
    );
  }


  String _getStressedSyllable(String pronunciation) {
    // Extract stressed syllable from pronunciation guide
    // Format: "kah-ON" -> "ON" (second syllable)
    // Format: "kah-ON" -> "second syllable" if uppercase found
    final parts = pronunciation.split('-');
    
    // Check for uppercase syllable (stressed)
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      // Check if syllable is fully uppercase (stressed)
      if (part == part.toUpperCase() && part != part.toLowerCase()) {
        final syllableNum = i + 1;
        final syllableNames = ['first', 'second', 'third', 'fourth', 'fifth'];
        if (syllableNum <= syllableNames.length) {
          return '${syllableNames[syllableNum - 1]} syllable';
        }
        return 'syllable $syllableNum';
      }
      // Check for uppercase letters within the syllable
      if (part.contains(RegExp(r'[A-Z]'))) {
        final syllableNum = i + 1;
        final syllableNames = ['first', 'second', 'third', 'fourth', 'fifth'];
        if (syllableNum <= syllableNames.length) {
          return '${syllableNames[syllableNum - 1]} syllable';
        }
        return 'syllable $syllableNum';
      }
    }
    
    // Default: if no uppercase found, assume second syllable for common Bisaya patterns
    if (parts.length >= 2) {
      return 'second syllable';
    }
    return 'first syllable';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    const Color kPrimary = Color(0xFF3B5FAE);
    const Color kAccent = Color(0xFF2666B4);
    final backgroundColor = isDark ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final cardColor = isDark ? const Color(0xFF20304A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF071B34);

    // Modern gradient header decoration
    Widget buildGradientHeader() {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimary, kAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 24,
          left: 20,
          right: 20,
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adaptive Flashcards',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Smart learning with AI difficulty',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onToggleDarkMode(!isDark),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.style, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isLoading ? 'Loading...' : 'Card ${_currentCardIndex + 1} of ${_flashcards.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            buildGradientHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _modelLoaded ? 'Generating flashcards...' : 'Loading AI model...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preparing your personalized learning',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_flashcards.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            buildGradientHeader(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.style_outlined, size: 64, color: Colors.orange),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No flashcards available',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _datasetService.isLoaded
                            ? 'Dataset loaded but no words found.\nPlease check the dataset file.'
                            : 'Dataset not loaded.\nPlease ensure the vocabulary data exists.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          try {
                            await _datasetService.loadDataset(forceReload: true);
                            await _generateFlashcards();
                          } catch (e) {
                            debugPrint('Error retrying: $e');
                            setState(() => _isLoading = false);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Loading'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentCard = _flashcards[_currentCardIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          buildGradientHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Flashcard with flip animation
                  GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * 3.14159;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: angle < 1.5708
                              ? _buildFlashcardFront(currentCard, cardColor, textColor)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(3.14159),
                                  child: _buildFlashcardBack(currentCard, cardColor, textColor),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tap hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 18, color: kPrimary),
                        const SizedBox(width: 8),
                        Text(
                          _isCardFlipped ? 'Tap to see word' : 'Tap card to reveal answer',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: kPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Modern navigation controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous button
                      Container(
                        decoration: BoxDecoration(
                          color: _currentCardIndex > 0 ? kPrimary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _currentCardIndex > 0
                              ? [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: _currentCardIndex > 0 ? _previousCard : null,
                          color: Colors.white,
                          iconSize: 28,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Flip button
                      ElevatedButton.icon(
                        onPressed: _flipCard,
                        icon: Icon(_isCardFlipped ? Icons.flip_to_front : Icons.flip_to_back),
                        label: Text(_isCardFlipped ? 'Show Word' : 'Flip Card'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: kAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Next button
                      Container(
                        decoration: BoxDecoration(
                          color: _currentCardIndex < _flashcards.length - 1 ? kPrimary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _currentCardIndex < _flashcards.length - 1
                              ? [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: _currentCardIndex < _flashcards.length - 1 ? _nextCard : null,
                          color: Colors.white,
                          iconSize: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _flipController.dispose();
    _speech.stop();
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    super.dispose();
  }
}

