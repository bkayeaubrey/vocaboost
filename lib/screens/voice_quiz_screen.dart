import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vocaboost/services/quiz_service.dart';

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
  final List<int?> _selectedAnswers = []; // Track all selected answers
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  String? _spokenAnswer;

  // Pronunciation Quiz - Focus on proper pronunciation of Bisaya words
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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    // If already answered incorrectly, allow retry
    if (_answered && _isCorrect) return;
    
    // If answered incorrectly, reset for retry
    if (_answered && !_isCorrect) {
      _retryPronunciation();
    }

    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) {
        debugPrint('onError: $val');
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
        _spokenAnswer = null;
      });

      _speech.listen(
        onResult: (val) {
          setState(() {
            _recognizedText = val.recognizedWords;
          });
        },
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _checkAnswer();
  }

  void _checkAnswer() {
    if (_recognizedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pronounce the word')),
      );
      return;
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correctAnswer'] as String;
    final alternatives = (currentQuestion['alternatives'] as List<dynamic>)
        .map((e) => e.toString().toLowerCase().trim())
        .toList();

    final spokenText = _recognizedText.trim().toLowerCase();
    
    // Check for exact match or close alternatives
    bool isCorrect = spokenText == correctAnswer.toLowerCase() ||
        alternatives.contains(spokenText);
    
    // Additional check: if the spoken text contains the key word (for phrases)
    if (!isCorrect && correctAnswer.contains(' ')) {
      final words = correctAnswer.toLowerCase().split(' ');
      final spokenWords = spokenText.split(' ');
      // Check if all key words are present
      isCorrect = words.every((word) => 
        spokenWords.any((spoken) => spoken.contains(word) || word.contains(spoken))
      );
    }

    setState(() {
      _answered = true;
      _isCorrect = isCorrect;
      _spokenAnswer = _recognizedText;
      if (isCorrect) {
        _score++;
        // Save answer index (we'll use -1 for voice answers)
        _selectedAnswers.add(-1);
        
        // Only auto-advance if correct
        Future.delayed(const Duration(seconds: 2), () {
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
        // Don't auto-advance if incorrect - allow retry
        // User can tap mic again to try
      }
    });
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
    final Color kPrimary = const Color(0xFF3B5FAE);
    final Color accentColor = const Color(0xFF2666B4);
    final Color backgroundColor = isDark ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = isDark ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF071B34);

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Pronunciation Quiz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => widget.onToggleDarkMode(!isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // Score Display
            Text(
              'Score: $_score / ${_questions.length}',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : accentColor,
              ),
            ),
            const SizedBox(height: 20),

            // Quiz Title
            Text(
              'Pronunciation Practice',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),

            // Word Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Pronounce this word:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentQuestion['word'],
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(${currentQuestion['pronunciation']})',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Meaning: ${currentQuestion['meaning']}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tip: ${currentQuestion['tip']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
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
            const SizedBox(height: 30),

            // Spoken Answer Display
            if (_spokenAnswer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
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
                        fontSize: 14,
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!_isCorrect) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pronunciation guide: ${currentQuestion['pronunciation']}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _retryPronunciation,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: _moveToNextQuestion,
                            icon: const Icon(Icons.skip_next, size: 18),
                            label: const Text('Skip'),
                            style: TextButton.styleFrom(
                              foregroundColor: textColor,
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
                ),
                child: Text(
                  'Listening: "$_recognizedText"',
                  style: GoogleFonts.poppins(fontSize: 16, color: textColor),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 30),

            // Voice Input Button
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? Colors.redAccent : accentColor,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.redAccent : accentColor).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isListening 
                  ? 'Listening... Tap to stop and check pronunciation'
                  : _answered && !_isCorrect
                      ? 'Tap mic to try again or skip to next question'
                      : 'Tap to pronounce the word',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

