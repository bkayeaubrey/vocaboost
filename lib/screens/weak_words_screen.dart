import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/spaced_repetition_service.dart';
import '../services/xp_service.dart';

/// Weak Words Review Screen
/// Identifies and focuses practice on words the user struggles with
/// Based on low easiness factor and frequent incorrect responses
class WeakWordsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;

  const WeakWordsScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
  });

  @override
  State<WeakWordsScreen> createState() => _WeakWordsScreenState();
}

class _WeakWordsScreenState extends State<WeakWordsScreen> {
  // Theme colors
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);
  static const Color kCorrect = Color(0xFF4CAF50);
  static const Color kWrong = Color(0xFFE53935);

  final SpacedRepetitionService _spacedRepetitionService = SpacedRepetitionService();
  final XPService _xpService = XPService();
  final FlutterTts _tts = FlutterTts();
  late ConfettiController _confettiController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _weakWords = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _inPracticeMode = false;
  int _correctCount = 0;
  int _totalPracticed = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initTTS();
    _loadWeakWords();
  }

  @override
  void dispose() {
    _tts.stop();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('fil-PH');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _loadWeakWords() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all saved words with spaced repetition data
      final allWords = await _spacedRepetitionService.getAllReviewWords();
      
      // Filter weak words: low easiness factor OR low repetitions with recent reviews
      // Words with easiness factor < 2.0 or reviewed multiple times but still struggling
      _weakWords = allWords.where((word) {
        final easiness = (word['easinessFactor'] as num?)?.toDouble() ?? 2.5;
        final repetitions = (word['repetitions'] as num?)?.toInt() ?? 0;
        final totalReviews = (word['totalReviews'] as num?)?.toInt() ?? 0;
        
        // Weak word criteria:
        // 1. Low easiness factor (difficulty remembering)
        // 2. High review count but low repetitions (keeps resetting)
        // 3. Due for review and has been reviewed before
        bool isWeak = easiness < 2.0;
        bool isStruggling = totalReviews > 3 && repetitions < 3;
        bool needsAttention = word['isDue'] == true && totalReviews > 0;
        
        return isWeak || isStruggling || needsAttention;
      }).toList();

      // Sort by weakness (lower easiness = harder = first)
      _weakWords.sort((a, b) {
        final eA = (a['easinessFactor'] as num?)?.toDouble() ?? 2.5;
        final eB = (b['easinessFactor'] as num?)?.toDouble() ?? 2.5;
        return eA.compareTo(eB);
      });

      // Limit to top 20 weakest words
      if (_weakWords.length > 20) {
        _weakWords = _weakWords.sublist(0, 20);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading weak words: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startPractice() {
    if (_weakWords.isEmpty) return;
    
    setState(() {
      _inPracticeMode = true;
      _currentIndex = 0;
      _correctCount = 0;
      _totalPracticed = 0;
      _streak = 0;
      _showAnswer = false;
    });
  }

  void _recordAnswer(int quality) async {
    final word = _weakWords[_currentIndex];
    
    // Record the review result
    try {
      await _spacedRepetitionService.recordReviewResult(
        word: word['word'],
        quality: quality,
      );
    } catch (e) {
      debugPrint('Error recording review: $e');
    }

    setState(() {
      _totalPracticed++;
      if (quality >= 3) {
        _correctCount++;
        _streak++;
        if (_streak >= 3) {
          _confettiController.play();
        }
      } else {
        _streak = 0;
      }
      
      if (_currentIndex < _weakWords.length - 1) {
        _currentIndex++;
        _showAnswer = false;
      } else {
        // Practice complete
        _showPracticeComplete();
      }
    });
  }

  void _showPracticeComplete() async {
    final accuracy = _totalPracticed > 0 ? (_correctCount / _totalPracticed * 100) : 0.0;
    final xpEarned = _correctCount * 5 + (_totalPracticed * 2);
    
    try {
      await _xpService.earnXP(amount: xpEarned, activityType: 'weak_words_review');
    } catch (e) {
      debugPrint('Error earning XP: $e');
    }

    _confettiController.play();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎉 ', style: TextStyle(fontSize: 28)),
            Text('Practice Complete!', style: GoogleFonts.poppins(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withOpacity(0.1), kAccent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildResultStat('Words', '$_totalPracticed', Icons.menu_book),
                      _buildResultStat('Correct', '$_correctCount', Icons.check_circle),
                      _buildResultStat('Accuracy', '${accuracy.toStringAsFixed(0)}%', Icons.percent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '+$xpEarned XP',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: kPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              accuracy >= 80 
                  ? '🌟 Excellent! Keep it up!' 
                  : accuracy >= 50 
                      ? '💪 Good effort! Practice makes perfect!'
                      : '📚 Keep reviewing these words!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadWeakWords();
              setState(() => _inPracticeMode = false);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadWeakWords();
              _startPractice();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Practice Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kPrimary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA);
    final cardColor = widget.isDarkMode ? const Color(0xFF252542) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _inPracticeMode ? 'Practice Mode' : 'Weak Words',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_inPracticeMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 18, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('$_streak', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _inPracticeMode
                  ? _buildPracticeMode(cardColor, textColor)
                  : _buildWordsList(cardColor, textColor, backgroundColor),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsList(Color cardColor, Color textColor, Color backgroundColor) {
    if (_weakWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No weak words!',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re doing great with all your words!',
              style: TextStyle(color: textColor.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kWrong, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weakWords.length} Words Need Attention',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice these words to improve!',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Practice button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _startPractice,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Start Practice',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Words list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _weakWords.length,
            itemBuilder: (context, index) => _buildWordCard(_weakWords[index], cardColor, textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word, Color cardColor, Color textColor) {
    final easiness = (word['easinessFactor'] as num?)?.toDouble() ?? 2.5;
    final difficultyLevel = easiness < 1.5 ? 'Hard' : easiness < 2.0 ? 'Medium' : 'Easy';
    final difficultyColor = easiness < 1.5 ? kWrong : easiness < 2.0 ? Colors.orange : kCorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: GestureDetector(
          onTap: () => _speak(word['word'] ?? ''),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.volume_up, color: kPrimary),
          ),
        ),
        title: Text(
          word['word'] ?? '',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              word['translation'] ?? '',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    difficultyLevel,
                    style: TextStyle(
                      color: difficultyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${word['totalReviews'] ?? 0} reviews',
                  style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeMode(Color cardColor, Color textColor) {
    if (_currentIndex >= _weakWords.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final word = _weakWords[_currentIndex];
    
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _weakWords.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1}/${_weakWords.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),

        // Card area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                if (!_showAnswer) {
                  setState(() => _showAnswer = true);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAnswer
                    ? _buildAnswerCard(word, cardColor, textColor)
                    : _buildQuestionCard(word, cardColor, textColor),
              ),
            ),
          ),
        ),

        // Action buttons
        if (_showAnswer)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'How well did you know this?',
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _recordAnswer(1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kWrong,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.close, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Forgot', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _recordAnswer(3),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.remove, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Hard', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _recordAnswer(4),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Good', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _recordAnswer(5),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCorrect,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.done_all, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Easy', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Tap the card to reveal the answer',
                style: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> word, Color cardColor, Color textColor) {
    return Container(
      key: const ValueKey('question'),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word['fromLanguage'] ?? 'Bisaya',
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => _speak(word['word'] ?? ''),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.volume_up, color: kPrimary, size: 28),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    word['word'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, color: textColor.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'Tap to reveal answer',
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(Map<String, dynamic> word, Color cardColor, Color textColor) {
    return Container(
      key: const ValueKey('answer'),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, kPrimary.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Question
          Text(
            word['word'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: 60,
            height: 2,
            color: kPrimary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          // Answer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kCorrect.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word['toLanguage'] ?? 'English',
              style: TextStyle(
                color: kCorrect,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            word['translation'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: kCorrect,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
