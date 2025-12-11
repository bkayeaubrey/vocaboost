import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/widgets/badge_notification.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class HangmanScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const HangmanScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends State<HangmanScreen> {
  final DatasetService _datasetService = DatasetService.instance;
  final XPService _xpService = XPService();
  final AchievementService _achievementService = AchievementService();
  late ConfettiController _confettiController;
  
  String _currentWord = '';
  String _currentHint = '';
  Set<String> _guessedLetters = {};
  int _wrongGuesses = 0;
  int _score = 0;
  int _gamesWon = 0;
  int _gamesPlayed = 0;
  bool _isGameOver = false;
  bool _hasWon = false;
  bool _isLoading = true;

  static const int maxWrongGuesses = 6;
  static const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initializeGame();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    setState(() => _isLoading = true);
    
    try {
      await _datasetService.loadDataset();
      _startNewGame();
    } catch (e) {
      debugPrint('Error initializing game: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _startNewGame() {
    final words = _datasetService.getAllEntries();
    if (words.isEmpty) {
      setState(() {
        _currentWord = 'SALAMAT';
        _currentHint = 'Thank you';
      });
      return;
    }

    // Filter words that are suitable for hangman (not too long, no spaces)
    final suitableWords = words.where((w) {
      final bisaya = (w['bisaya'] ?? '').toString().toUpperCase();
      return bisaya.length >= 3 && 
             bisaya.length <= 12 && 
             !bisaya.contains(' ') &&
             bisaya.contains(RegExp(r'^[A-Z]+$'));
    }).toList();

    if (suitableWords.isEmpty) {
      setState(() {
        _currentWord = 'MAAYONG';
        _currentHint = 'Good (greeting prefix)';
      });
      return;
    }

    final random = Random();
    final selectedWord = suitableWords[random.nextInt(suitableWords.length)];

    setState(() {
      _currentWord = (selectedWord['bisaya'] ?? 'SALAMAT').toString().toUpperCase();
      _currentHint = (selectedWord['english'] ?? 'Unknown').toString();
      _guessedLetters = {};
      _wrongGuesses = 0;
      _isGameOver = false;
      _hasWon = false;
    });
  }

  void _guessLetter(String letter) {
    if (_isGameOver || _guessedLetters.contains(letter)) return;

    setState(() {
      _guessedLetters.add(letter);

      if (!_currentWord.contains(letter)) {
        _wrongGuesses++;
        if (_wrongGuesses >= maxWrongGuesses) {
          _isGameOver = true;
          _hasWon = false;
          _gamesPlayed++;
        }
      } else {
        // Check if word is complete
        final isComplete = _currentWord
            .split('')
            .every((l) => _guessedLetters.contains(l));
        
        if (isComplete) {
          _isGameOver = true;
          _hasWon = true;
          _gamesWon++;
          _gamesPlayed++;
          _score += (maxWrongGuesses - _wrongGuesses) * 10 + 50;
          _confettiController.play();
          _awardXP();
        }
      }
    });
  }

  Future<void> _awardXP() async {
    try {
      await _xpService.earnXP(
        amount: 30 + (maxWrongGuesses - _wrongGuesses) * 5,
        activityType: 'hangman',
      );
      
      // Check for hangman achievement
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(hangmanWins: _gamesWon);
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }
    } catch (e) {
      debugPrint('Error awarding XP: $e');
    }
  }

  String _getDisplayWord() {
    return _currentWord.split('').map((letter) {
      return _guessedLetters.contains(letter) ? letter : '_';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final Color kPrimary = const Color(0xFF3B5FAE);
    final Color accentColor = const Color(0xFF2666B4);
    final Color backgroundColor = widget.isDarkMode ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = widget.isDarkMode ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : const Color(0xFF071B34);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Hangman',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$_score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatChip('Won', '$_gamesWon', Colors.green, textColor),
                          _buildStatChip('Played', '$_gamesPlayed', accentColor, textColor),
                          _buildStatChip('Lives', '${maxWrongGuesses - _wrongGuesses}', Colors.red, textColor),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Hangman Figure
                      Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: HangmanPainter(
                            wrongGuesses: _wrongGuesses,
                            color: textColor,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Hint
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Hint: $_currentHint',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Word Display
                      Text(
                        _isGameOver && !_hasWon ? _currentWord : _getDisplayWord(),
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _isGameOver && !_hasWon ? Colors.red : textColor,
                          letterSpacing: 4,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Game Over Message
                      if (_isGameOver) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _hasWon
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _hasWon ? Icons.celebration : Icons.sentiment_dissatisfied,
                                size: 48,
                                color: _hasWon ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _hasWon ? 'You Won! 🎉' : 'Game Over',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _hasWon ? Colors.green : Colors.red,
                                ),
                              ),
                              if (_hasWon) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '+${30 + (maxWrongGuesses - _wrongGuesses) * 5} XP',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                              if (!_hasWon) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'The word was: $_currentWord',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _startNewGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Play Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Keyboard
                        _buildKeyboard(cardColor, textColor, accentColor),
                      ],
                    ],
                  ),
                ),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard(Color cardColor, Color textColor, Color accentColor) {
    final rows = [
      alphabet.substring(0, 10),
      alphabet.substring(10, 19),
      alphabet.substring(19),
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.split('').map((letter) {
              final isGuessed = _guessedLetters.contains(letter);
              final isCorrect = isGuessed && _currentWord.contains(letter);
              final isWrong = isGuessed && !_currentWord.contains(letter);

              Color bgColor = cardColor;
              Color fgColor = textColor;
              if (isCorrect) {
                bgColor = Colors.green;
                fgColor = Colors.white;
              } else if (isWrong) {
                bgColor = Colors.red.withValues(alpha: 0.3);
                fgColor = Colors.red;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  elevation: isGuessed ? 0 : 2,
                  child: InkWell(
                    onTap: isGuessed ? null : () => _guessLetter(letter),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 40,
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class HangmanPainter extends CustomPainter {
  final int wrongGuesses;
  final Color color;

  HangmanPainter({required this.wrongGuesses, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final baseY = size.height - 20;

    // Base
    canvas.drawLine(
      Offset(30, baseY),
      Offset(size.width - 30, baseY),
      paint,
    );

    // Pole
    if (wrongGuesses >= 1) {
      canvas.drawLine(
        Offset(60, baseY),
        Offset(60, 30),
        paint,
      );
      // Top beam
      canvas.drawLine(
        const Offset(60, 30),
        Offset(centerX + 10, 30),
        paint,
      );
      // Rope
      canvas.drawLine(
        Offset(centerX + 10, 30),
        Offset(centerX + 10, 50),
        paint,
      );
    }

    // Head
    if (wrongGuesses >= 2) {
      canvas.drawCircle(
        Offset(centerX + 10, 65),
        15,
        paint,
      );
    }

    // Body
    if (wrongGuesses >= 3) {
      canvas.drawLine(
        Offset(centerX + 10, 80),
        Offset(centerX + 10, 120),
        paint,
      );
    }

    // Left Arm
    if (wrongGuesses >= 4) {
      canvas.drawLine(
        Offset(centerX + 10, 90),
        Offset(centerX - 15, 105),
        paint,
      );
    }

    // Right Arm
    if (wrongGuesses >= 5) {
      canvas.drawLine(
        Offset(centerX + 10, 90),
        Offset(centerX + 35, 105),
        paint,
      );
    }

    // Legs
    if (wrongGuesses >= 6) {
      // Left Leg
      canvas.drawLine(
        Offset(centerX + 10, 120),
        Offset(centerX - 10, 150),
        paint,
      );
      // Right Leg
      canvas.drawLine(
        Offset(centerX + 10, 120),
        Offset(centerX + 30, 150),
        paint,
      );
      
      // X eyes for dead
      canvas.drawLine(
        Offset(centerX + 3, 60),
        Offset(centerX + 10, 67),
        paint,
      );
      canvas.drawLine(
        Offset(centerX + 10, 60),
        Offset(centerX + 3, 67),
        paint,
      );
      canvas.drawLine(
        Offset(centerX + 13, 60),
        Offset(centerX + 20, 67),
        paint,
      );
      canvas.drawLine(
        Offset(centerX + 20, 60),
        Offset(centerX + 13, 67),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HangmanPainter oldDelegate) {
    return oldDelegate.wrongGuesses != wrongGuesses || oldDelegate.color != color;
  }
}
