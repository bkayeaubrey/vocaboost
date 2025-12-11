import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vocaboost/services/quiz_service.dart';
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/translation_service.dart';
import 'package:vocaboost/services/pronunciation_assistant_service.dart';
import 'package:vocaboost/services/flashcard_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:vocaboost/widgets/badge_notification.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceQuizScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const VoiceQuizScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<VoiceQuizScreen> createState() => _VoiceQuizScreenState();
}

class _VoiceQuizScreenState extends State<VoiceQuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _answered = false;
  bool _isCorrect = false;
  final QuizService _quizService = QuizService();
  final TranslationService _translationService = TranslationService();
  final PronunciationAssistantService _pronunciationAssistant = PronunciationAssistantService();
  final AchievementService _achievementService = AchievementService();
  final XPService _xpService = XPService();
  final List<int?> _selectedAnswers = []; // Track all selected answers
  final NLPModelService _nlpService = NLPModelService.instance;
  final Map<String, int> _incorrectCount = {}; // Track consecutive incorrect answers per word
  Map<String, dynamic>? _pronunciationFeedback; // AI feedback for pronunciation
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  String? _spokenAnswer;
  bool _isLoading = true;
  bool _modelLoaded = false;
  
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;
  Timer? _silenceTimer; // Timer for auto-send after silence

  // Pronunciation Quiz - Focus on proper pronunciation of Bisaya words (HARDCODED - COMMENTED OUT)
  // Now using NLPModelService to generate questions dynamically
  /*
  final List<Map<String, dynamic>> _questions = [
    {
      'word': 'Panagsa',
      'pronunciation': 'pah-NAHG-sah',
      'meaning': 'Sometimes',
      'correctAnswer': 'Panagsa',
      'alternatives': ['panagsa', 'panagsa', 'panag sa'],
      'tip': 'Emphasize the second syllable "NAHG"',
    },
    {
      'word': 'Gwapa',
      'pronunciation': 'GWAH-pah',
      'meaning': 'Beautiful',
      'correctAnswer': 'Gwapa',
      'alternatives': ['gwapa', 'guapa', 'gwa pa'],
      'tip': 'Pronounce "Gw" like "Gua" with emphasis on first syllable',
    },
    {
      'word': 'Tubig',
      'pronunciation': 'TOO-big',
      'meaning': 'Water',
      'correctAnswer': 'Tubig',
      'alternatives': ['tubig', 'too big', 'tu big'],
      'tip': 'Stress the first syllable "TOO"',
    },
    {
      'word': 'Maayo',
      'pronunciation': 'mah-AH-yo',
      'meaning': 'Good',
      'correctAnswer': 'Maayo',
      'alternatives': ['maayo', 'ma ayo', 'mah ayo'],
      'tip': 'Emphasize the middle syllable "AH"',
    },
    {
      'word': 'Salamat',
      'pronunciation': 'sah-LAH-maht',
      'meaning': 'Thank you',
      'correctAnswer': 'Salamat',
      'alternatives': ['salamat', 'sala mat', 'sah la mat'],
      'tip': 'Stress the second syllable "LAH"',
    },
    {
      'word': 'Kumusta',
      'pronunciation': 'koo-MOOS-tah',
      'meaning': 'Hello / How are you',
      'correctAnswer': 'Kumusta',
      'alternatives': ['kumusta', 'kumusta ka', 'koo moos ta'],
      'tip': 'Emphasize "MOOS" in the middle',
    },
    {
      'word': 'Maayong buntag',
      'pronunciation': 'mah-AH-yong BOON-tag',
      'meaning': 'Good morning',
      'correctAnswer': 'Maayong buntag',
      'alternatives': ['maayong buntag', 'maayo buntag', 'mah ah yong boon tag'],
      'tip': 'Stress "AH" in maayong and "BOON" in buntag',
    },
  ];
  */
  
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeTts();
    _loadModelAndGenerateQuestions();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // Try to set Bisaya/Filipino language with fallbacks
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
      
      await _flutterTts.setSpeechRate(0.4); // Slower rate for syllable clarity
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

  Future<void> _speakFeedback(String text) async {
    if (!_isTtsInitialized) {
      await _initializeTts();
    }
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }


  Future<void> _loadModelAndGenerateQuestions() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      if (!_nlpService.isLoaded) {
        await _nlpService.loadModel();
      }
      setState(() {
        _modelLoaded = true;
      });
      await _generateQuestions();
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQuestions() async {
    if (!_modelLoaded) return;

    final questions = <Map<String, dynamic>>[];
    final allWords = _nlpService.getRandomWords(count: 10);
    
    if (allWords.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    for (final word in allWords) {
      final metadata = _nlpService.getWordMetadata(word);
      if (metadata == null) continue;

      final bisaya = metadata['bisaya'] as String? ?? word;
      final english = metadata['english'] as String? ?? '';
      final pronunciation = metadata['pronunciation'] as String? ?? '';
      
      if (english.isEmpty || pronunciation.isEmpty) continue;

      // Generate alternatives based on similar words
      final similarWords = await _nlpService.getSimilarWords(word, count: 2);
      final alternatives = <String>[];
      
      for (final similarWord in similarWords) {
        final similarMeta = _nlpService.getWordMetadata(similarWord);
        if (similarMeta != null) {
          final similarBisaya = similarMeta['bisaya'] as String? ?? similarWord;
          alternatives.add(similarBisaya.toLowerCase());
        }
      }
      
      // Add common variations
      alternatives.add(bisaya.toLowerCase());
      alternatives.add(bisaya.toLowerCase().replaceAll(' ', ' '));

      questions.add({
        'word': bisaya,
        'pronunciation': pronunciation,
        'meaning': english,
        'correctAnswer': bisaya,
        'alternatives': alternatives.toSet().toList(),
        'tip': 'Listen carefully to the pronunciation guide',
      });
    }

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      // Auto-check answer after 3 seconds of silence
      if (_isListening && _recognizedText.isNotEmpty) {
        _stopListening();
      }
    });
  }

  Future<void> _startListening() async {
    // If already answered incorrectly, allow retry
    if (_answered && _isCorrect) return;
    
    // If answered incorrectly, reset for retry
    if (_answered && !_isCorrect) {
      _retryPronunciation();
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
        debugPrint('Speech recognition status: $val');
        if (val == 'notAvailable' || val == 'done' || val == 'notListening') {
          if (mounted) {
            if (val == 'notAvailable') {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Speech recognition not available on this device'),
                duration: Duration(seconds: 3),
              ),
            );
            } else if (val == 'done' || val == 'notListening') {
              // Speech recognition stopped naturally
              _silenceTimer?.cancel();
              if (_isListening && _recognizedText.isNotEmpty) {
                _checkAnswer();
              }
            }
          }
        }
      },
      onError: (val) {
        debugPrint('Speech recognition error: $val');
        if (mounted) {
          setState(() => _isListening = false);
          String errorMessage = 'Speech recognition error occurred';
          
          // Parse error message for user-friendly feedback
          final errorMsgLower = val.errorMsg.toLowerCase();
          if (errorMsgLower.contains('permission')) {
            errorMessage = 'Microphone permission required. Please grant permission in your device settings.';
          } else if (errorMsgLower.contains('not available')) {
            errorMessage = 'Speech recognition is not available on this device.';
          } else if (errorMsgLower.contains('network')) {
            errorMessage = 'Network error. Please check your internet connection.';
          } else if (errorMsgLower.contains('timeout')) {
            errorMessage = 'Speech recognition timed out. Please try again.';
          } else if (errorMsgLower.contains('no match')) {
            errorMessage = 'Could not recognize speech. Please try speaking again.';
          } else {
            errorMessage = 'Speech recognition error: ${val.errorMsg}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available. Please check your device settings and microphone permissions.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _spokenAnswer = null;
    });

    // Start the silence timer
    _resetSilenceTimer();

    try {
    _speech.listen(
      onResult: (val) {
        setState(() {
          _recognizedText = val.recognizedWords;
        });
          // Reset timer on each new word recognition
          if (val.finalResult) {
            // Final result - check answer immediately
            _stopListening();
          } else {
            // Partial result - reset silence timer
            _resetSilenceTimer();
          }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: false,
      partialResults: true,
      localeId: 'en_US', // Try to use English locale
    );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start speech recognition: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _stopListening() {
    _silenceTimer?.cancel();
    try {
    _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
    setState(() {
      _isListening = false;
    });
    _checkAnswer();
  }

  void _checkAnswer() {
    if (_recognizedText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pronounce the word')),
        );
      }
      return;
    }

    if (_questions.isEmpty) return;
    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correctAnswer'] as String;
    final alternatives = (currentQuestion['alternatives'] as List<dynamic>)
        .map((e) => e.toString().toLowerCase().trim())
        .toList();

    // Normalize spoken text: remove punctuation, extra spaces, common filler words
    String normalizeText(String text) {
      return text
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
          .replaceAll(RegExp(r'\b(the|a|an|is|are|was|were)\b', caseSensitive: false), '') // Remove common filler words
          .trim();
    }

    final spokenText = normalizeText(_recognizedText);
    final correctAnswerNormalized = normalizeText(correctAnswer);
    
    debugPrint('Voice Quiz Check:');
    debugPrint('  Original recognized: "$_recognizedText"');
    debugPrint('  Normalized spoken: "$spokenText"');
    debugPrint('  Correct answer: "$correctAnswer"');
    debugPrint('  Normalized correct: "$correctAnswerNormalized"');
    debugPrint('  Alternatives: $alternatives');
    
    // Check for exact match
    bool isCorrect = spokenText == correctAnswerNormalized;
    
    // Check if spoken text contains the correct answer (for cases with extra words)
    if (!isCorrect) {
      isCorrect = spokenText.contains(correctAnswerNormalized) || 
                  correctAnswerNormalized.contains(spokenText);
    }
    
    // Check alternatives
    if (!isCorrect) {
      for (final alt in alternatives) {
        final altNormalized = normalizeText(alt);
        if (spokenText == altNormalized || 
            spokenText.contains(altNormalized) || 
            altNormalized.contains(spokenText)) {
          isCorrect = true;
          break;
        }
      }
    }
    
    // For phrases: check if all key words are present
    if (!isCorrect && correctAnswer.contains(' ')) {
      final words = correctAnswerNormalized.split(' ').where((w) => w.isNotEmpty).toList();
      final spokenWords = spokenText.split(' ').where((w) => w.isNotEmpty).toList();
      // Check if all key words are present (with fuzzy matching)
      isCorrect = words.every((word) => 
        spokenWords.any((spoken) => 
          spoken == word || 
          spoken.contains(word) || 
          word.contains(spoken) ||
          (spoken.length > 2 && word.length > 2 && 
           (spoken.substring(0, spoken.length > 3 ? 3 : spoken.length) == 
            word.substring(0, word.length > 3 ? 3 : word.length)))
        )
      );
    }
    
    // For single words: check if the core word is present (fuzzy match)
    if (!isCorrect && !correctAnswer.contains(' ')) {
      final correctWord = correctAnswerNormalized;
      // Check if spoken text contains the word or vice versa
      isCorrect = spokenText.contains(correctWord) || 
                  correctWord.contains(spokenText);
      
      // Additional fuzzy check: if both are similar length and share significant characters
      if (!isCorrect && spokenText.length > 2 && correctWord.length > 2) {
        final minLength = spokenText.length < correctWord.length 
            ? spokenText.length 
            : correctWord.length;
        // Check if first 3+ characters match (for pronunciation variations)
        if (minLength >= 3) {
          final spokenStart = spokenText.substring(0, minLength > 4 ? 4 : minLength);
          final correctStart = correctWord.substring(0, minLength > 4 ? 4 : minLength);
          isCorrect = spokenStart == correctStart;
        }
      }
    }
    
    debugPrint('  Result: ${isCorrect ? "CORRECT" : "INCORRECT"}');

    final bisayaWord = currentQuestion['word'] as String? ?? '';
    
    setState(() {
      _answered = true;
      _isCorrect = isCorrect;
      _spokenAnswer = _recognizedText;
      if (isCorrect) {
        _score++;
        // Save answer index (we'll use -1 for voice answers)
        _selectedAnswers.add(-1);
        
        // Reset incorrect count for this word
        if (bisayaWord.isNotEmpty) {
          _incorrectCount[bisayaWord] = 0;
        }
        
        // Speak "Excellent" for correct answer
        _speakFeedback('Excellent');
        
        // Only auto-advance if correct
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _currentQuestionIndex < _questions.length - 1) {
            setState(() {
              _currentQuestionIndex++;
              _answered = false;
              _isCorrect = false;
              _recognizedText = '';
              _spokenAnswer = null;
            });
          } else if (mounted) {
            _saveQuizResult();
            _showFinalScore();
          }
        });
      } else {
        // Track incorrect answer
        if (bisayaWord.isNotEmpty) {
          _incorrectCount[bisayaWord] = (_incorrectCount[bisayaWord] ?? 0) + 1;
          
          // Auto-save if incorrect 3 times in a row
          if (_incorrectCount[bisayaWord]! >= 3) {
            _autoSaveWord(bisayaWord);
            _incorrectCount[bisayaWord] = 0; // Reset after saving
          }
        }
        
        // Get AI-powered pronunciation feedback
        final pronunciation = currentQuestion['pronunciation'] as String? ?? '';
        _pronunciationFeedback = null; // Reset feedback
        _pronunciationAssistant.getPronunciationFeedback(
          spokenText: _recognizedText,
          correctWord: correctAnswer,
          pronunciationGuide: pronunciation,
        ).then((feedback) {
          if (mounted) {
            setState(() {
              _pronunciationFeedback = feedback;
            });
          }
        }).catchError((e) {
          debugPrint('Error getting pronunciation feedback: $e');
        });
        
        // Speak "Try again" for incorrect answer
        _speakFeedback('Try again');
        // Don't auto-advance if incorrect - allow retry
        // User can tap mic again to try
      }
    });
  }

  Future<void> _autoSaveWord(String bisayaWord) async {
    try {
      final metadata = _nlpService.getWordMetadata(bisayaWord);
      if (metadata != null) {
        final english = metadata['english'] as String? ?? '';
        if (english.isNotEmpty) {
          await _translationService.saveTranslation(
            input: bisayaWord,
            output: english,
            fromLanguage: 'Bisaya',
            toLanguage: 'English',
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to auto-save word: $e');
    }
  }

  void _moveToNextQuestion() {
    // Save the incorrect attempt if user skips
    if (_answered && !_isCorrect) {
      _selectedAnswers.add(-1);
    }
    
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _isCorrect = false;
        _recognizedText = '';
        _spokenAnswer = null;
      });
    } else {
      _saveQuizResult();
      _showFinalScore();
    }
  }

  void _retryPronunciation() {
    setState(() {
      _answered = false;
      _isCorrect = false;
      _recognizedText = '';
      _spokenAnswer = null;
    });
  }

  Future<void> _saveQuizResult() async {
    try {
      await _quizService.saveQuizResult(
        score: _score,
        totalQuestions: _questions.length,
        questions: _questions,
        selectedAnswers: _selectedAnswers,
      );
      
      // Update learning streak when quiz is completed
      final flashcardService = FlashcardService();
      await flashcardService.updateLearningStreak();
      
      // Award XP for voice quiz
      final xp = 15 + (_score * 5);
      await _xpService.earnXP(amount: xp, activityType: 'voice_quiz');
      
      // Get voice exercise count and check achievements
      final voiceExercisesCount = await _quizService.getVoiceExercisesCount();
      final isPerfect = _score == _questions.length;
      final perfectCount = isPerfect ? await _quizService.getPerfectQuizCount() : null;
      
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(
        voiceExercises: voiceExercisesCount,
        quizzesCompleted: await _quizService.getTotalQuizzesCompleted(),
        perfectQuizzes: perfectCount,
      );
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }
    } catch (e) {
      debugPrint('Failed to save quiz result: $e');
    }
  }

  void _showFinalScore() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pronunciation Quiz Completed!'),
        content: Text('Your score is $_score out of ${_questions.length}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentQuestionIndex = 0;
                _score = 0;
                _answered = false;
                _isCorrect = false;
                _recognizedText = '';
                _spokenAnswer = null;
                _selectedAnswers.clear();
              });
            },
            child: const Text('Restart'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Blue Hour Harbor Palette
    const Color kPrimary = Color(0xFF3B5FAE);
    const Color kAccent = Color(0xFF2666B4);
    final Color backgroundColor = isDark ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = isDark ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF071B34);

    // Modern gradient header
    Widget buildVoiceQuizHeader() {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
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
                      Row(
                        children: [
                          const Text('🎤', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(
                            'Voice Quiz',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Practice your pronunciation!',
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
            const SizedBox(height: 16),
            // Score display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Score: $_score / ${_questions.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
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
            buildVoiceQuizHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _modelLoaded ? '🎤 Generating questions...' : '🔄 Loading model...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preparing your voice quiz!',
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

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            buildVoiceQuizHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('😕', style: TextStyle(fontSize: 48)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No questions available',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your model files.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          buildVoiceQuizHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.quiz, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Word Card with modern styling
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🗣️ Pronounce this word',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          currentQuestion['word'],
                          style: GoogleFonts.poppins(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: kAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '(${currentQuestion['pronunciation']})',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: kPrimary,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Meaning: ${currentQuestion['meaning']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Tip: ${currentQuestion['tip']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Spoken Answer Display with modern feedback
                  if (_spokenAnswer != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isCorrect
                              ? [Colors.green.withValues(alpha: 0.15), Colors.green.withValues(alpha: 0.05)]
                              : [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.05)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCorrect ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _isCorrect ? '🎉' : '😅',
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You said: "$_spokenAnswer"',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isCorrect
                                ? '✓ Excellent pronunciation!'
                                : '✗ Try again. Say: "${currentQuestion['correctAnswer']}"',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_isCorrect) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '🔊 ${currentQuestion['pronunciation']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // AI-powered pronunciation feedback
                            if (_pronunciationFeedback != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.withValues(alpha: 0.1),
                                      Colors.purple.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🤖', style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'AI Feedback',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        if (_pronunciationFeedback!['overallScore'] != null) ...[
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${_pronunciationFeedback!['overallScore']}/100',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_pronunciationFeedback!['feedback'] != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _pronunciationFeedback!['feedback'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                    if (_pronunciationFeedback!['tips'] != null &&
                                        (_pronunciationFeedback!['tips'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ...(_pronunciationFeedback!['tips'] as List).map((tip) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('• ', style: GoogleFonts.poppins(color: Colors.blue.shade700)),
                                                Expanded(
                                                  child: Text(
                                                    tip.toString(),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: textColor.withValues(alpha: 0.9),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _retryPronunciation,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton.icon(
                                  onPressed: _moveToNextQuestion,
                                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                                  label: const Text('Skip'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (_recognizedText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('👂', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Listening: "$_recognizedText"',
                              style: GoogleFonts.poppins(fontSize: 16, color: textColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Voice Input Button with animated styling
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isListening ? 140 : 120,
                      height: _isListening ? 140 : 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [Colors.red.shade400, Colors.red.shade600]
                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : const Color(0xFF10B981)).withValues(alpha: 0.4),
                            blurRadius: _isListening ? 30 : 20,
                            spreadRadius: _isListening ? 8 : 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: _isListening ? 60 : 50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isListening
                          ? '🎧 Listening... Tap to check'
                          : _answered && !_isCorrect
                              ? '🔄 Tap mic to try again'
                              : '🎤 Tap to pronounce',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
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
    try {
      _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech recognition in dispose: $e');
    }
    if (_isTtsInitialized) {
      try {
      _flutterTts.stop();
      } catch (e) {
        debugPrint('TTS stop error: $e');
      }
    }
    super.dispose();
  }
}

