import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vocaboost/services/progress_service.dart';
import 'package:vocaboost/services/quiz_service.dart';
import 'package:vocaboost/services/flashcard_service.dart';
import 'package:vocaboost/services/report_service.dart';
import 'saved_screen.dart';
import 'quiz_selection_screen.dart';

// Blue Hour Color Palette
const Color kPrimary = Color(0xFF3B5FAE);
const Color kAccent = Color(0xFF2666B4);
const Color kLightBackground = Color(0xFFC7D4E8);
const Color kDarkBackground = Color(0xFF071B34);

class ProgressScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const ProgressScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();
  final QuizService _quizService = QuizService();
  final ReportService _reportService = ReportService();
  bool _isDownloading = false;
  
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  Map<String, dynamic> _wordMastery = {};
  Map<String, dynamic> _pronunciationScore = {};
  List<Map<String, dynamic>> _quizResults = [];
  bool _isLoading = true;
  
  Map<String, int> _dailyWordAcquisition = {};
  Map<String, dynamic> _streakData = {};
  List<Map<String, dynamic>> _achievements = [];
  String _motivationalMessage = '';
  
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late Animation<double> _headerAnimation;
  late Animation<double> _cardsAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _cardsAnimation = CurvedAnimation(
      parent: _cardsController,
      curve: Curves.easeOutBack,
    );
    
    _loadProgress();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    
    try {
      // Use the optimized getAllProgressData method
      final allData = await _progressService.getAllProgressData(forceRefresh: true);
      
      setState(() {
        _stats = allData['stats'] ?? {};
        _weeklyData = List<Map<String, dynamic>>.from(allData['weeklyData'] ?? []);
        _wordMastery = allData['wordMastery'] ?? {};
        _pronunciationScore = allData['pronunciationScore'] ?? {};
      });
      
      // Load quiz results for history from Firestore directly
      await _loadQuizResults();
      
      // Load additional analytics data
      await _loadDummyAnalyticsData();
      
      setState(() => _isLoading = false);
      
      _headerController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _cardsController.forward();
      });
    } catch (e) {
      debugPrint('Error loading progress: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadQuizResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _quizResults = [];
        return;
      }
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      _quizResults = snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error loading quiz results: $e');
      _quizResults = [];
    }
  }

  Future<void> _loadDummyAnalyticsData() async {
    await _calculateDailyWordAcquisition();
    await _loadStreakData();
    _calculateAchievements();
    _generateMotivationalMessage();
  }

  Future<void> _calculateDailyWordAcquisition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _dailyWordAcquisition = {};
        return;
      }

      // Get quiz results to track daily activity
      final quizResultsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();

      final now = DateTime.now();
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dailyCounts = <String, int>{};
      
      for (var day in dayNames) {
        dailyCounts[day] = 0;
      }

      final weekAgo = now.subtract(const Duration(days: 7));
      for (var doc in quizResultsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          if (!date.isBefore(weekAgo)) {
            final dayOfWeek = date.weekday;
            final dayName = dayNames[dayOfWeek - 1];
            // Count correct answers as progress
            final correctAnswers = (data['correctAnswers'] as num?)?.toInt() ?? 1;
            dailyCounts[dayName] = (dailyCounts[dayName] ?? 0) + correctAnswers;
          }
        }
      }

      if (dailyCounts.values.every((count) => count == 0)) {
        final weeklyData = await _progressService.getWeeklyProgress();
        for (int i = 0; i < weeklyData.length && i < dayNames.length; i++) {
          final dayName = dayNames[i];
          final score = weeklyData[i]['score'] as int? ?? 0;
          dailyCounts[dayName] = score;
        }
      }

      setState(() {
        _dailyWordAcquisition = dailyCounts;
      });
    } catch (e) {
      debugPrint('Error calculating daily activity: $e');
      _dailyWordAcquisition = {};
    }
  }

  Future<void> _loadStreakData() async {
    try {
      final flashcardService = FlashcardService();
      final streak = await flashcardService.getLearningStreak();
      
      final currentStreak = streak['currentStreak'] as int? ?? 0;
      final longestStreak = streak['longestStreak'] as int? ?? 0;
      
      final milestones = [
        {'days': 3, 'badge': '🔥 Fire Starter', 'earned': currentStreak >= 3, 'daysToGo': currentStreak < 3 ? 3 - currentStreak : 0},
        {'days': 7, 'badge': '⚡ Week Warrior', 'earned': currentStreak >= 7, 'daysToGo': currentStreak < 7 ? 7 - currentStreak : 0},
        {'days': 14, 'badge': '🏆 Two Week Champion', 'earned': currentStreak >= 14, 'daysToGo': currentStreak < 14 ? 14 - currentStreak : 0},
        {'days': 30, 'badge': '👑 Monthly Master', 'earned': currentStreak >= 30, 'daysToGo': currentStreak < 30 ? 30 - currentStreak : 0},
      ];
      
      setState(() {
        _streakData = {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'milestones': milestones,
        };
      });
    } catch (e) {
      debugPrint('Error loading streak data: $e');
      _streakData = {'currentStreak': 0, 'longestStreak': 0, 'milestones': []};
    }
  }

  void _calculateAchievements() {
    final achievements = <Map<String, dynamic>>[];
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;
    final overallAccuracy = _stats['overallAccuracy']?.toDouble() ?? 0.0;
    final pronunciationAccuracy = (_pronunciationScore['pronunciationAccuracy'] ?? 0.0).toDouble();
    final masteredWords = _wordMastery['masteredWords'] ?? 0;
    final currentStreak = _streakData['currentStreak'] ?? 0;
    
    if (totalQuizzes >= 10) achievements.add({'name': 'Quiz Master', 'icon': Icons.quiz, 'color': Colors.blue, 'earned': true});
    if (totalQuizzes >= 50) achievements.add({'name': 'Quiz Champion', 'icon': Icons.emoji_events, 'color': Colors.amber, 'earned': true});
    if (masteredWords >= 20) achievements.add({'name': 'Word Collector', 'icon': Icons.collections_bookmark, 'color': Colors.green, 'earned': true});
    if (masteredWords >= 100) achievements.add({'name': 'Vocabulary Master', 'icon': Icons.library_books, 'color': Colors.purple, 'earned': true});
    if (overallAccuracy >= 80) achievements.add({'name': 'Accuracy Expert', 'icon': Icons.gps_fixed, 'color': Colors.red, 'earned': true});
    if (pronunciationAccuracy >= 75) achievements.add({'name': 'Pronunciation Pro', 'icon': Icons.mic, 'color': Colors.pink, 'earned': true});
    if (masteredWords >= 10) achievements.add({'name': 'Word Master', 'icon': Icons.star, 'color': Colors.orange, 'earned': true});
    if (currentStreak >= 7) achievements.add({'name': 'Week Warrior', 'icon': Icons.local_fire_department, 'color': Colors.deepOrange, 'earned': true});
    if (currentStreak >= 30) achievements.add({'name': 'Monthly Master', 'icon': Icons.calendar_month, 'color': Colors.indigo, 'earned': true});
    
    setState(() {
      _achievements = achievements;
    });
  }

  void _generateMotivationalMessage() {
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;
    final overallAccuracy = _stats['overallAccuracy']?.toDouble() ?? 0.0;
    final currentStreak = _streakData['currentStreak'] ?? 0;
    
    String message;
    if (totalQuizzes == 0) {
      message = "🌟 Start your Bisaya learning journey today! Take your first quiz.";
    } else if (currentStreak >= 7) {
      message = "🔥 Amazing! You're on a $currentStreak-day streak. Keep the momentum!";
    } else if (overallAccuracy >= 80) {
      message = "🎯 Excellent accuracy! You're mastering Bisaya quickly!";
    } else if (overallAccuracy >= 60) {
      message = "📈 Good progress! Keep practicing to improve your accuracy.";
    } else {
      message = "💪 Every expert was once a beginner. Keep learning!";
    }
    
    setState(() {
      _motivationalMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final cardColor = isDark ? const Color(0xFF1A2E4A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: accentColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your progress...',
                    style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProgress,
              color: accentColor,
              child: CustomScrollView(
                slivers: [
                  // Modern Gradient Header
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _headerAnimation,
                      child: _buildGradientHeader(textColor, accentColor),
                    ),
                  ),
                  
                  // Content
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _cardsAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Motivational Message
                            if (_motivationalMessage.isNotEmpty)
                              _buildMotivationalCard(cardColor, textColor),
                            const SizedBox(height: 16),
                            
                            // Quick Stats Row
                            _buildQuickStatsRow(cardColor, textColor, accentColor),
                            const SizedBox(height: 20),
                            
                            // Streak Card
                            _buildStreakCard(cardColor, textColor),
                            const SizedBox(height: 20),
                            
                            // Achievements
                            if (_achievements.isNotEmpty)
                              _buildAchievementsCard(cardColor, textColor),
                            if (_achievements.isNotEmpty)
                              const SizedBox(height: 20),
                            
                            // Word Mastery Card
                            _buildWordMasteryCard(cardColor, textColor, accentColor),
                            const SizedBox(height: 20),
                            
                            // Performance Chart
                            _buildPerformanceChart(cardColor, textColor, accentColor),
                            const SizedBox(height: 20),
                            
                            // Learning Analytics
                            _buildLearningAnalytics(cardColor, textColor, accentColor),
                            const SizedBox(height: 20),
                            
                            // Quiz History
                            _buildQuizHistoryCard(cardColor, textColor, accentColor),
                            const SizedBox(height: 20),
                            
                            // Action Buttons
                            _buildActionButtons(cardColor, textColor, accentColor),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGradientHeader(Color textColor, Color accentColor) {
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;
    final overallAccuracy = _stats['overallAccuracy']?.toDouble() ?? 0.0;
    final currentStreak = _streakData['currentStreak'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, kAccent, kPrimary.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              // App Bar Row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_streakData['currentStreak'] ?? 0} day streak',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress & Reports',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Track your Bisaya learning journey',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Stats Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderStat('$currentStreak', 'Streak', Icons.local_fire_department_rounded),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _buildHeaderStat('$totalQuizzes', 'Quizzes', Icons.quiz_rounded),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _buildHeaderStat('${overallAccuracy.toStringAsFixed(0)}%', 'Accuracy', Icons.check_circle_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _motivationalMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(Color cardColor, Color textColor, Color accentColor) {
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;
    final masteredWords = _wordMastery['masteredWords'] ?? 0;
    final currentStreak = _streakData['currentStreak'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.quiz_rounded,
            value: '$totalQuizzes',
            label: 'Quizzes',
            color: Colors.purple,
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_fire_department_rounded,
            value: '$currentStreak',
            label: 'Day Streak',
            color: Colors.orange,
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.psychology_rounded,
            value: '$masteredWords',
            label: 'Mastered',
            color: Colors.green,
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
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
              fontSize: 11,
              color: textColor.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(Color cardColor, Color textColor) {
    final currentStreak = _streakData['currentStreak'] ?? 0;
    final longestStreak = _streakData['longestStreak'] ?? 0;
    final milestones = (_streakData['milestones'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Streak',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Best: $longestStreak days',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$currentStreak',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'days',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Milestones',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ...milestones.take(3).map((milestone) {
              final days = milestone['days'] as int;
              final badge = milestone['badge'] as String;
              final earned = milestone['earned'] as bool;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      earned ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: earned ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$days days - $badge',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: earned ? textColor : textColor.withValues(alpha: 0.5),
                          fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (earned)
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementsCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Achievements',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_achievements.length} earned',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _achievements.map((achievement) {
              final name = achievement['name'] as String;
              final icon = achievement['icon'] as IconData;
              final color = achievement['color'] as Color;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWordMasteryCard(Color cardColor, Color textColor, Color accentColor) {
    final masteredWords = _wordMastery['masteredWords'] ?? 0;
    final learningWords = _wordMastery['learningWords'] ?? 0;
    final totalWords = _wordMastery['totalWords'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Word Mastery',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMasteryStat('Mastered', '$masteredWords', Colors.green, textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMasteryStat('Learning', '$learningWords', Colors.orange, textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMasteryStat('Total', '$totalWords', accentColor, textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryStat(String label, String value, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(Color cardColor, Color textColor, Color accentColor) {
    final totalQuestions = _stats['totalQuestionsAnswered'] ?? 0;
    final correctAnswers = _stats['correctAnswers'] ?? 0;
    final overallAccuracy = _stats['overallAccuracy']?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pie_chart_rounded, color: accentColor, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Quiz Performance',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (totalQuestions == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'Take quizzes to see your performance!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: correctAnswers.toDouble(),
                            title: '${overallAccuracy.toStringAsFixed(0)}%',
                            color: Colors.green,
                            radius: 50,
                            titleStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: (totalQuestions - correctAnswers).toDouble(),
                            title: '',
                            color: Colors.red.withValues(alpha: 0.6),
                            radius: 45,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Correct', correctAnswers, Colors.green, textColor),
                      const SizedBox(height: 8),
                      _buildLegendItem('Incorrect', totalQuestions - correctAnswers, Colors.red, textColor),
                      const SizedBox(height: 16),
                      Text(
                        'Total: $totalQuestions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningAnalytics(Color cardColor, Color textColor, Color accentColor) {
    final weeklyTotal = _dailyWordAcquisition.values.fold(0, (sum, value) => sum + value);
    final average = _dailyWordAcquisition.isEmpty
        ? '0.0'
        : (weeklyTotal / _dailyWordAcquisition.length).toStringAsFixed(1);
    final maxWords = _dailyWordAcquisition.isEmpty
        ? 0
        : _dailyWordAcquisition.values.reduce((a, b) => a > b ? a : b);
    final bestDay = _dailyWordAcquisition.isEmpty
        ? ''
        : _dailyWordAcquisition.entries.firstWhere((e) => e.value == maxWords, orElse: () => _dailyWordAcquisition.entries.first).key;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Colors.teal, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Learning Velocity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_dailyWordAcquisition.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 48, color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'Start learning to track your velocity!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxWords > 0 ? maxWords + 5.0 : 10.0,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[value.toInt()],
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 5 == 0) {
                            return Text(
                              value.toInt().toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: textColor.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _dailyWordAcquisition.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final dayData = entry.value;
                    final words = dayData.value;
                    final isBest = bestDay.isNotEmpty && dayData.key == bestDay;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: words.toDouble(),
                          gradient: isBest
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.green, Colors.green.shade300],
                                )
                              : LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [accentColor, kPrimary],
                                ),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly: $weeklyTotal words',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Daily avg: $average words',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (weeklyTotal > 10)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Great week!',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizHistoryCard(Color cardColor, Color textColor, Color accentColor) {
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded, color: Colors.purple, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Quizzes',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalQuizzes total',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_quizResults.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No quizzes taken yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._quizResults.take(5).map((quiz) {
              final correct = quiz['correctAnswers'] ?? quiz['score'] ?? 0;
              final total = quiz['totalQuestions'] ?? quiz['total'] ?? 1;
              final percentage = total > 0 ? (correct / total) * 100 : 0;
              final timestamp = quiz['timestamp'];
              String date = 'Unknown';
              if (timestamp is Timestamp) {
                final d = timestamp.toDate();
                date = '${d.day}/${d.month}/${d.year}';
              } else if (timestamp is String) {
                date = timestamp;
              }
              final type = quiz['quizType'] ?? quiz['type'] ?? 'Quiz';

              Color performanceColor;
              IconData performanceIcon;
              if (percentage >= 80) {
                performanceColor = Colors.green;
                performanceIcon = Icons.emoji_events;
              } else if (percentage >= 60) {
                performanceColor = Colors.orange;
                performanceIcon = Icons.thumb_up;
              } else {
                performanceColor = Colors.red;
                performanceIcon = Icons.school;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: performanceColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: performanceColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: performanceColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(performanceIcon, color: performanceColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              date,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: performanceColor,
                            ),
                          ),
                          Text(
                            '$correct/$total',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color cardColor, Color textColor, Color accentColor) {
    return Column(
      children: [
        // Take Quiz Button
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizSelectionScreen(
                  isDarkMode: widget.isDarkMode,
                  onToggleDarkMode: widget.onToggleDarkMode,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimary, kAccent],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.quiz_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Take a Quiz',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Download Reports Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.download_rounded, color: accentColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Download Reports',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDownloadButton(
                      icon: Icons.assessment_rounded,
                      label: 'Full Report',
                      onTap: () => _downloadReport('full'),
                      cardColor: cardColor,
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDownloadButton(
                      icon: Icons.calendar_today_rounded,
                      label: 'Weekly',
                      onTap: () => _downloadReport('weekly'),
                      cardColor: cardColor,
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDownloadButton(
                      icon: Icons.history_rounded,
                      label: 'Quiz History',
                      onTap: () => _downloadReport('quiz'),
                      cardColor: cardColor,
                      accentColor: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color cardColor,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: _isDownloading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport(String type) async {
    setState(() => _isDownloading = true);
    
    bool success = false;
    String reportName = '';
    
    try {
      switch (type) {
        case 'full':
          success = await _reportService.downloadProgressReport();
          reportName = 'Full Progress Report';
          break;
        case 'weekly':
          success = await _reportService.downloadWeeklyReport();
          reportName = 'Weekly Report';
          break;
        case 'quiz':
          success = await _reportService.downloadQuizHistory();
          reportName = 'Quiz History';
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  success 
                      ? '$reportName downloaded successfully!'
                      : 'Failed to download $reportName',
                ),
              ],
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
