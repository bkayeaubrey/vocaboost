import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../services/dataset_service.dart';
import '../services/xp_service.dart';

/// Sentence Builder Game Screen
/// Users arrange scrambled words to form correct Bisaya sentences
/// Uses sentences from the bisaya_dataset.csv
class SentenceBuilderScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;

  const SentenceBuilderScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
  });

  @override
  State<SentenceBuilderScreen> createState() => _SentenceBuilderScreenState();
}

class _SentenceBuilderScreenState extends State<SentenceBuilderScreen>
    with TickerProviderStateMixin {
  // Theme colors
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);
  static const Color kCorrect = Color(0xFF4CAF50);
  static const Color kWrong = Color(0xFFE53935);

  // Services
  final DatasetService _datasetService = DatasetService.instance;
  final XPService _xpService = XPService();
  final FlutterTts _tts = FlutterTts();
  late ConfettiController _confettiController;

  // Game state
  bool _isLoading = true;
  List<Map<String, dynamic>> _sentences = [];
  int _currentIndex = 0;
  int _score = 0;
  int _totalXP = 0;
  int _streak = 0;
  int _hearts = 3;
  String _difficulty = 'beginner'; // beginner, intermediate, advanced

  // Current sentence state
  String _currentSentence = '';
  String _currentTranslation = '';
  List<String> _scrambledWords = [];
  List<String> _selectedWords = [];
  bool _showingResult = false;
  bool _isCorrect = false;

  // Animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    
    _initTTS();
    _loadSentences();
  }

  @override
  void dispose() {
    _tts.stop();
    _confettiController.dispose();
    _shakeController.dispose();
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

  Future<void> _loadSentences() async {
    setState(() => _isLoading = true);

    try {
      await _datasetService.loadDataset();
      final allData = _datasetService.getAllEntries();

      // Extract sentences based on difficulty
      _sentences = [];
      for (var entry in allData) {
        String sentence = '';
        String translation = '';

        switch (_difficulty) {
          case 'beginner':
            sentence = entry['beginnerExample'] ?? '';
            translation = entry['beginnerEnglish'] ?? '';
            break;
          case 'intermediate':
            sentence = entry['intermediateExample'] ?? '';
            translation = entry['intermediateEnglish'] ?? '';
            break;
          case 'advanced':
            sentence = entry['advancedExample'] ?? '';
            translation = entry['advancedEnglish'] ?? '';
            break;
        }

        // Only add if sentence has multiple words (good for word arrangement)
        if (sentence.isNotEmpty && sentence.split(' ').length >= 3) {
          _sentences.add({
            'sentence': sentence,
            'translation': translation,
            'word': entry['bisaya'] ?? '',
          });
        }
      }

      // Shuffle sentences
      _sentences.shuffle(Random());

      // Limit to 10 sentences per round
      if (_sentences.length > 10) {
        _sentences = _sentences.sublist(0, 10);
      }

      if (_sentences.isNotEmpty) {
        _setupCurrentSentence();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading sentences: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupCurrentSentence() {
    if (_currentIndex >= _sentences.length) return;

    final data = _sentences[_currentIndex];
    _currentSentence = data['sentence'];
    _currentTranslation = data['translation'];

    // Split sentence into words and scramble
    List<String> words = _currentSentence.split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();
    
    // Scramble words
    _scrambledWords = List.from(words);
    _scrambledWords.shuffle(Random());
    
    // Make sure it's actually scrambled (not in original order)
    while (_scrambledWords.join(' ') == _currentSentence && words.length > 2) {
      _scrambledWords.shuffle(Random());
    }

    _selectedWords = [];
    _showingResult = false;
    _isCorrect = false;
  }

  void _selectWord(int index) {
    if (_showingResult) return;

    setState(() {
      final word = _scrambledWords[index];
      _selectedWords.add(word);
      _scrambledWords.removeAt(index);
    });
  }

  void _removeWord(int index) {
    if (_showingResult) return;

    setState(() {
      final word = _selectedWords[index];
      _scrambledWords.add(word);
      _selectedWords.removeAt(index);
    });
  }

  void _checkAnswer() {
    final userAnswer = _selectedWords.join(' ');
    final isCorrect = _normalizeString(userAnswer) == _normalizeString(_currentSentence);

    setState(() {
      _showingResult = true;
      _isCorrect = isCorrect;

      if (isCorrect) {
        _streak++;
        int xpGained = 15 + (_streak > 3 ? 5 : 0);
        if (_difficulty == 'intermediate') xpGained += 5;
        if (_difficulty == 'advanced') xpGained += 10;
        
        _score++;
        _totalXP += xpGained;
        
        if (_streak >= 3) {
          _confettiController.play();
        }
      } else {
        _streak = 0;
        _hearts--;
        _shakeController.forward().then((_) => _shakeController.reset());
        
        if (_hearts <= 0) {
          _showGameOver();
        }
      }
    });

    // Speak the correct sentence
    _speak(_currentSentence);
  }

  String _normalizeString(String s) {
    return s.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _nextSentence() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _setupCurrentSentence();
      });
    } else {
      _showGameComplete();
    }
  }

  void _showGameComplete() async {
    try {
      await _xpService.earnXP(amount: _totalXP, activityType: 'sentence_builder');
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
            Text('Game Complete!', style: GoogleFonts.poppins(fontSize: 20)),
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
                      _buildResultStat('Score', '$_score/${_sentences.length}', Icons.check_circle),
                      _buildResultStat('XP', '+$_totalXP', Icons.stars),
                      _buildResultStat('Streak', '$_streak🔥', Icons.local_fire_department),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _score == _sentences.length 
                  ? '🌟 Perfect Score!' 
                  : _score >= _sentences.length * 0.7 
                      ? '💪 Great Job!'
                      : '📚 Keep Practicing!',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Play Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('💔 ', style: TextStyle(fontSize: 28)),
            Text('Game Over', style: GoogleFonts.poppins(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You ran out of hearts!', style: GoogleFonts.poppins(fontSize: 16)),
            const SizedBox(height: 16),
            Text('Score: $_score/${_sentences.length}', 
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('+$_totalXP XP earned', 
                style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _totalXP = 0;
      _streak = 0;
      _hearts = 3;
    });
    _loadSentences();
  }

  Widget _buildResultStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kPrimary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  void _showDifficultySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Difficulty', 
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDifficultyOption('beginner', 'Beginner', '🌱 Simple sentences', Colors.green),
            _buildDifficultyOption('intermediate', 'Intermediate', '🌿 Medium complexity', Colors.orange),
            _buildDifficultyOption('advanced', 'Advanced', '🌳 Complex sentences', Colors.red),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(String level, String title, String desc, Color color) {
    final isSelected = _difficulty == level;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _difficulty = level;
          _currentIndex = 0;
          _score = 0;
          _totalXP = 0;
          _streak = 0;
          _hearts = 3;
        });
        _loadSentences();
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.signal_cellular_alt, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(desc),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimary) : null,
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
        title: Text('Sentence Builder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Difficulty selector
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showDifficultySelector,
            tooltip: 'Change difficulty',
          ),
          // Hearts
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: List.generate(3, (i) => Icon(
                i < _hearts ? Icons.favorite : Icons.favorite_border,
                color: i < _hearts ? Colors.red : Colors.white54,
                size: 20,
              )),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sentences.isEmpty
                  ? _buildNoSentences(textColor)
                  : _buildGame(cardColor, textColor, backgroundColor),

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

  Widget _buildNoSentences(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No sentences available', 
              style: GoogleFonts.poppins(fontSize: 20, color: textColor)),
          const SizedBox(height: 8),
          Text('Try a different difficulty level',
              style: TextStyle(color: textColor.withOpacity(0.6))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _showDifficultySelector,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Change Difficulty', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(Color cardColor, Color textColor, Color backgroundColor) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _sentences.length,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
          minHeight: 6,
        ),

        // Score and streak
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1}/${_sentences.length}',
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: kPrimary, size: 18),
                        const SizedBox(width: 4),
                        Text('$_totalXP', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Translation (what to build)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
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
          child: Column(
            children: [
              Text(
                'Build this sentence in Bisaya:',
                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                _currentTranslation,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Answer area (selected words)
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value * sin(_shakeController.value * 3 * pi), 0),
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: _showingResult 
                  ? (_isCorrect ? kCorrect.withOpacity(0.1) : kWrong.withOpacity(0.1))
                  : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showingResult 
                    ? (_isCorrect ? kCorrect : kWrong)
                    : kPrimary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                if (_selectedWords.isEmpty && !_showingResult)
                  Text(
                    'Tap words below to build the sentence',
                    style: TextStyle(color: textColor.withOpacity(0.4)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _selectedWords.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap: () => _removeWord(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _showingResult 
                                ? (_isCorrect ? kCorrect : kWrong)
                                : kPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                // Show correct answer if wrong
                if (_showingResult && !_isCorrect) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Correct answer:', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _speak(_currentSentence),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, color: kCorrect, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentSentence,
                            style: GoogleFonts.poppins(
                              color: kCorrect,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Word bank (scrambled words)
        if (!_showingResult)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _scrambledWords.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _selectWord(entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPrimary.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          entry.value,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        // Action buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _showingResult
                ? ElevatedButton(
                    onPressed: _nextSentence,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCorrect ? kCorrect : kPrimary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _currentIndex < _sentences.length - 1 ? 'Next' : 'Finish',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _selectedWords.isEmpty ? null : () {
                            setState(() {
                              _scrambledWords.addAll(_selectedWords);
                              _selectedWords.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: kPrimary.withOpacity(0.5)),
                          ),
                          child: Text('Clear', style: TextStyle(color: kPrimary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _scrambledWords.isEmpty ? _checkAnswer : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Check',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
