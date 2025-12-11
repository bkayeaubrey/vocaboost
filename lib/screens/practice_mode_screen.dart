import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/progressive_learning_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/services/quiz_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:vocaboost/widgets/badge_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

/// Interactive Practice Mode - Fill-in-the-blank exercises
class PracticeModeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const PracticeModeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  static const String _kUnlockedLevelKey = 'practice_unlocked_level';
  final DatasetService _datasetService = DatasetService.instance;
  final ProgressiveLearningService _progressiveLearningService = ProgressiveLearningService();
  final AchievementService _achievementService = AchievementService();
  final QuizService _quizService = QuizService();
  final XPService _xpService = XPService();
  // ignore: unused_field
  DateTime? _exerciseStartTime;
  
  // Quiz mode
  // ignore: unused_field
  bool _isLoading = true;
  int _selectedDifficulty = -1; // -1=No selection (show cards), 0=Beginner, 1=Intermediate, 2=Advanced
  final Map<int, List<Map<String, dynamic>>> _quizQuestions = {}; // Questions by difficulty (0=Beginner, 1=Intermediate, 2=Advanced)
  Map<int, int> _currentQuestionIndex = {0: 0, 1: 0, 2: 0}; // Current question index per difficulty
  Map<int, Map<String, String?>> _selectedAnswers = {0: {}, 1: {}, 2: {}}; // Selected answers per difficulty
  Map<int, int> _scores = {0: 0, 1: 0, 2: 0}; // Scores per difficulty
  Map<int, int> _totalAnsweredQuiz = {0: 0, 1: 0, 2: 0}; // Total answered per difficulty
  bool _showResults = false;

  // Progressive Learning Mode
  final bool _useProgressiveMode = true;
  Map<String, dynamic>? _currentProgression;
  int _selectedProgressiveLevel = -1;
  String? _progressiveSelectedAnswer;
  bool _progressiveAnswered = false;
  int _progressiveCorrectCount = 0;
  int _progressiveTotalCount = 0;
  bool _progressiveLoading = false;
  bool _progressiveLoadingAttempted = false;
  // Cache per-level question lists (up to 10 each)
  final Map<int, List<Map<String, dynamic>>> _progressiveLevelQuestionsCache = {};
  List<Map<String, dynamic>>? _currentLevelQuestions;
  int _currentLevelQuestionIndex = 0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _exerciseStartTime = DateTime.now();
    // Load progressive mode data immediately. Attach error handler to the Future
    // so that async exceptions are caught and handled (avoids unhandled zone errors).
    _loadProgressiveProgression().catchError((e, st) {
      debugPrint('❌ initState: failed to load progressive progression asynchronously: $e\n$st');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error opening Practice Mode'),
              content: Text('An error occurred while opening Practice Mode:\n\n${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (e2) {
          debugPrint('Failed to show init error dialog: $e2');
        }
      });
    });
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// Track quiz completion and check achievements
  Future<void> _trackQuizCompletion(int correct, int total, bool isPerfect) async {
    try {
      // Award XP for quiz completion
      final xp = 10 + (correct * 5) + (isPerfect ? 20 : 0);
      await _xpService.earnXP(amount: xp, activityType: 'practice_quiz');
      
      // Save quiz result for tracking
      await _quizService.saveQuizResult(
        score: correct,
        totalQuestions: total,
        questions: _currentLevelQuestions ?? [],
        selectedAnswers: [],
      );
      
      // Get quiz stats and check achievements
      final quizzesCompleted = await _quizService.getTotalQuizzesCompleted();
      final perfectQuizzes = isPerfect ? await _quizService.getPerfectQuizCount() : null;
      
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(
        quizzesCompleted: quizzesCompleted,
        perfectQuizzes: perfectQuizzes,
      );
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }
    } catch (e) {
      debugPrint('Error tracking quiz completion: $e');
    }
  }

  /// Load quiz questions for all difficulty levels
  Future<void> _loadQuizQuestions() async {
    setState(() => _isLoading = true);
    _selectedAnswers = {0: {}, 1: {}, 2: {}};
    _currentQuestionIndex = {0: 0, 1: 0, 2: 0};
    _scores = {0: 0, 1: 0, 2: 0};
    _totalAnsweredQuiz = {0: 0, 1: 0, 2: 0};
    _showResults = false;

    try {
      // Ensure dataset is loaded first
      await _datasetService.loadDataset(forceReload: false);
      debugPrint('🔄 Dataset loaded, generating quiz questions...');
      
      final allEntries = _datasetService.getAllEntries();
      debugPrint('📊 Found ${allEntries.length} entries in dataset');
      
      if (allEntries.isEmpty) {
        debugPrint('❌ No dataset entries available');
        setState(() => _isLoading = false);
        return;
      }

      // Generate questions for each difficulty level
      final beginnerQuestions = <Map<String, dynamic>>[];
      final intermediateQuestions = <Map<String, dynamic>>[];
      final advancedQuestions = <Map<String, dynamic>>[];

      // Shuffle entries for randomness
      final shuffledEntries = List.from(allEntries)..shuffle();

      for (final entry in shuffledEntries) {
        final practice = _generateVocabularyPractice(entry);
        if (practice == null) continue;

        // Add questions to respective difficulty lists
        if (practice['beginner'] != null) {
          beginnerQuestions.add({
            'word': practice['word'],
            'english': practice['english'],
            'tagalog': practice['tagalog'],
            'pronunciation': practice['pronunciation'],
            'partOfSpeech': practice['partOfSpeech'],
            'category': practice['category'],
            'exercise': practice['beginner'],
            'level': 'Beginner',
          });
        }
        if (practice['intermediate'] != null) {
          intermediateQuestions.add({
            'word': practice['word'],
            'english': practice['english'],
            'tagalog': practice['tagalog'],
            'pronunciation': practice['pronunciation'],
            'partOfSpeech': practice['partOfSpeech'],
            'category': practice['category'],
            'exercise': practice['intermediate'],
            'level': 'Intermediate',
          });
        }
        if (practice['advanced'] != null) {
          advancedQuestions.add({
            'word': practice['word'],
            'english': practice['english'],
            'tagalog': practice['tagalog'],
            'pronunciation': practice['pronunciation'],
            'partOfSpeech': practice['partOfSpeech'],
            'category': practice['category'],
            'exercise': practice['advanced'],
            'level': 'Advanced',
          });
        }

        // Stop when we have enough questions (10 per level)
        if (beginnerQuestions.length >= 10 && 
            intermediateQuestions.length >= 10 && 
            advancedQuestions.length >= 10) {
          break;
        }
      }

      // Limit to 10 questions per level
      beginnerQuestions.shuffle();
      intermediateQuestions.shuffle();
      advancedQuestions.shuffle();

      setState(() {
        _quizQuestions[0] = beginnerQuestions.take(10).toList();
        _quizQuestions[1] = intermediateQuestions.take(10).toList();
        _quizQuestions[2] = advancedQuestions.take(10).toList();
        _isLoading = false;
      });

      debugPrint('✅ Quiz questions loaded:');
      debugPrint('   Beginner: ${_quizQuestions[0]?.length ?? 0} questions');
      debugPrint('   Intermediate: ${_quizQuestions[1]?.length ?? 0} questions');
      debugPrint('   Advanced: ${_quizQuestions[2]?.length ?? 0} questions');
    } catch (e) {
      debugPrint('❌ Error loading quiz questions: $e');
      setState(() => _isLoading = false);
    }
  }

  /* COMMENTED OUT - Old practice mode method, replaced by quiz
  Future<void> _loadPracticeExercises({bool forceReload = false}) async {
    setState(() => _isLoading = true);

    try {
      // Load dataset first (primary source)
      debugPrint('🔄 Loading exercises from dataset (fast)...');
      
      // Try to load dataset with better error handling
      try {
        if (!_datasetService.isLoaded || forceReload) {
          await _datasetService.loadDataset(forceReload: forceReload).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ Dataset loading timeout, using fallback');
            },
          );
        }
      } catch (e) {
        debugPrint('⚠️ Dataset loading error: $e');
      }
      
      // Get ALL entries from dataset (not just random words)
      // Apply contextual example logic to EACH row
      if (!_datasetService.isLoaded) {
        throw Exception('Dataset not loaded');
      }
      
      final allEntries = _datasetService.getAllEntries();
      debugPrint('📚 Processing ALL ${allEntries.length} entries from dataset');
      
      if (allEntries.isEmpty) {
        throw Exception('No entries available in dataset');
      }
      
      final exercises = <Map<String, dynamic>>[];
      
      // Generate exercises for ALL dataset entries (each row)
      // Process in batches to avoid overwhelming the system
      final batchSize = 20; // Process 20 at a time
      for (int i = 0; i < allEntries.length; i += batchSize) {
        final batch = allEntries.skip(i).take(batchSize).toList();
        debugPrint('🔄 Processing batch ${(i ~/ batchSize) + 1}: entries ${i + 1} to ${i + batch.length}');
        
        // Generate exercises in parallel for this batch
        final futures = batch.map((entry) async {
        try {
          // Use the entry directly (we already have the metadata)
          final metadata = entry;
          final bisaya = (metadata['bisaya'] as String? ?? '').trim();
          final english = (metadata['english'] as String? ?? '').trim();
          final pronunciation = (metadata['pronunciation'] as String? ?? '').trim();
          final partOfSpeech = (metadata['partOfSpeech'] as String? ?? 'Unknown').trim();
          
          // Skip if no Bisaya word
          if (bisaya.isEmpty) {
            return null;
          }
          
          // Use contextual examples from database (saved_words) first, then fallback to dataset
          Map<String, dynamic>? fillInBlank;
          
          // Try to get examples from saved_words collection in database
          try {
            final user = _auth.currentUser;
            if (user != null) {
              final querySnapshot = await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_words')
                  .where('input', isEqualTo: bisaya)
                  .limit(1)
                  .get();
              
              if (querySnapshot.docs.isNotEmpty) {
                final doc = querySnapshot.docs.first;
                final data = doc.data();
                
                final beginnerExample = (data['beginnerExample'] as String? ?? '').trim();
                final intermediateExample = (data['intermediateExample'] as String? ?? '').trim();
                final advancedExample = (data['advancedExample'] as String? ?? '').trim();
                
                // Use database examples if available
                if (beginnerExample.isNotEmpty || intermediateExample.isNotEmpty || advancedExample.isNotEmpty) {
                  final dbMetadata = {
                    'beginnerExample': beginnerExample,
                    'intermediateExample': intermediateExample,
                    'advancedExample': advancedExample,
                    ...metadata,
                  };
                  
                  fillInBlank = _createFillInBlankFromDatasetExamples(
                    dbMetadata,
                    bisaya,
                    english,
                    partOfSpeech,
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error getting examples from database: $e');
          }
          
          // Fallback to dataset examples if database didn't have them
          if (fillInBlank == null || fillInBlank.isEmpty) {
            fillInBlank = _createFillInBlankFromDatasetExamples(
              metadata, 
              bisaya, 
              english, 
              partOfSpeech
            );
          }
          
          // If no contextual example available, skip this entry
          if (fillInBlank == null || fillInBlank.isEmpty) {
            return null;
          }
          
          return {
            'word': bisaya,
            'meaning': english,
            'pronunciation': pronunciation,
            'fillInBlank': fillInBlank,
          };
        } catch (e) {
          debugPrint('❌ Error processing entry: $e');
          return null;
        }
      });
      
      // Wait for all exercises in this batch to load in parallel
      final batchResults = await Future.wait(futures, eagerError: false);
      
      // Add valid exercises from this batch
      for (final result in batchResults) {
        if (result == null) continue;
        
        var fillInBlank = result['fillInBlank'] as Map<String, dynamic>?;
        if (fillInBlank == null || fillInBlank.isEmpty) {
          continue;
        }
        
        final sentence = fillInBlank['sentence'] as String? ?? '';
        final optionsRaw = fillInBlank['options'];
        final hasValidOptions = optionsRaw is List && (optionsRaw).isNotEmpty;
        final correctAnswer = fillInBlank['correctAnswer'] as String? ?? '';
        
        // Only add if all required fields are present
        if (sentence.isNotEmpty && hasValidOptions && correctAnswer.isNotEmpty) {
          exercises.add(result);
        }
      }
      
      debugPrint('✅ Batch ${(i ~/ batchSize) + 1} complete: ${exercises.length} total exercises so far');
    }
    
    // All batches processed
    debugPrint('🎉 Finished processing all ${allEntries.length} entries');
    debugPrint('📊 Generated ${exercises.length} valid exercises from dataset');
    
    // COMMENTED OUT: Basic fallback exercises
      // if (exercises.isEmpty) {
      //   debugPrint('⚠️ No valid exercises generated, creating basic fallback');
      //   for (int i = 0; i < words.length && i < 10; i++) {
      //     final word = words[i];
      //     try {
      //       final basicFillInBlank = _createBasicFillInBlank(word, '', 'Verb');
      //       exercises.add({
      //         'word': word,
      //         'meaning': '',
      //         'pronunciation': '',
      //         'fillInBlank': basicFillInBlank,
      //       });
      //     } catch (e) {
      //       debugPrint('⚠️ Error creating basic exercise for $word: $e');
      //     }
      //   }
      // }
      
      if (exercises.isEmpty) {
        throw Exception('Failed to generate any exercises');
      }

      // Show exercises immediately
      setState(() {
        _practiceExercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading practice exercises: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercises: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  */ // END COMMENTED OUT - Old practice mode method

  /// Create fill-in-blank exercise from dataset examples (Bisaya only)
  // ignore: unused_element
  Map<String, dynamic>? _createFillInBlankFromDatasetExamples(
    Map<String, dynamic>? metadata,
    String bisaya,
    String english,
    String partOfSpeech,
  ) {
    if (metadata == null) return null;
    
    // Get Bisaya examples from dataset (Bisaya only, no translations)
    final beginnerBisaya = (metadata['beginnerExample'] as String? ?? '').trim();
    final intermediateBisaya = (metadata['intermediateExample'] as String? ?? '').trim();
    final advancedBisaya = (metadata['advancedExample'] as String? ?? '').trim();
    
    // Use the first available example (prefer beginner, then intermediate, then advanced)
    String? exampleSentence;
    if (beginnerBisaya.isNotEmpty) {
      exampleSentence = beginnerBisaya;
    } else if (intermediateBisaya.isNotEmpty) {
      exampleSentence = intermediateBisaya;
    } else if (advancedBisaya.isNotEmpty) {
      exampleSentence = advancedBisaya;
    }
    
    if (exampleSentence == null || exampleSentence.isEmpty) {
      debugPrint('⚠️ No Bisaya examples found in dataset for: $bisaya');
      return null;
    }
    
    // Find the actual word form in the sentence (it might be conjugated/inflected)
    // Example: "Ang proyekto magpadayon sa Marso sunod tuig." -> "Ang proyekto magpadayon sa _____ sunod tuig."
    String sentence = exampleSentence;
    String correctAnswer = bisaya;
    final wordLower = bisaya.toLowerCase().trim();
    final sentenceLower = sentence.toLowerCase();
    
    // Try to find the base word or its inflected forms in the sentence
    // Common Bisaya verb prefixes: mo-, mag-, nag-, gi-, ka-, etc.
    // Also check for exact match first (for nouns, adjectives, etc. that don't change)
    final wordForms = [
      bisaya, // Original form (exact match first - important for nouns like "Marso")
      wordLower, // Lowercase
      bisaya.trim(), // Trimmed original
      'mo$wordLower', // Infinitive
      'mag$wordLower', // Future/Infinitive
      'nag$wordLower', // Present progressive
      'gi$wordLower', // Past
      'ka$wordLower', // Ability/possibility
      wordLower.replaceAll('mo', ''), // Remove mo prefix if present
      wordLower.replaceAll('mag', ''), // Remove mag prefix if present
      wordLower.replaceAll('nag', ''), // Remove nag prefix if present
      wordLower.replaceAll('gi', ''), // Remove gi prefix if present
    ];
    
    // Find which form appears in the sentence
    String? foundForm;
    int foundIndex = -1;
    int foundLength = 0;
    
    for (final form in wordForms) {
      if (form.isEmpty) continue;
      final formLower = form.toLowerCase();
      
      // Search for the word in the sentence (case-insensitive)
      int index = sentenceLower.indexOf(formLower);
      
      // Try to find whole word matches (not part of another word)
      while (index != -1) {
        // Check if it's a whole word (not part of another word)
        final before = index > 0 ? sentenceLower[index - 1] : ' ';
        final after = index + form.length < sentenceLower.length 
            ? sentenceLower[index + form.length] 
            : ' ';
        
        // Check if surrounded by word boundaries (space, punctuation, or start/end)
        if (!_isLetter(before) && !_isLetter(after)) {
          // Found a whole word match!
          foundForm = sentence.substring(index, index + form.length);
          foundIndex = index;
          foundLength = form.length;
          correctAnswer = foundForm; // Use the exact form found in sentence
          break;
        }
        
        // Continue searching from next position
        index = sentenceLower.indexOf(formLower, index + 1);
      }
      
      if (foundIndex != -1) break; // Found a match, stop searching
    }
    
    // If found, replace with blank
    if (foundIndex != -1 && foundForm != null) {
      // Replace the word with blank, preserving spacing
      sentence = '${sentence.substring(0, foundIndex)}_____${sentence.substring(foundIndex + foundLength)}';
      correctAnswer = foundForm; // Use the exact form found in sentence
      debugPrint('✅ Found word "$foundForm" at index $foundIndex, replaced with blank');
      debugPrint('   Original sentence: "$exampleSentence"');
      debugPrint('   Modified sentence: "$sentence"');
      debugPrint('   Correct answer: "$correctAnswer"');
      debugPrint('   Dataset word: "$bisaya"');
    } else {
      // If word not found in any form, try case-insensitive partial match as last resort
      final partialIndex = sentenceLower.indexOf(wordLower);
      if (partialIndex != -1) {
        // Check word boundaries
        final before = partialIndex > 0 ? sentenceLower[partialIndex - 1] : ' ';
        final after = partialIndex + wordLower.length < sentenceLower.length 
            ? sentenceLower[partialIndex + wordLower.length] 
            : ' ';
        if (!_isLetter(before) && !_isLetter(after)) {
          foundIndex = partialIndex;
          foundLength = wordLower.length;
          correctAnswer = sentence.substring(partialIndex, partialIndex + wordLower.length);
          sentence = '${sentence.substring(0, partialIndex)}_____${sentence.substring(partialIndex + wordLower.length)}';
          debugPrint('✅ Found word (partial match) at index $foundIndex, replaced with blank');
        } else {
          // Word not found, can't create valid exercise
          debugPrint('⚠️ Word "$bisaya" not found in sentence: "$exampleSentence"');
          return null;
        }
      } else {
        debugPrint('⚠️ Word "$bisaya" not found in sentence: "$exampleSentence"');
        return null;
      }
    }
    
    // Determine the grammatical form/prefix of the correct answer
    // This helps us generate wrong options in the same form
    String? prefix;
    String detectedBaseWord = bisaya.toLowerCase().trim();
    
    // Extract prefix from the correct answer found in sentence
    final correctLower = correctAnswer.toLowerCase();
    if (correctLower.startsWith('mo') && correctLower.length > 2) {
      prefix = 'mo';
      // The base word should match the dataset word
      detectedBaseWord = correctLower.substring(2);
    } else if (correctLower.startsWith('mag') && correctLower.length > 3) {
      prefix = 'mag';
      detectedBaseWord = correctLower.substring(3);
    } else if (correctLower.startsWith('nag') && correctLower.length > 3) {
      prefix = 'nag';
      detectedBaseWord = correctLower.substring(3);
    } else if (correctLower.startsWith('gi') && correctLower.length > 2) {
      prefix = 'gi';
      detectedBaseWord = correctLower.substring(2);
    } else if (correctLower.startsWith('ka') && correctLower.length > 2) {
      prefix = 'ka';
      detectedBaseWord = correctLower.substring(2);
    }
    
    // Generate wrong options using OTHER Bisaya words from ANY other dataset rows/cells
    // Wrong choices can be ANY words from other entries (not filtered by part of speech)
    // Example: For "Marso", wrong choices could be "Enero", "Pebrero" (months) OR "Salamat", "Adlaw" (other words)
    final allEntries = _datasetService.getAllEntries();
    final options = <String>[];
    
    // IMPORTANT: Add correct answer first (the exact form found in sentence)
    options.add(correctAnswer);
    debugPrint('📝 Added correct answer to options: "$correctAnswer"');
    
    // Get words from ANY other dataset entries (different rows)
    // These are actual words from other cells/rows in the dataset
    final otherWordsFromDataset = allEntries
        .where((e) {
          final entryBisaya = (e['bisaya'] as String? ?? '').trim();
          return entryBisaya.isNotEmpty &&
                 entryBisaya.toLowerCase() != bisaya.toLowerCase() &&
                 entryBisaya.toLowerCase() != correctAnswer.toLowerCase();
        })
        .map((e) => (e['bisaya'] as String? ?? '').trim())
        .where((w) => w.isNotEmpty)
        .toSet() // Remove duplicates
        .toList()
      ..shuffle();
    
    debugPrint('📚 Found ${otherWordsFromDataset.length} other words from dataset');
    
    // Add wrong options from other dataset entries
    // Use the words as-is from other rows (no prefix modification needed)
    for (final otherWord in otherWordsFromDataset) {
      if (options.length >= 4) break;
      
      // Use the word directly from the dataset (other row/cell)
      final wrongOption = otherWord;
      
      // Make sure it's different from correct answer and not already in options
      if (wrongOption.toLowerCase() != correctAnswer.toLowerCase() &&
          !options.any((opt) => opt.toLowerCase() == wrongOption.toLowerCase())) {
        options.add(wrongOption);
        debugPrint('   Added wrong option: "$wrongOption"');
      }
    }
    
    // Ensure we have at least 2 options (correct + at least 1 wrong)
    if (options.length < 2) {
      debugPrint('⚠️ Not enough options generated for: $bisaya (only ${options.length} options)');
      return null;
    }
    
    debugPrint('✅ Generated ${options.length} options: $options');
    
    // If we still don't have enough options, fill with variations
    // But only if we have at least 2 options (correct + 1 wrong)
    if (options.length < 4 && options.length >= 2) {
      // Try to add one more variation if possible
      String? variation;
      if (prefix == 'mo' && detectedBaseWord.isNotEmpty) {
        variation = 'mag$detectedBaseWord';
      } else if (prefix == 'mag' && detectedBaseWord.isNotEmpty) {
        variation = 'mo$detectedBaseWord';
      } else if (prefix == 'nag' && detectedBaseWord.isNotEmpty) {
        variation = 'gi$detectedBaseWord';
      } else if (prefix == 'gi' && detectedBaseWord.isNotEmpty) {
        variation = 'nag$detectedBaseWord';
      } else if (prefix != null && detectedBaseWord.isNotEmpty) {
        // Try base form without prefix
        variation = detectedBaseWord;
      }
      
      if (variation != null &&
          variation.isNotEmpty) {
        final variationLower = variation.toLowerCase();
        if (variationLower != correctAnswer.toLowerCase() &&
            !options.any((opt) => opt.toLowerCase() == variationLower)) {
          options.add(variation);
        }
      }
    }
    
    // Ensure we have at least 2 options (correct + at least 1 wrong)
    if (options.length < 2) {
      debugPrint('⚠️ Not enough options generated for: $bisaya');
      return null;
    }
    
    // Shuffle options but verify correct answer is still there
    options.shuffle();
    
    // Verify correct answer is still in options after shuffle
    final correctIndex = options.indexOf(correctAnswer);
    if (correctIndex == -1) {
      // This should never happen, but if it does, add it back
      debugPrint('⚠️ ERROR: Correct answer "$correctAnswer" not found in options after shuffle!');
      debugPrint('   Options before shuffle: $options');
      debugPrint('   Adding correct answer back...');
      options.insert(0, correctAnswer);
    } else {
      debugPrint('✅ Correct answer "$correctAnswer" found at index $correctIndex after shuffle');
    }
    
    // Final validation
    if (!options.contains(correctAnswer)) {
      debugPrint('❌ CRITICAL: Correct answer still not in options!');
      return null;
    }
    
    debugPrint('📋 Final exercise:');
    debugPrint('   Sentence: "$sentence"');
    debugPrint('   Correct answer: "$correctAnswer"');
    debugPrint('   Options: $options');
    
    return {
      'sentence': sentence,
      'correctAnswer': correctAnswer,
      'options': options,
      'feedback': 'Maayo! Ang "$correctAnswer" mao ang hustong tubag.',
      'translation': '', // No translation, Bisaya only
    };
  }
  
  // Helper to check if character is a letter
  bool _isLetter(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
           (code >= 97 && code <= 122) || // a-z
           (code >= 192 && code <= 255); // Extended Latin (for accented characters)
  }

  /// Generate comprehensive vocabulary practice from a dataset entry
  Map<String, dynamic>? _generateVocabularyPractice(Map<String, dynamic> metadata) {
    try {
      final bisaya = (metadata['bisaya'] as String? ?? '').trim();
      final english = (metadata['english'] as String? ?? '').trim();
      final tagalog = (metadata['tagalog'] as String? ?? '').trim();
      final partOfSpeech = (metadata['partOfSpeech'] as String? ?? '').trim();
      final pronunciation = (metadata['pronunciation'] as String? ?? '').trim();
      final category = (metadata['category'] as String? ?? '').trim();
      
      if (bisaya.isEmpty || english.isEmpty) {
        return null;
      }
      
      // Get examples for each difficulty level
      final beginnerBisaya = (metadata['beginnerExample'] as String? ?? '').trim();
      final beginnerEnglish = (metadata['beginnerEnglish'] as String? ?? '').trim();
      final intermediateBisaya = (metadata['intermediateExample'] as String? ?? '').trim();
      final intermediateEnglish = (metadata['intermediateEnglish'] as String? ?? '').trim();
      final advancedBisaya = (metadata['advancedExample'] as String? ?? '').trim();
      final advancedEnglish = (metadata['advancedEnglish'] as String? ?? '').trim();
      
      // Generate exercises for each level
      final beginnerExercise = _createExerciseFromSentence(
        beginnerBisaya, 
        beginnerEnglish, 
        bisaya, 
        'Beginner'
      );
      final intermediateExercise = _createExerciseFromSentence(
        intermediateBisaya, 
        intermediateEnglish, 
        bisaya, 
        'Intermediate'
      );
      final advancedExercise = _createExerciseFromSentence(
        advancedBisaya, 
        advancedEnglish, 
        bisaya, 
        'Advanced'
      );
      
      // Only return if at least one exercise is valid
      if (beginnerExercise == null && intermediateExercise == null && advancedExercise == null) {
        return null;
      }
      
      return {
        'word': bisaya,
        'english': english,
        'tagalog': tagalog,
        'partOfSpeech': partOfSpeech,
        'pronunciation': pronunciation,
        'category': category,
        'beginner': beginnerExercise,
        'intermediate': intermediateExercise,
        'advanced': advancedExercise,
      };
    } catch (e) {
      debugPrint('❌ Error generating vocabulary practice: $e');
      return null;
    }
  }

  /// Create a fill-in-the-blank exercise from a sentence
  Map<String, dynamic>? _createExerciseFromSentence(
    String bisayaSentence,
    String englishTranslation,
    String targetWord,
    String level,
  ) {
    if (bisayaSentence.isEmpty || targetWord.isEmpty) {
      return null;
    }
    
    // Find the word in the sentence (handle inflections)
    String sentence = bisayaSentence;
    String correctAnswer = targetWord;
    final wordLower = targetWord.toLowerCase().trim();
    final sentenceLower = sentence.toLowerCase();
    
    // Try to find the word or its inflected forms
    final wordForms = [
      targetWord,
      wordLower,
      'mo$wordLower',
      'mag$wordLower',
      'nag$wordLower',
      'gi$wordLower',
      'ka$wordLower',
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
          correctAnswer = foundForm;
          break;
        }
        index = sentenceLower.indexOf(formLower, index + 1);
      }
      if (foundIndex != -1) break;
    }
    
    if (foundIndex == -1) {
      return null; // Word not found in sentence
    }
    
    // Replace word with blank
    sentence = '${sentence.substring(0, foundIndex)}_____${sentence.substring(foundIndex + foundLength)}';
    
    // Generate 4 answer choices
    final allEntries = _datasetService.getAllEntries();
    final options = <String>[correctAnswer];
    
    // Get other words from dataset
    final otherWords = allEntries
        .where((e) {
          final entryBisaya = (e['bisaya'] as String? ?? '').trim();
          return entryBisaya.isNotEmpty &&
                 entryBisaya.toLowerCase() != targetWord.toLowerCase() &&
                 entryBisaya.toLowerCase() != correctAnswer.toLowerCase();
        })
        .map((e) => (e['bisaya'] as String? ?? '').trim())
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList()
      ..shuffle();
    
    // Add wrong options
    for (final otherWord in otherWords) {
      if (options.length >= 4) break;
      if (otherWord.toLowerCase() != correctAnswer.toLowerCase() &&
          !options.any((opt) => opt.toLowerCase() == otherWord.toLowerCase())) {
        options.add(otherWord);
      }
    }
    
    // Ensure we have 4 options
    while (options.length < 4 && otherWords.isNotEmpty) {
      final word = otherWords.removeAt(0);
      if (word.toLowerCase() != correctAnswer.toLowerCase() &&
          !options.any((opt) => opt.toLowerCase() == word.toLowerCase())) {
        options.add(word);
      }
    }
    
    if (options.length < 2) {
      return null;
    }
    
    // Shuffle options
    options.shuffle();
    
    return {
      'sentence': sentence,
      'originalSentence': bisayaSentence,
      'englishTranslation': englishTranslation,
      'options': options,
      'correctAnswer': correctAnswer,
      'correctIndex': options.indexOf(correctAnswer),
    };
  }

  /// COMMENTED OUT: Create a basic fill-in-blank exercise as fallback with diverse sentences
  /*
  Map<String, dynamic> _createBasicFillInBlank(String word, String meaning, String partOfSpeech) {
    final isVerb = partOfSpeech.toLowerCase().contains('verb');
    final isNoun = partOfSpeech.toLowerCase().contains('noun');
    
    if (isVerb) {
      final baseWord = word.toLowerCase();
      final infinitive = baseWord.startsWith('mo') ? baseWord : 'mo$baseWord';
      final pastForm = baseWord.startsWith('gi') ? baseWord : 'gi$baseWord';
      final presentForm = 'nag$baseWord';
      
      // Diverse verb sentence templates
      final verbSentences = [
        'Gusto ko mo_____ ug saging.',
        'Asa ka mo_____?',
        'Nakaon na ba ka ug _____?',
        'Mopalit ko ug _____ karon.',
        'Nag_____ ko ganina.',
        'Gikaon nako ang _____.',
        'Kanus-a ka mo_____?',
        'Dili ko mokaon ug _____.',
      ];
      final random = DateTime.now().millisecondsSinceEpoch % verbSentences.length;
      final sentence = verbSentences[random];
      
      // Determine correct answer based on sentence
      String correctAnswer;
      if (sentence.contains('mo_____') || sentence.contains('mokaon') || sentence.contains('mopalit')) {
        correctAnswer = infinitive;
      } else if (sentence.contains('Nag_____') || sentence.contains('nag_____')) {
        correctAnswer = presentForm;
      } else if (sentence.contains('Gikaon') || sentence.contains('gikaon')) {
        correctAnswer = pastForm;
      } else {
        correctAnswer = infinitive;
      }
      
      return {
        'sentence': sentence,
        'correctAnswer': correctAnswer,
        'options': [correctAnswer, infinitive, pastForm, presentForm]..shuffle(),
        'feedback': 'Great! \'$correctAnswer\' is the correct form for this sentence.',
        'translation': _getTranslationForSentence(sentence, meaning),
      };
    } else if (isNoun) {
      // Diverse noun sentence templates
      final nounSentences = [
        'Gusto ko ug _____.',
        'Naa koy _____.',
        'Asa ang _____?',
        'Kining _____ kay nindot.',
        'Wala koy _____.',
        'Pila ang _____?',
        'Unsa ang _____?',
        'Gipalit nako ang _____.',
      ];
      final random = DateTime.now().millisecondsSinceEpoch % nounSentences.length;
      final sentence = nounSentences[random];
      
      return {
        'sentence': sentence,
        'correctAnswer': word,
        'options': [word, '${word}na', '${word}ko', '${word}ta']..shuffle(),
        'feedback': 'Correct! \'$word\' means \'$meaning\'.',
        'translation': _getTranslationForSentence(sentence, meaning),
      };
    } else {
      // Diverse adjective sentence templates
      final adjSentences = [
        'Ang saging kay _____.',
        'Kining tawo kay _____.',
        'Ang balay kay _____.',
        'Siya kay _____ kaayo.',
        'Nindot kaayo ang _____.',
        'Dako ang _____.',
      ];
      final random = DateTime.now().millisecondsSinceEpoch % adjSentences.length;
      final sentence = adjSentences[random];
      
      return {
        'sentence': sentence,
        'correctAnswer': word,
        'options': [word, '${word}na', '${word}ko', '${word}ta']..shuffle(),
        'feedback': 'Well done! \'$word\' means \'$meaning\'.',
        'translation': _getTranslationForSentence(sentence, meaning),
      };
    }
  }

  /// Get translation for a sentence
  String _getTranslationForSentence(String sentence, String meaning) {
    if (sentence.contains('Gusto ko')) {
      return 'I want $meaning.';
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
      return 'I $meaning earlier.';
    } else if (sentence.contains('Gikaon') || sentence.contains('Gipalit')) {
      return 'I $meaning it.';
    } else if (sentence.contains('kay nindot') || sentence.contains('kay dako')) {
      return 'The $meaning is beautiful/big.';
    } else if (sentence.contains('kaayo')) {
      return 'He/She is very $meaning.';
    } else {
      return 'Translation: $sentence';
    }
  }
  */

  /// Validate answer with STRICT matching - prioritize accuracy
  // ignore: unused_element
  bool _validateAnswer(String userAnswer, String correctAnswer) {
    // Remove all whitespace and normalize
    final normalizedUser = userAnswer.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final normalizedCorrect = correctAnswer.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    
    // 1. Exact match (highest priority)
    if (normalizedUser == normalizedCorrect) {
      debugPrint('✅ Exact match: "$userAnswer" == "$correctAnswer"');
      return true;
    }
    
    // 2. Check for exact word match (handle cases where answer might have extra characters)
    // Remove common suffixes/prefixes that don't affect meaning
    final userBase = _getBaseWord(normalizedUser);
    final correctBase = _getBaseWord(normalizedCorrect);
    
    if (userBase == correctBase && userBase.isNotEmpty) {
      debugPrint('✅ Base word match: "$userBase" == "$correctBase"');
      return true;
    }
    
    // 3. Only allow very specific, known Bisaya variations (strict list)
    final strictVariations = {
      'mokaon': ['mokaon', 'moka-on'], // Only allow these exact variations
      'nagkaon': ['nagkaon', 'nagka-on'],
      'gikaon': ['gikaon', 'gika-on'],
      'mopalit': ['mopalit', 'mopal-it'],
      'nagpalit': ['nagpalit', 'nagpal-it'],
      'gipalit': ['gipalit', 'gipal-it'],
      'kaon': ['kaon', 'ka-on'],
      'palit': ['palit', 'pal-it'],
    };
    
    // Check if both words are in the variations map and match
    for (var entry in strictVariations.entries) {
      final baseKey = entry.key;
      if (normalizedCorrect.contains(baseKey) || normalizedUser.contains(baseKey)) {
        // Check if both match any variation of the same base word
        final correctMatches = entry.value.any((v) => normalizedCorrect.contains(v));
        final userMatches = entry.value.any((v) => normalizedUser.contains(v));
        
        if (correctMatches && userMatches) {
          debugPrint('✅ Variation match: "$userAnswer" matches "$correctAnswer"');
          return true;
        }
      }
    }
    
    // 4. Very strict similarity check (95%+ only, for minor typos)
    final similarity = _calculateSimilarity(normalizedUser, normalizedCorrect);
    if (similarity >= 0.95) {
      debugPrint('✅ High similarity (${(similarity * 100).toStringAsFixed(1)}%): "$userAnswer" ~ "$correctAnswer"');
      return true;
    }
    
    debugPrint('❌ No match: "$userAnswer" != "$correctAnswer" (similarity: ${(similarity * 100).toStringAsFixed(1)}%)');
    return false;
  }

  /// Get base word by removing common prefixes
  String _getBaseWord(String word) {
    // Remove common Bisaya verb prefixes
    final prefixes = ['mo', 'nag', 'gi', 'mag', 'na', 'ka'];
    String base = word;
    
    for (final prefix in prefixes) {
      if (base.startsWith(prefix) && base.length > prefix.length) {
        base = base.substring(prefix.length);
        break;
      }
    }
    
    return base;
  }

  /// Calculate string similarity (simple Levenshtein-based)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.isEmpty) return 1.0;
    
    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }

  /* COMMENTED OUT - Old practice mode methods, replaced by quiz
  void _selectAnswer(String answer) {
    if (_isAnswered) return;

    final currentExercise = _practiceExercises[_currentExerciseIndex];
    final fillInBlank = currentExercise['fillInBlank'] as Map<String, dynamic>;
    final correctAnswer = fillInBlank['correctAnswer'] as String;
    final word = currentExercise['word'] as String;
    
    // Calculate time spent
    final timeSpent = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;
    
    // Validate answer with fuzzy matching
    final isCorrect = _validateAnswer(answer, correctAnswer);
    
    // Record accuracy
    _accuracyService.recordPracticeExercise(
      word: word,
      isCorrect: isCorrect,
      exerciseType: 'fill_in_blank',
      timeSpent: timeSpent,
    ).catchError((e) {
      debugPrint('Error recording practice exercise: $e');
    });

    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _totalAnswered++;
      
      if (isCorrect) {
        _score++;
      }
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _practiceExercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _selectedAnswer = null;
        _isAnswered = false;
        _exerciseStartTime = DateTime.now(); // Reset timer for next exercise
      });
    } else {
      // Show completion dialog
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final percentage = (_score / _totalAnswered * 100).round();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Practice Complete!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $_score / $_totalAnswered',
              style: GoogleFonts.poppins(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: $percentage%',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: percentage >= 70 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentExerciseIndex = 0;
                _selectedAnswer = null;
                _isAnswered = false;
                _score = 0;
                _totalAnswered = 0;
              });
              _loadPracticeExercises(forceReload: true);
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  */ // END COMMENTED OUT - Old practice mode methods

  @override
  Widget build(BuildContext context) {
    const Color kPrimary = Color(0xFF3B5FAE);
    const Color kAccent = Color(0xFF2666B4);
    final Color backgroundColor = widget.isDarkMode ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = widget.isDarkMode ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : const Color(0xFF071B34);

    // Playful gradient header
    Widget buildPlayfulHeader() {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
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
                  onTap: () {
                    if (_selectedProgressiveLevel != -1) {
                      setState(() {
                        _selectedProgressiveLevel = -1;
                        _currentLevelQuestions = null;
                        _currentLevelQuestionIndex = 0;
                      });
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
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
                          const Text('🎮', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(
                            'Fill in the Blank',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Have fun learning Bisaya!',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onToggleDarkMode(!widget.isDarkMode),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Score display with playful styling
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
                  const Text('⭐', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Score: $_progressiveCorrectCount / $_progressiveTotalCount',
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

    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          body: _useProgressiveMode
              ? Column(
                  children: [
                    buildPlayfulHeader(),
                    Expanded(
                      child: _buildProgressiveView(textColor, cardColor, kAccent, backgroundColor),
                    ),
                  ],
                )
              : Column(
                  children: [
                    buildPlayfulHeader(),
                    Expanded(
                      child: _quizQuestions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text('🤔', style: TextStyle(fontSize: 48)),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No quiz questions available',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The dataset may not be loaded yet.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _loadQuizQuestions(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Load Questions'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildQuizView(textColor, cardColor, kAccent, backgroundColor),
                    ),
                  ],
                ),
        ),
        // Confetti overlay
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.2,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
                Colors.pink,
                Colors.cyan,
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the progressive learning view
  Widget _buildProgressiveView(
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    // Show loading while data loads
    if (_progressiveLoading || _currentProgression == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '🎮 Loading levels...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparing your fun learning adventure!',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final levels = _currentProgression!['levels'] as List<dynamic>;
    final unlockedLevel = _currentProgression!['unlockedLevel'] as int? ?? 1;

    // If a level is selected, show the level content
    if (_selectedProgressiveLevel != -1) {
      // Check if level is locked
      if (_selectedProgressiveLevel > unlockedLevel) {
        return _buildLockedLevelView(textColor, cardColor, accentColor);
      }
      return _buildProgressiveLevelTab(
        _selectedProgressiveLevel,
        textColor,
        cardColor,
        accentColor,
        backgroundColor,
      );
    }

    // Playful level icons and emojis
    final levelEmojis = ['🌱', '🌿', '🌳', '🌟', '⭐', '🏆'];
    final levelColors = [
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFFEC4899), // Pink
    ];

    // Otherwise, show the level selection cards
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Fun intro text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  const Color(0xFFA855F7).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Level!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Complete each level to unlock the next',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(6, (index) {
            final levelNum = index + 1;
            final isLocked = levelNum > unlockedLevel;
            final level = levels[index] as Map<String, dynamic>;
            final variant = level['variant'] as String;
            final levelColor = levelColors[index];
            final levelEmoji = levelEmojis[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: isLocked
                    ? null
                    : () {
                        _startProgressiveLevel(levelNum);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: isLocked
                        ? LinearGradient(
                            colors: [Colors.grey.shade300, Colors.grey.shade200],
                          )
                        : LinearGradient(
                            colors: [cardColor, cardColor],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLocked ? Colors.grey.shade400 : levelColor,
                      width: 2,
                    ),
                    boxShadow: isLocked
                        ? null
                        : [
                            BoxShadow(
                              color: levelColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // Level badge with emoji
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: isLocked
                              ? null
                              : LinearGradient(
                                  colors: [levelColor, levelColor.withValues(alpha: 0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: isLocked ? Colors.grey.shade400 : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isLocked
                              ? null
                              : [
                                  BoxShadow(
                                    color: levelColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: isLocked
                              ? const Icon(Icons.lock_rounded, size: 28, color: Colors.white)
                              : Text(levelEmoji, style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Level $levelNum',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isLocked ? Colors.grey.shade600 : textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: levelColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      variant,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: levelColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLocked
                                  ? '🔒 Complete Level ${levelNum - 1} to unlock'
                                  : '✨ Ready to play!',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isLocked
                                    ? Colors.grey.shade500
                                    : textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLocked)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: levelColor,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build locked level message
  Widget _buildLockedLevelView(
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          // Playful locked animation
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.2),
                  Colors.orange.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Text('🔐', style: TextStyle(fontSize: 80)),
          ),
          const SizedBox(height: 32),
          Text(
            'Oops! Level Locked!',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('💪', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  'Get a perfect score on the previous level to unlock this one!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedProgressiveLevel = -1;
              });
            },
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Levels'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build progressive level tab (quiz-like format)
  Widget _buildProgressiveLevelTab(
    int levelNum,
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    // Use current session question list and index
    final questions = _currentLevelQuestions;
    if (questions == null || questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'No questions available for this level',
              style: GoogleFonts.poppins(color: textColor),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedProgressiveLevel = -1;
                });
              },
              child: const Text('Back to Levels'),
            ),
          ],
        ),
      );
    }

    final currentIndex = _currentLevelQuestionIndex.clamp(0, questions.length - 1);
    final level = questions[currentIndex];
    final variant = level['variant'] as String? ?? 'Progressive';
    final englishTranslation = level['englishTranslation'] as String? ?? '';
    final fillInBlank = level['fillInBlank'] as String? ?? '';
    final correctAnswer = level['correctAnswer'] as String? ?? '';
    final choices = (level['choices'] as List<dynamic>?)?.cast<String>().toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button and Mode Toggle
          Row(
            children: [
              // Back button to level selection
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedProgressiveLevel = -1;
                    _currentLevelQuestions = null;
                    _currentLevelQuestionIndex = 0;
                  });
                },
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level $levelNum / 6',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _progressiveAnswered
                        ? (_progressiveSelectedAnswer?.toLowerCase().trim() ==
                                correctAnswer.toLowerCase().trim()
                            ? 'Correct!'
                            : 'Incorrect')
                        : '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _progressiveSelectedAnswer?.toLowerCase().trim() ==
                              correctAnswer.toLowerCase().trim()
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Q${_currentLevelQuestionIndex + 1}/${(_currentLevelQuestions?.length ?? 0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: levelNum / 6,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
          const SizedBox(height: 24),

          // Level Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Level $levelNum - $variant',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Fill in the Blank Exercise
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fill in the Blank',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fillInBlank,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  englishTranslation,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Answer Choices
          ...List.generate(choices.length, (index) {
            final choice = choices[index];
            final isSelected = _progressiveSelectedAnswer == choice;
            final isCorrectChoice =
                choice.toLowerCase().trim() == correctAnswer.toLowerCase().trim();

            Color choiceColor = cardColor;
            Color choiceBorder = accentColor.withOpacity(0.3);

            if (_progressiveAnswered) {
              if (isCorrectChoice) {
                choiceColor = Colors.green.withOpacity(0.2);
                choiceBorder = Colors.green;
              } else if (isSelected && !isCorrectChoice) {
                choiceColor = Colors.red.withOpacity(0.2);
                choiceBorder = Colors.red;
              }
            } else if (isSelected) {
              choiceColor = accentColor.withOpacity(0.2);
              choiceBorder = accentColor;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap:
                    _progressiveAnswered ? null : () => _selectProgressiveAnswer(choice),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: choiceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: choiceBorder, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          choice,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (_progressiveAnswered)
                        Icon(
                          isCorrectChoice ? Icons.check : Icons.close,
                          color: isCorrectChoice ? Colors.green : Colors.red,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // Next button removed — progression is now automatic after answering
        ],
      ),
    );
  }

  /// Build the quiz view with tabs for difficulty levels
  Widget _buildQuizView(
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    // If a difficulty is selected, show the quiz content
    if (_selectedDifficulty != -1) {
      return _buildQuizTab(_selectedDifficulty, textColor, cardColor, accentColor, backgroundColor);
    }
    
    // Otherwise, show the difficulty selection cards
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.quiz,
            size: 80,
            color: accentColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Your Difficulty',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Select a difficulty level to start your quiz',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Beginner Card
          _buildDifficultyCard(
            'Beginner',
            0,
            Icons.school,
            'Start with basic vocabulary and simple sentences',
            textColor,
            cardColor,
            accentColor,
          ),
          
          const SizedBox(height: 24),
          
          // Intermediate Card
          _buildDifficultyCard(
            'Intermediate',
            1,
            Icons.trending_up,
            'Challenge yourself with more complex sentences',
            textColor,
            cardColor,
            accentColor,
          ),
          
          const SizedBox(height: 24),
          
          // Advanced Card
          _buildDifficultyCard(
            'Advanced',
            2,
            Icons.star,
            'Master advanced vocabulary and complex structures',
            textColor,
            cardColor,
            accentColor,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Build a difficulty selection card (like learning center format)
  Widget _buildDifficultyCard(
    String label,
    int difficultyIndex,
    IconData icon,
    String description,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficulty = difficultyIndex;
          _showResults = false;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 70,
              color: accentColor,
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build quiz tab for a specific difficulty level
  Widget _buildQuizTab(
    int difficultyIndex,
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    final questions = _quizQuestions[difficultyIndex] ?? [];
    final currentIndex = _currentQuestionIndex[difficultyIndex] ?? 0;
    final selectedAnswers = _selectedAnswers[difficultyIndex] ?? {};
    final score = _scores[difficultyIndex] ?? 0;
    final totalAnswered = _totalAnsweredQuiz[difficultyIndex] ?? 0;
    
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions available for this level',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    if (_showResults && currentIndex >= questions.length) {
      return _buildQuizResults(difficultyIndex, textColor, cardColor, accentColor);
    }

    if (currentIndex >= questions.length) {
      return _buildQuizResults(difficultyIndex, textColor, cardColor, accentColor);
    }

    final question = questions[currentIndex];
    final exercise = question['exercise'] as Map<String, dynamic>;
    final questionKey = 'q$currentIndex';
    final selectedAnswer = selectedAnswers[questionKey];
    final isAnswered = selectedAnswer != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to Selection Button
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDifficulty = -1;
                    _showResults = false;
                  });
                },
                icon: Icon(Icons.arrow_back, color: accentColor),
                tooltip: 'Back to Selection',
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          // Progress and Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentIndex + 1} of ${questions.length}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              Text(
                'Score: $score / $totalAnswered',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (currentIndex + 1) / questions.length,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
          const SizedBox(height: 24),

          // Word Information Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['word'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                if ((question['pronunciation'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '[${question['pronunciation']}]',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow('English', question['english'] as String, textColor),
                    ),
                    const SizedBox(width: 12),
                    if ((question['tagalog'] as String? ?? '').isNotEmpty)
                      Expanded(
                        child: _buildInfoRow('Tagalog', question['tagalog'] as String, textColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question['level'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  exercise['sentence'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((exercise['englishTranslation'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise['englishTranslation'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Answer Options
                ...List.generate((exercise['options'] as List).length, (index) {
                  final option = (exercise['options'] as List)[index] as String;
                  final correctAnswer = exercise['correctAnswer'] as String;
                  final isSelected = selectedAnswer == option;
                  final isCorrect = option.toLowerCase() == correctAnswer.toLowerCase();
                  
                  Color buttonColor = cardColor;
                  Color textColorButton = textColor;
                  
                  if (isAnswered) {
                    if (isCorrect) {
                      buttonColor = Colors.green;
                      textColorButton = Colors.white;
                    } else if (isSelected && !isCorrect) {
                      buttonColor = Colors.red;
                      textColorButton = Colors.white;
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: isAnswered
                          ? null
                          : () {
                              final isCorrectAnswer = option.toLowerCase() == correctAnswer.toLowerCase();
                              setState(() {
                                if (_selectedAnswers[difficultyIndex] == null) {
                                  _selectedAnswers[difficultyIndex] = {};
                                }
                                _selectedAnswers[difficultyIndex]![questionKey] = option;
                                _totalAnsweredQuiz[difficultyIndex] = (_totalAnsweredQuiz[difficultyIndex] ?? 0) + 1;
                                if (isCorrectAnswer) {
                                  _scores[difficultyIndex] = (_scores[difficultyIndex] ?? 0) + 1;
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: textColorButton,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: isSelected
                            ? BorderSide(
                                color: isCorrect ? Colors.green : Colors.red,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            option,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isAnswered && isSelected)
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                
                // Next/Finish Button
                if (isAnswered) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (currentIndex < questions.length - 1) {
                            _currentQuestionIndex[difficultyIndex] = currentIndex + 1;
                          } else {
                            _showResults = true;
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        currentIndex < questions.length - 1 ? 'Next Question' : 'View Results',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build quiz results view
  Widget _buildQuizResults(
    int difficultyIndex,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    final score = _scores[difficultyIndex] ?? 0;
    final totalAnswered = _totalAnsweredQuiz[difficultyIndex] ?? 0;
    final percentage = totalAnswered > 0 ? (score / totalAnswered * 100).round() : 0;
    final levelNames = ['Beginner', 'Intermediate', 'Advanced'];
    final levelName = levelNames[difficultyIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$levelName Quiz Complete!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$score / $totalAnswered',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentQuestionIndex[difficultyIndex] = 0;
                      _selectedAnswers[difficultyIndex] = {};
                      _scores[difficultyIndex] = 0;
                      _totalAnsweredQuiz[difficultyIndex] = 0;
                      _showResults = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retake Quiz'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDifficulty = -1;
                    _showResults = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: BorderSide(color: accentColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Selection'),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _loadQuizQuestions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: BorderSide(color: accentColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('New Random Quiz'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the vocabulary practice view (OLD - no longer used, replaced by quiz)
  /* COMMENTED OUT - Replaced by quiz view
  Widget _buildVocabularyPracticeView(
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    final practice = _vocabularyPractice!;
    final word = practice['word'] as String;
    final english = practice['english'] as String;
    final tagalog = practice['tagalog'] as String;
    final partOfSpeech = practice['partOfSpeech'] as String;
    final pronunciation = practice['pronunciation'] as String;
    final category = practice['category'] as String;
    final beginner = practice['beginner'] as Map<String, dynamic>?;
    final intermediate = practice['intermediate'] as Map<String, dynamic>?;
    final advanced = practice['advanced'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word Information Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                if (pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '[$pronunciation]',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: textColor.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow('English', english, textColor),
                    ),
                    const SizedBox(width: 16),
                    if (tagalog.isNotEmpty)
                      Expanded(
                        child: _buildInfoRow('Tagalog', tagalog, textColor),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (partOfSpeech.isNotEmpty)
                      Expanded(
                        child: _buildInfoRow('Part of Speech', partOfSpeech, textColor),
                      ),
                    const SizedBox(width: 16),
                    if (category.isNotEmpty)
                      Expanded(
                        child: _buildInfoRow('Category', category, textColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Difficulty Level Tabs
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: accentColor,
                  unselectedLabelColor: textColor.withValues(alpha: 0.6),
                  indicatorColor: accentColor,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Beginner'),
                    Tab(text: 'Intermediate'),
                    Tab(text: 'Advanced'),
                  ],
                ),
                SizedBox(
                  height: 500,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Beginner Tab
                      beginner != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: _buildExerciseCard(
                                'Beginner',
                                beginner,
                                'beginner',
                                textColor,
                                cardColor,
                                accentColor,
                              ),
                            )
                          : Center(
                              child: Text(
                                'No beginner exercise available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                      // Intermediate Tab
                      intermediate != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: _buildExerciseCard(
                                'Intermediate',
                                intermediate,
                                'intermediate',
                                textColor,
                                cardColor,
                                accentColor,
                              ),
                            )
                          : Center(
                              child: Text(
                                'No intermediate exercise available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                      // Advanced Tab
                      advanced != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: _buildExerciseCard(
                                'Advanced',
                                advanced,
                                'advanced',
                                textColor,
                                cardColor,
                                accentColor,
                              ),
                            )
                          : Center(
                              child: Text(
                                'No advanced exercise available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Answer Key Button
          ElevatedButton(
            onPressed: () {
              setState(() => _showAnswerKey = !_showAnswerKey);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _showAnswerKey ? 'Hide Answer Key' : 'Show Answer Key',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Answer Key Section
          if (_showAnswerKey) ...[
            const SizedBox(height: 24),
            _buildAnswerKey(
              beginner,
              intermediate,
              advanced,
              textColor,
              cardColor,
              accentColor,
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Load New Practice Button
          OutlinedButton(
            onPressed: _loadVocabularyPractice,
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              side: BorderSide(color: accentColor, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Load New Vocabulary Practice',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  */ // END COMMENTED OUT - Old vocabulary practice view

  Widget _buildInfoRow(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: textColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /* COMMENTED OUT - Old exercise card method, replaced by quiz
  Widget _buildExerciseCard(
    String level,
    Map<String, dynamic> exercise,
    String levelKey,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    final sentence = exercise['sentence'] as String;
    final options = exercise['options'] as List<dynamic>;
    final correctAnswer = exercise['correctAnswer'] as String;
    final englishTranslation = exercise['englishTranslation'] as String? ?? '';
    final selectedAnswer = _selectedAnswers[levelKey];
    final isCorrect = selectedAnswer != null && 
                      selectedAnswer.toLowerCase() == correctAnswer.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedAnswer != null
              ? (isCorrect ? Colors.green : Colors.red)
              : accentColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  level,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              if (selectedAnswer != null) ...[
                const Spacer(),
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 24,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            sentence,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (englishTranslation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              englishTranslation,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...List.generate(options.length, (index) {
            final option = options[index] as String;
            final isSelected = selectedAnswer == option;
            final isCorrectOption = option.toLowerCase() == correctAnswer.toLowerCase();
            
            Color buttonColor = cardColor;
            Color textColorButton = textColor;
            
            if (selectedAnswer != null) {
              if (isCorrectOption) {
                buttonColor = Colors.green;
                textColorButton = Colors.white;
              } else if (isSelected && !isCorrectOption) {
                buttonColor = Colors.red;
                textColorButton = Colors.white;
              }
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: selectedAnswer == null
                    ? () {
                        setState(() {
                          _selectedAnswers[levelKey] = option;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: textColorButton,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: isSelected
                      ? BorderSide(
                          color: isCorrectOption ? Colors.green : Colors.red,
                          width: 2,
                        )
                      : null,
                ),
                child: Text(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  */ // END COMMENTED OUT - Old exercise card method

  /* COMMENTED OUT - Old answer key method, replaced by quiz
  Widget _buildAnswerKey(
    Map<String, dynamic>? beginner,
    Map<String, dynamic>? intermediate,
    Map<String, dynamic>? advanced,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Answer Key',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 20),
          if (beginner != null)
            _buildAnswerKeyItem(
              'Beginner',
              beginner['correctAnswer'] as String,
              textColor,
            ),
          if (intermediate != null)
            _buildAnswerKeyItem(
              'Intermediate',
              intermediate['correctAnswer'] as String,
              textColor,
            ),
          if (advanced != null)
            _buildAnswerKeyItem(
              'Advanced',
              advanced['correctAnswer'] as String,
              textColor,
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerKeyItem(String level, String answer, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              level,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answer,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  */ // END COMMENTED OUT - Old answer key item method

  Future<int> _loadUnlockedLevelFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kUnlockedLevelKey) ?? 1;
    } catch (e) {
      debugPrint('⚠️ Unable to load unlocked level from storage: $e');
      return 1;
    }
  }

  Future<void> _persistUnlockedLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUnlockedLevelKey, level.clamp(1, 6));
    } catch (e) {
      debugPrint('⚠️ Unable to persist unlocked level: $e');
    }
  }

  /// Load progressive learning progression
  Future<void> _loadProgressiveProgression() async {
    // Prevent duplicate loading
    if (_progressiveLoadingAttempted) return;

    if (!mounted) return;
    setState(() {
      _progressiveLoading = true;
      _progressiveLoadingAttempted = true;
    });

    try {
      debugPrint('🟡 [_loadProgressiveProgression] Starting dataset load...');
      // Load dataset synchronously if available
      await _datasetService.loadDataset(forceReload: false);
      debugPrint('🟢 [_loadProgressiveProgression] Dataset loaded successfully');

      final allEntries = _datasetService.getAllEntries();
      debugPrint('🟢 [_loadProgressiveProgression] Retrieved ${allEntries.length} entries');

      if (allEntries.isEmpty) {
        debugPrint('🔴 [_loadProgressiveProgression] Dataset is empty!');
        if (mounted) {
          setState(() => _progressiveLoading = false);
        }
        return;
      }

      if (mounted) {
        try {
          debugPrint('🟡 [_loadProgressiveProgression] Generating progression from first entry...');
          final firstEntry = allEntries[0];
          debugPrint('   Entry word: ${firstEntry['bisaya'] ?? 'NULL'}');
          debugPrint('   Entry english: ${firstEntry['english'] ?? 'NULL'}');

          final progression = _progressiveLearningService.generateSixLevelProgression(firstEntry);
          debugPrint('🟢 [_loadProgressiveProgression] Progression generated (result: ${progression != null ? 'success' : 'null'})');

          if (progression != null && mounted) {
            // Merge persisted unlocked level with freshly generated progression
            final storedUnlocked = await _loadUnlockedLevelFromStorage();
            final currentUnlocked = (progression['unlockedLevel'] as int?) ?? 1;
            final mergedUnlocked = storedUnlocked > currentUnlocked ? storedUnlocked : currentUnlocked;
            progression['unlockedLevel'] = mergedUnlocked;

            final levels = progression['levels'] as List<dynamic>? ?? [];
            for (var i = 0; i < levels.length; i++) {
              final levelNum = i + 1;
              final levelMap = levels[i] as Map<String, dynamic>;
              levelMap['isLocked'] = levelNum > mergedUnlocked;
            }

            setState(() {
              _currentProgression = progression;
              _progressiveLoading = false;
            });
            debugPrint('🟢 [_loadProgressiveProgression] Progression set in state');
          } else if (mounted) {
            debugPrint('🔴 [_loadProgressiveProgression] Progression was null');
            setState(() => _progressiveLoading = false);
          }
        } catch (genErr, genSt) {
          debugPrint('🔴 [_loadProgressiveProgression] Error during progression generation: $genErr');
          debugPrint('   Stack: $genSt');
          if (mounted) {
            setState(() => _progressiveLoading = false);
          }
          rethrow;
        }
      } else if (mounted) {
        setState(() {
          _progressiveLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔴 [_loadProgressiveProgression] Top-level error: $e');
      if (mounted) {
        setState(() {
          _progressiveLoading = false;
        });
      }
      rethrow; // Re-throw so the initState try/catch can capture and show the dialog
    }
  }

  /// Start a progressive level session by generating up to 10 random questions
  Future<void> _startProgressiveLevel(int levelNum) async {
    // Reset session state
    setState(() {
      _selectedProgressiveLevel = levelNum;
      _progressiveSelectedAnswer = null;
      _progressiveAnswered = false;
      _progressiveCorrectCount = 0;
      _progressiveTotalCount = 0;
      _currentLevelQuestionIndex = 0;
      _currentLevelQuestions = null;
    });

    // If we already cached the list, assign it
    if (_progressiveLevelQuestionsCache.containsKey(levelNum)) {
      setState(() {
        _currentLevelQuestions = _progressiveLevelQuestionsCache[levelNum];
      });
      return;
    }

    // Build candidates by scanning dataset and extracting exercises directly
    final candidates = <Map<String, dynamic>>[];
    try {
      await _datasetService.loadDataset(forceReload: false);
      final allEntries = _datasetService.getAllEntries();

      for (final entry in allEntries) {
        // Use the progressive learning service to generate explicit six-level variants
        final progression = _progressiveLearningService.generateSixLevelProgression(entry);
        if (progression == null) continue;

        final levels = progression['levels'] as List<dynamic>?;
        if (levels == null || levels.length < levelNum) continue;

        final levelMap = levels[levelNum - 1] as Map<String, dynamic>?;
        if (levelMap == null) continue;

        // Normalize fields from the progressive level map into the expected item shape
        final item = <String, dynamic>{
          'level': levelNum,
          'variant': levelMap['variant'] as String? ?? 'Level $levelNum',
          'bisayaSentence': levelMap['bisayaSentence'] as String? ?? levelMap['fillInBlank'] as String? ?? '',
          'englishTranslation': levelMap['englishTranslation'] as String? ?? progression['english'] as String? ?? '',
          'tagalogTranslation': progression['tagalog'] as String? ?? '',
          'fillInBlank': levelMap['fillInBlank'] as String? ?? '',
          'correctAnswer': levelMap['correctAnswer'] as String? ?? '',
          'choices': (levelMap['choices'] as List<dynamic>?)?.cast<String>().toList() ?? [],
          'sourceWord': progression['word'] as String? ?? '',
          'isLocked': false,
        };

        candidates.add(item);
      }

      // Shuffle and take up to 10
      candidates.shuffle();
      final selected = candidates.take(10).toList();

      // Cache and set current session list
      _progressiveLevelQuestionsCache[levelNum] = selected;
      setState(() {
        _currentLevelQuestions = selected;
      });
    } catch (e) {
      debugPrint('❌ Error generating questions for level $levelNum: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading level questions: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  /// Select answer in progressive mode
  void _selectProgressiveAnswer(String answer) {
    if (_progressiveAnswered) return;

    // Determine correct answer from current session questions if available
    String correctAnswer = '';
    if (_currentLevelQuestions != null && _currentLevelQuestions!.isNotEmpty) {
      final idx = _currentLevelQuestionIndex.clamp(0, _currentLevelQuestions!.length - 1);
      final q = _currentLevelQuestions![idx];
      correctAnswer = (q['correctAnswer'] as String?) ?? (q['correctAnswer'.toString()] as String? ?? '');
      if (correctAnswer.isEmpty) {
        // Try alternative key names used elsewhere
        correctAnswer = (q['correct'] as String?) ?? '';
      }
    } else {
      final levels = _currentProgression?['levels'] as List<dynamic>?;
      final currentLevelIndex = _selectedProgressiveLevel - 1;
      final level = levels?[currentLevelIndex] as Map<String, dynamic>?;
      correctAnswer = level?['correctAnswer'] as String? ?? '';
    }

    final isCorrect = answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();

    setState(() {
      _progressiveSelectedAnswer = answer;
      _progressiveAnswered = true;
      _progressiveTotalCount++;
      if (isCorrect) {
        _progressiveCorrectCount++;
      }
    });
    // Automatically advance after a short delay so user sees feedback
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_progressiveAnswered) {
        _progressiveNextLevel();
      }
    });
  }

  /// Handle next level in progressive mode
  void _progressiveNextLevel() {
    // If there are more questions in the current session, advance to next
    final questions = _currentLevelQuestions ?? [];
    if (_currentLevelQuestionIndex < questions.length - 1) {
      setState(() {
        _currentLevelQuestionIndex++;
        _progressiveSelectedAnswer = null;
        _progressiveAnswered = false;
      });
      return;
    }

    // Session finished: compute accurate totals based on session questions
    final totalQuestions = _currentLevelQuestions?.length ?? _progressiveTotalCount;
    final correct = _progressiveCorrectCount;
    final isPerfect = totalQuestions > 0 && correct == totalQuestions;

    // Track quiz completion and check achievements
    _trackQuizCompletion(correct, totalQuestions, isPerfect);

    if (_selectedProgressiveLevel <= 6) {
      // If perfect, unlock next level immediately in data
      if (isPerfect && _currentProgression != null) {
        // Use service to update progression, but also update local map explicitly
        final beforeUnlocked = (_currentProgression!['unlockedLevel'] as int?) ?? 1;
        _progressiveLearningService.unlockNextLevel(_currentProgression!);
        final afterUnlocked = (_currentProgression!['unlockedLevel'] as int?) ?? beforeUnlocked;
        debugPrint('🔓 Unlock check: level $_selectedProgressiveLevel perfect=$isPerfect before=$beforeUnlocked after=$afterUnlocked');
        // Ensure the 'unlockedLevel' and per-level flags are reflected in the map used by UI
        try {
          // The service already advances `unlockedLevel` in `_currentProgression`.
          // Read that value and derive per-level `isLocked` flags from it.
          final newUnlocked = (_currentProgression!['unlockedLevel'] as int?) ?? 1;
          _persistUnlockedLevel(newUnlocked);
          final levels = _currentProgression!['levels'] as List<dynamic>? ?? [];
          for (var i = 0; i < levels.length; i++) {
            final levelNum = i + 1;
            final levelMap = levels[i] as Map<String, dynamic>;
            levelMap['isLocked'] = levelNum > newUnlocked;
          }
        } catch (e) {
          debugPrint('⚠️ Error updating unlocked level locally: $e');
        }
        // celebrate with confetti and ensure UI reflects unlocked level
        _confettiController.play();
        setState(() {});
      }

      // Show dialog summarizing results
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              isPerfect ? 'Congratulations!' : 'Level Complete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Score: $correct / $totalQuestions',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (isPerfect)
                  Text(
                    'Perfect score! You unlocked the next level.',
                    style: GoogleFonts.poppins(color: Colors.green),
                  )
                else
                  Text(
                    'Get a perfect score across all questions to unlock the next level.',
                    style: GoogleFonts.poppins(color: Colors.orange),
                  ),
              ],
            ),
            actions: [
              if (!isPerfect) ...[
                TextButton(
                  onPressed: () {
                    // Retry same level: reset session
                    Navigator.of(ctx).pop();
                    setState(() {
                      _currentLevelQuestionIndex = 0;
                      _progressiveSelectedAnswer = null;
                      _progressiveAnswered = false;
                      _progressiveCorrectCount = 0;
                      _progressiveTotalCount = 0;
                    });
                  },
                  child: Text('Retry', style: GoogleFonts.poppins()),
                ),
              ],
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (isPerfect && _selectedProgressiveLevel < 6) {
                    // Start next level session
                    final next = _selectedProgressiveLevel + 1;
                    // small delay to allow dialog to fully close
                    Future.delayed(const Duration(milliseconds: 150), () {
                      _startProgressiveLevel(next);
                    });
                  } else {
                    // Return to level selection
                    setState(() {
                      _selectedProgressiveLevel = -1;
                      _currentLevelQuestions = null;
                      _currentLevelQuestionIndex = 0;
                      _progressiveSelectedAnswer = null;
                      _progressiveAnswered = false;
                      _progressiveCorrectCount = 0;
                      _progressiveTotalCount = 0;
                    });
                  }
                },
                child: Text(
                  isPerfect && _selectedProgressiveLevel < 6 ? 'Next Level' : 'Close',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildLevelIcon(int levelNum) {
    const iconSize = 28.0;
    const iconColor = Colors.white;

    switch (levelNum) {
      case 1:
        return Tooltip(
          message: 'Foundations',
          child: Icon(Icons.foundation, size: iconSize, color: iconColor),
        );
      case 2:
        return Tooltip(
          message: 'Basics',
          child: Icon(Icons.school, size: iconSize, color: iconColor),
        );
      case 3:
        return Tooltip(
          message: 'Developing',
          child: Icon(Icons.trending_up, size: iconSize, color: iconColor),
        );
      case 4:
        return Tooltip(
          message: 'Skilled',
          child: Icon(Icons.verified, size: iconSize, color: iconColor),
        );
      case 5:
        return Tooltip(
          message: 'Advanced',
          child: Icon(Icons.auto_awesome, size: iconSize, color: iconColor),
        );
      case 6:
        return Tooltip(
          message: 'Mastery',
          child: Icon(Icons.star, size: iconSize, color: iconColor),
        );
      default:
        return Text(
          'L$levelNum',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        );
    }
  }
}

