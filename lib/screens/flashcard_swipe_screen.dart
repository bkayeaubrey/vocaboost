import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/spaced_repetition_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/widgets/badge_notification.dart';
import 'dart:math';

/// Flashcard Swipe Screen - For DISCOVERING new words casually
/// Unlike Spaced Repetition, this is for fun exploration without retention tracking
class FlashcardSwipeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const FlashcardSwipeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<FlashcardSwipeScreen> createState() => _FlashcardSwipeScreenState();
}

class _FlashcardSwipeScreenState extends State<FlashcardSwipeScreen>
    with TickerProviderStateMixin {
  final DatasetService _datasetService = DatasetService.instance;
  final SpacedRepetitionService _spacedRepetitionService = SpacedRepetitionService();
  final XPService _xpService = XPService();
  final AchievementService _achievementService = AchievementService();

  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  int _likedCount = 0;
  int _skippedCount = 0;
  Set<String> _addedToLearning = {}; // Words added to spaced repetition
  bool _isLoading = true;
  bool _isFlipped = false;
  bool _isSessionComplete = false;
  String _selectedCategory = 'all';
  List<String> _categories = ['all'];

  double _dragPosition = 0;
  double _dragAngle = 0;
  late AnimationController _animationController;
  
  // 3D Flip animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize 3D flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    
    _loadCategories();
    _loadCards();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    await _datasetService.loadDataset();
    final allWords = _datasetService.getAllEntries();
    final cats = allWords
        .map((w) => w['category']?.toString() ?? 'General')
        .toSet()
        .toList();
    cats.sort();
    setState(() {
      _categories = ['all', ...cats];
    });
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);

    try {
      await _datasetService.loadDataset();
      var allWords = _datasetService.getAllEntries();
      
      // Filter by category if selected
      if (_selectedCategory != 'all') {
        allWords = allWords.where((w) => 
          (w['category']?.toString() ?? 'General') == _selectedCategory
        ).toList();
      }
      
      // Shuffle and pick random words for discovery
      final random = Random();
      final shuffled = List<Map<String, dynamic>>.from(allWords)..shuffle(random);
      
      final cards = shuffled.take(20).map((w) => {
        'bisaya': w['bisaya'] ?? '',
        'english': w['english'] ?? '',
        'category': w['category'] ?? 'General',
        'example': w['example'] ?? '',
      }).toList();

      setState(() {
        _cards = cards;
        _currentIndex = 0;
        _likedCount = 0;
        _skippedCount = 0;
        _isFlipped = false;
        _isSessionComplete = false;
        _addedToLearning = {};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cards: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta.dx;
      _dragAngle = _dragPosition / 300 * 0.3;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (_dragPosition.abs() > screenWidth * 0.3) {
      final isRight = _dragPosition > 0;
      _animateSwipeOut(isRight);
    } else {
      _animateReturn();
    }
  }

  void _animateSwipeOut(bool isRight) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = isRight ? screenWidth * 1.5 : -screenWidth * 1.5;
    
    setState(() {
      _dragPosition = targetX;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _processSwipe(isRight);
  }

  void _animateReturn() {
    setState(() {
      _dragPosition = 0;
      _dragAngle = 0;
    });
  }

  void _processSwipe(bool liked) async {
    setState(() {
      if (liked) {
        _likedCount++;
      } else {
        _skippedCount++;
      }

      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
        _dragPosition = 0;
        _dragAngle = 0;
        _isFlipped = false;
        _flipController.reset();
      } else {
        _isSessionComplete = true;
        _awardXP();
      }
    });
  }

  Future<void> _addToLearning(Map<String, dynamic> card) async {
    final word = card['bisaya'] ?? '';
    if (word.isEmpty || _addedToLearning.contains(word)) return;
    
    try {
      await _spacedRepetitionService.addWordToReview(
        bisayaWord: word,
        englishWord: card['english'] ?? '',
      );
      setState(() {
        _addedToLearning.add(word);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('"$word" added to Spaced Repetition!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to learning: $e');
    }
  }

  Future<void> _awardXP() async {
    try {
      final xp = 15 + (_likedCount * 2) + (_addedToLearning.length * 5);
      await _xpService.earnXP(
        amount: xp,
        activityType: 'word_discovery',
      );
      
      // Check words learned achievements
      final wordsLearned = await _spacedRepetitionService.getLearnedWordsCount();
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(wordsLearned: wordsLearned);
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }
    } catch (e) {
      debugPrint('Error awarding XP: $e');
    }
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _restartSession() {
    _flipController.reset();
    _loadCards();
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF162236) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF1A2C42);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Category',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedCategory = cat);
                      _loadCards();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.deepPurple 
                            : Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.deepPurple 
                              : Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        cat == 'all' ? 'All Categories' : cat,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFF0F4F8);
    const kDarkBackground = Color(0xFF0A1628);
    const kDarkCard = Color(0xFF162236);
    const kTextDark = Color(0xFF1A2C42);
    const kTextLight = Color(0xFFE8EEF4);

    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final textColor = isDark ? kTextLight : kTextDark;
    final cardColor = isDark ? kDarkCard : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Modern App Bar
          _buildModernAppBar(isDark, textColor, kAccent),
          
          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState(textColor)
                : _isSessionComplete
                    ? _buildCompletionScreen(isDark, cardColor, textColor, kAccent, kPrimary)
                    : _cards.isEmpty
                        ? _buildEmptyState(textColor, kAccent)
                        : _buildSwipeView(isDark, cardColor, textColor, kAccent, kPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark, Color textColor, Color accentColor) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E3A5F), const Color(0xFF0A1628)]
              : [const Color(0xFF7C4DFF), const Color(0xFF536DFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          
          // Title with icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.style_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Words',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _selectedCategory == 'all' ? 'Explore new vocabulary' : _selectedCategory,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Category filter button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
              onPressed: _showCategoryPicker,
            ),
          ),
          const SizedBox(width: 8),
          
          // Progress indicator
          if (!_isLoading && !_isSessionComplete && _cards.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1}/${_cards.length}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.deepPurple,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading flashcards...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeView(bool isDark, Color cardColor, Color textColor, Color accentColor, Color primaryColor) {
    final card = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Column(
      children: [
        // Progress Bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ],
          ),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                icon: Icons.favorite_rounded,
                label: 'Liked',
                count: _likedCount,
                color: Colors.pink,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.school_rounded,
                label: 'Added',
                count: _addedToLearning.length,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.skip_next_rounded,
                label: 'Skipped',
                count: _skippedCount,
                color: Colors.grey,
              ),
            ],
          ),
        ),

        // Swipe Instructions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSwipeHint(Icons.arrow_back_rounded, 'Skip', Colors.grey),
              _buildSwipeHint(Icons.arrow_forward_rounded, 'Like it!', Colors.pink, isRight: true),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card Stack
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background card
              if (_currentIndex < _cards.length - 1)
                Transform.translate(
                  offset: const Offset(0, 12),
                  child: Transform.scale(
                    scale: 0.92,
                    child: _buildCard(
                      _cards[min(_currentIndex + 1, _cards.length - 1)],
                      cardColor.withValues(alpha: 0.6),
                      textColor.withValues(alpha: 0.4),
                      accentColor,
                      primaryColor,
                      isBackground: true,
                      showFront: true,
                    ),
                  ),
                ),

              // Main swipable card with 3D flip
              GestureDetector(
                onTap: _flipCard,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(_dragPosition, 0),
                  child: Transform.rotate(
                    angle: _dragAngle,
                    child: Stack(
                      children: [
                        // 3D Flip Card
                        AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final angle = _flipAnimation.value * 3.14159;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // perspective
                                ..rotateY(angle),
                              child: angle < 1.5708
                                  ? _buildCard(card, cardColor, textColor, accentColor, primaryColor, showFront: true)
                                  : Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()..rotateY(3.14159),
                                      child: _buildCard(card, cardColor, textColor, accentColor, primaryColor, showFront: false),
                                    ),
                            );
                          },
                        ),
                        
                        // Know indicator
                        if (_dragPosition > 50)
                          _buildSwipeIndicator(
                            icon: Icons.favorite_rounded,
                            label: 'LIKE!',
                            color: Colors.pink,
                          ),
                        // Learning indicator
                        if (_dragPosition < -50)
                          _buildSwipeIndicator(
                            icon: Icons.skip_next_rounded,
                            label: 'SKIP',
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tap hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: textColor.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text(
                      'Tap card to ${_isFlipped ? 'see word' : 'reveal meaning'}',
                      style: GoogleFonts.poppins(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Button controls
        Padding(
          padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSwipeButton(
                icon: Icons.close_rounded,
                color: Colors.grey,
                onTap: () => _processSwipe(false),
                label: 'Skip',
              ),
              // Add to Learning button
              _buildAddToLearningButton(card, cardColor, textColor),
              _buildSwipeButton(
                icon: Icons.favorite_rounded,
                color: Colors.pink,
                onTap: () => _processSwipe(true),
                label: 'Like',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeHint(IconData icon, String label, Color color, {bool isRight = false}) {
    final children = [
      Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
      const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.poppins(
          color: color.withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    ];
    
    return Row(
      children: isRight ? children.reversed.toList() : children,
    );
  }

  Widget _buildSwipeIndicator({required IconData icon, required String label, required Color color}) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 72),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> card,
    Color cardColor,
    Color textColor,
    Color accentColor,
    Color primaryColor, {
    bool isBackground = false,
    bool showFront = true,
  }) {
    final bisaya = card['bisaya'] ?? '';
    final english = card['english'] ?? '';

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 380,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isBackground
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (!showFront ? Colors.amber : Colors.deepPurple).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (!showFront ? Colors.amber : Colors.deepPurple).withValues(alpha: 0.05),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showFront || isBackground) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.translate_rounded, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      bisaya,
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Bisaya',
                        style: GoogleFonts.poppins(
                          color: Colors.deepPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade400, Colors.amber.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lightbulb_rounded, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      english,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'English',
                        style: GoogleFonts.poppins(
                          color: Colors.amber.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        bisaya,
                        style: GoogleFonts.poppins(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddToLearningButton(Map<String, dynamic> card, Color cardColor, Color textColor) {
    final word = card['bisaya'] ?? '';
    final isAdded = _addedToLearning.contains(word);
    
    return Column(
      children: [
        GestureDetector(
          onTap: isAdded ? null : () => _addToLearning(card),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: isAdded
                  ? LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isAdded ? Colors.green : Colors.deepPurple).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isAdded ? Icons.check_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isAdded ? 'Added!' : 'Learn',
          style: GoogleFonts.poppins(
            color: isAdded ? Colors.green : Colors.deepPurple,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.15),
                    Colors.deepPurple.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style_rounded,
                size: 56,
                color: Colors.deepPurple.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Cards Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save some words first to start\npracticing with flashcards',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCards,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Refresh', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen(bool isDark, Color cardColor, Color textColor, Color accentColor, Color primaryColor) {
    final total = _likedCount + _skippedCount;
    final likedPercent = total > 0 ? (_likedCount / total * 100).round() : 0;
    final xpEarned = 15 + (_likedCount * 2) + (_addedToLearning.length * 5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Trophy/Badge
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _addedToLearning.isNotEmpty
                    ? [Colors.green.shade300, Colors.green.shade500]
                    : [Colors.deepPurple.shade300, Colors.deepPurple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_addedToLearning.isNotEmpty ? Colors.green : Colors.deepPurple).withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _addedToLearning.isNotEmpty ? Icons.school_rounded : Icons.explore_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          
          Text(
            'Discovery Complete! 🎉',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _addedToLearning.isNotEmpty
                ? 'You added ${_addedToLearning.length} words to learn!'
                : 'Great exploration session!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                  icon: Icons.favorite_rounded,
                  label: 'Liked',
                  count: _likedCount,
                  color: Colors.pink,
                  cardColor: cardColor,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultCard(
                  icon: Icons.school_rounded,
                  label: 'To Learn',
                  count: _addedToLearning.length,
                  color: Colors.green,
                  cardColor: cardColor,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultCard(
                  icon: Icons.skip_next_rounded,
                  label: 'Skipped',
                  count: _skippedCount,
                  color: Colors.grey,
                  cardColor: cardColor,
                  textColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Discovery Progress
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Words Liked',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '$likedPercent%',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: likedPercent / 100,
                    minHeight: 12,
                    backgroundColor: Colors.pink.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Tip Card
          if (_addedToLearning.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Go to Spaced Repetition to review your new words!',
                      style: GoogleFonts.poppins(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          
          // XP Earned
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade300, Colors.amber.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  '+$xpEarned XP Earned!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Discover More Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _restartSession,
              icon: const Icon(Icons.explore_rounded),
              label: Text(
                'Discover More',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
