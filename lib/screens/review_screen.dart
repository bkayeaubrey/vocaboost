import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/spaced_repetition_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;

/// Color constants
const Color kPrimary = Color(0xFF3B5FAE);
const Color kAccent = Color(0xFF2666B4);
const Color kDarkBg = Color(0xFF071B34);
const Color kDarkCard = Color(0xFF20304A);

/// Spaced Repetition Review Screen with modern Anki-style design
class ReviewScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const ReviewScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with TickerProviderStateMixin {
  final SpacedRepetitionService _spacedRepetitionService = SpacedRepetitionService();
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;

  List<Map<String, dynamic>> _wordsDue = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showAnswer = false;
  bool _isImporting = false;
  Map<String, dynamic>? _stats;
  
  // Session tracking
  int _sessionReviewed = 0;
  int _sessionCorrect = 0;
  DateTime? _sessionStartTime;
  
  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTts();
    _loadWordsDue();
    _sessionStartTime = DateTime.now();
  }

  void _initializeAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> _speakWord(String text) async {
    if (!_isTtsInitialized) await _initializeTts();
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _loadWordsDue() async {
    setState(() => _isLoading = true);
    try {
      final words = await _spacedRepetitionService.getWordsDueForReview();
      final stats = await _spacedRepetitionService.getReviewStatistics();
      
      setState(() {
        _wordsDue = words;
        _stats = stats;
        _currentIndex = 0;
        _showAnswer = false;
        _isLoading = false;
      });
      _flipController.reset();
    } catch (e) {
      debugPrint('Error loading words due: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromQuizzes() async {
    setState(() => _isImporting = true);
    try {
      final count = await _spacedRepetitionService.importWordsFromQuizResults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $count words from your quiz history!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload to show the new words
        await _loadWordsDue();
      }
    } catch (e) {
      debugPrint('Error importing words: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _flipCard() {
    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  Future<void> _submitReview(int quality) async {
    if (_currentIndex >= _wordsDue.length) return;

    final currentWord = _wordsDue[_currentIndex];
    
    // Track session stats
    _sessionReviewed++;
    if (quality >= 3) _sessionCorrect++;

    try {
      await _spacedRepetitionService.recordReviewResult(
        word: currentWord['word'] as String,
        quality: quality,
      );

      // Animate card out
      await _slideController.forward();
      
      // Move to next word or finish
      if (_currentIndex < _wordsDue.length - 1) {
        setState(() {
          _currentIndex++;
          _showAnswer = false;
        });
        _flipController.reset();
        _slideController.reset();
      } else {
        // Show completion dialog
        if (mounted) {
          _showSessionComplete();
        }
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSessionComplete() {
    final duration = DateTime.now().difference(_sessionStartTime!);
    final accuracy = _sessionReviewed > 0 
        ? (_sessionCorrect / _sessionReviewed * 100).round() 
        : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Complete!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : kDarkBg,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatItem(
                Icons.check_circle_outline,
                'Words Reviewed',
                '$_sessionReviewed',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                Icons.trending_up,
                'Accuracy',
                '$accuracy%',
                accuracy >= 80 ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                Icons.timer_outlined,
                'Time Spent',
                '${duration.inMinutes}m ${duration.inSeconds % 60}s',
                Colors.purple,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: kAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _sessionReviewed = 0;
                        _sessionCorrect = 0;
                        _sessionStartTime = DateTime.now();
                        _loadWordsDue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final backgroundColor = isDark ? kDarkBg : const Color(0xFFC7D4E8);
    final cardColor = isDark ? kDarkCard : Colors.white;
    final textColor = isDark ? Colors.white : kDarkBg;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? _buildLoadingState(textColor)
          : _wordsDue.isEmpty
              ? _buildEmptyState(cardColor, textColor)
              : _buildReviewState(cardColor, textColor, backgroundColor),
    );
  }

  Widget _buildLoadingState(Color textColor) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kAccent),
                  const SizedBox(height: 24),
                  Text(
                    'Loading your review...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor.withOpacity(0.7),
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

  Widget _buildEmptyState(Color cardColor, Color textColor) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_stats?['totalWords'] ?? 0) > 0 
                          ? Icons.check_circle 
                          : Icons.psychology_outlined,
                      size: 64,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    (_stats?['totalWords'] ?? 0) > 0 
                        ? 'All caught up!' 
                        : 'No words to review yet',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (_stats?['totalWords'] ?? 0) > 0
                        ? 'Great job! Check back later for more reviews.'
                        : 'Import words from your quiz history or\nlearn new words to start reviewing!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_stats != null && (_stats!['totalWords'] ?? 0) > 0) 
                    _buildStatsCard(cardColor, textColor),
                  const SizedBox(height: 24),
                  // Import from quizzes button
                  if ((_stats?['totalWords'] ?? 0) == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: _isImporting ? null : _importFromQuizzes,
                        icon: _isImporting 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(_isImporting ? 'Importing...' : 'Import from Quiz History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildStatsCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Your Progress',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat(
                Icons.library_books,
                '${_stats!['totalWords']}',
                'Total',
                kAccent,
              ),
              _buildMiniStat(
                Icons.emoji_events,
                '${_stats!['wordsMastered']}',
                'Mastered',
                Colors.amber,
              ),
              _buildMiniStat(
                Icons.schedule,
                '${_stats!['wordsDue']}',
                'Due',
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: widget.isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewState(Color cardColor, Color textColor, Color backgroundColor) {
    final currentWord = _wordsDue[_currentIndex];
    final progress = (_currentIndex + 1) / _wordsDue.length;

    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          // Progress section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Card ${_currentIndex + 1} of ${_wordsDue.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: textColor.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          
          // Card section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi;
                      final isBack = angle > (math.pi / 2);
                      
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildCardBack(currentWord, cardColor, textColor),
                              )
                            : _buildCardFront(currentWord, cardColor, textColor),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Rating buttons
          if (_showAnswer) _buildRatingButtons(textColor),
          
          // Tap hint
          if (!_showAnswer)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 16, color: textColor.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Tap card to reveal answer',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final textColor = widget.isDarkMode ? Colors.white : kDarkBg;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Spaced Repetition',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          if (_sessionReviewed > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_sessionReviewed',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: textColor,
            ),
            onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(Map<String, dynamic> word, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              color: kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word['fromLanguage'] ?? 'Bisaya',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kAccent,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            word['word'] as String,
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          IconButton(
            onPressed: () => _speakWord(word['word'] as String),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up, color: kAccent, size: 28),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'What does this mean?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Map<String, dynamic> word, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimary,
            kAccent,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word['toLanguage'] ?? 'English',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            word['translation'] as String,
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _speakWord(word['translation'] as String),
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'How well did you remember?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButtons(Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: _buildRatingButton(
              'Again',
              Icons.refresh,
              const Color(0xFFE53935),
              0,
              'Review soon',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRatingButton(
              'Hard',
              Icons.sentiment_dissatisfied,
              const Color(0xFFFB8C00),
              2,
              '< 10 min',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRatingButton(
              'Good',
              Icons.sentiment_satisfied,
              const Color(0xFF43A047),
              4,
              '1 day',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRatingButton(
              'Easy',
              Icons.sentiment_very_satisfied,
              const Color(0xFF1E88E5),
              5,
              '4 days',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton(
    String label,
    IconData icon,
    Color color,
    int quality,
    String interval,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _submitReview(quality),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                interval,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

