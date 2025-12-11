import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/report_service.dart';

/// Weekly Progress Report Screen
/// Shows detailed weekly stats: words learned, time spent, accuracy, streak days, XP earned
class WeeklyProgressScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;

  const WeeklyProgressScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
  });

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {
  // Theme colors
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);

  final ReportService _reportService = ReportService();

  bool _isLoading = true;
  bool _isDownloading = false;
  
  // Weekly stats
  int _weeklyXP = 0;
  int _wordsLearned = 0;
  int _quizzesCompleted = 0;
  double _averageAccuracy = 0.0;
  int _streakDays = 0;
  List<Map<String, dynamic>> _dailyActivity = [];
  Map<String, int> _activityByType = {};
  String _encouragement = '';

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      // Load XP data
      await _loadXPData(user.uid, weekStartDate);
      
      // Load words data
      await _loadWordsData(user.uid, weekStartDate);
      
      // Load quiz data
      await _loadQuizData(user.uid, weekStartDate);
      
      // Load daily activity for chart
      await _loadDailyActivity(user.uid, weekStartDate);
      
      // Calculate streak
      await _calculateStreak(user.uid);
      
      // Generate encouragement message
      _generateEncouragement();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading weekly data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadXPData(String uid, DateTime weekStart) async {
    try {
      final xpDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('xp_data')
          .doc('current')
          .get();

      if (xpDoc.exists) {
        _weeklyXP = (xpDoc.data()?['weeklyXP'] as num?)?.toInt() ?? 0;
      }

      // Get XP history for activity breakdown
      final xpHistory = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('xp_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      _activityByType = {};
      for (var doc in xpHistory.docs) {
        final data = doc.data();
        final type = data['activityType'] as String? ?? 'other';
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        _activityByType[type] = (_activityByType[type] ?? 0) + amount;
      }
    } catch (e) {
      debugPrint('Error loading XP data: $e');
    }
  }

  Future<void> _loadWordsData(String uid, DateTime weekStart) async {
    try {
      // Use quiz results to count words practiced this week
      final quizSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quiz_results')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      int totalCorrect = 0;
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        totalCorrect += (data['correctAnswers'] as num?)?.toInt() ?? 0;
      }
      _wordsLearned = totalCorrect;
    } catch (e) {
      debugPrint('Error loading words data: $e');
    }
  }

  Future<void> _loadQuizData(String uid, DateTime weekStart) async {
    try {
      final quizSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quiz_results')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      _quizzesCompleted = quizSnapshot.docs.length;
      
      if (_quizzesCompleted > 0) {
        double totalAccuracy = 0;
        for (var doc in quizSnapshot.docs) {
          final data = doc.data();
          final correct = (data['correctAnswers'] as num?)?.toInt() ?? 0;
          final total = (data['totalQuestions'] as num?)?.toInt() ?? 1;
          totalAccuracy += (correct / total) * 100;
        }
        _averageAccuracy = totalAccuracy / _quizzesCompleted;
      }
    } catch (e) {
      debugPrint('Error loading quiz data: $e');
    }
  }

  Future<void> _loadDailyActivity(String uid, DateTime weekStart) async {
    try {
      _dailyActivity = [];
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        // Get XP earned on this day
        final xpSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('xp_history')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        int dayXP = 0;
        for (var doc in xpSnapshot.docs) {
          dayXP += (doc.data()['amount'] as num?)?.toInt() ?? 0;
        }

        _dailyActivity.add({
          'day': dayNames[i],
          'xp': dayXP,
          'isToday': i == DateTime.now().weekday - 1,
        });
      }
    } catch (e) {
      debugPrint('Error loading daily activity: $e');
    }
  }

  Future<void> _calculateStreak(String uid) async {
    try {
      final streakDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('streaks')
          .doc('current')
          .get();

      if (streakDoc.exists) {
        _streakDays = (streakDoc.data()?['currentStreak'] as num?)?.toInt() ?? 0;
      } else {
        // Calculate streak from XP history
        final now = DateTime.now();
        int streak = 0;
        
        for (int i = 0; i < 30; i++) {
          final checkDate = now.subtract(Duration(days: i));
          final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
          final dayEnd = dayStart.add(const Duration(days: 1));

          final activity = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('xp_history')
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
              .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
              .limit(1)
              .get();

          if (activity.docs.isNotEmpty) {
            streak++;
          } else if (i > 0) {
            break;
          }
        }
        _streakDays = streak;
      }
    } catch (e) {
      debugPrint('Error calculating streak: $e');
    }
  }

  void _generateEncouragement() {
    if (_weeklyXP >= 500) {
      _encouragement = "🏆 Outstanding week! You're on fire!";
    } else if (_weeklyXP >= 300) {
      _encouragement = "🌟 Great progress! Keep up the momentum!";
    } else if (_weeklyXP >= 100) {
      _encouragement = "💪 Good effort! Every bit counts!";
    } else if (_weeklyXP > 0) {
      _encouragement = "🌱 You've started! Keep going!";
    } else {
      _encouragement = "📚 Start learning to earn XP!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA);
    final cardColor = widget.isDarkMode ? const Color(0xFF252542) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Weekly Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isDownloading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            onPressed: _isDownloading ? null : _downloadWeeklyReport,
            tooltip: 'Download Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWeeklyData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Week summary header
                    _buildWeekSummaryCard(cardColor, textColor),
                    const SizedBox(height: 20),

                    // Stats grid
                    _buildStatsGrid(cardColor, textColor),
                    const SizedBox(height: 20),

                    // Daily activity chart
                    _buildDailyActivityChart(cardColor, textColor),
                    const SizedBox(height: 20),

                    // Activity breakdown
                    _buildActivityBreakdown(cardColor, textColor),
                    const SizedBox(height: 20),

                    // Achievements this week
                    _buildWeeklyAchievements(cardColor, textColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWeekSummaryCard(Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimary, kAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'This Week',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 36),
              const SizedBox(width: 12),
              Text(
                '$_weeklyXP',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'XP',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _encouragement,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Color cardColor, Color textColor) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatTile(
          icon: Icons.check_circle,
          value: '$_wordsLearned',
          label: 'Correct Answers',
          color: Colors.blue,
          cardColor: cardColor,
          textColor: textColor,
        ),
        _buildStatTile(
          icon: Icons.quiz,
          value: '$_quizzesCompleted',
          label: 'Quizzes Done',
          color: Colors.green,
          cardColor: cardColor,
          textColor: textColor,
        ),
        _buildStatTile(
          icon: Icons.percent,
          value: '${_averageAccuracy.toStringAsFixed(0)}%',
          label: 'Avg Accuracy',
          color: Colors.orange,
          cardColor: cardColor,
          textColor: textColor,
        ),
        _buildStatTile(
          icon: Icons.local_fire_department,
          value: '$_streakDays',
          label: 'Day Streak',
          color: Colors.red,
          cardColor: cardColor,
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildStatTile({
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
              color: textColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyActivityChart(Color cardColor, Color textColor) {
    final maxXP = _dailyActivity.isNotEmpty
        ? _dailyActivity.map((d) => d['xp'] as int).reduce((a, b) => a > b ? a : b)
        : 100;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Activity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxXP * 1.2).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} XP',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _dailyActivity.length) {
                          final day = _dailyActivity[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              day['day'],
                              style: TextStyle(
                                color: day['isToday'] == true ? kPrimary : textColor.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: day['isToday'] == true ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: _dailyActivity.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isToday = data['isToday'] == true;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (data['xp'] as int).toDouble(),
                        color: isToday ? kPrimary : kPrimary.withOpacity(0.5),
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown(Color cardColor, Color textColor) {
    if (_activityByType.isEmpty) {
      return const SizedBox.shrink();
    }

    final typeLabels = {
      'quiz': 'Quizzes',
      'flashcard': 'Flashcards',
      'review': 'Reviews',
      'challenge': 'Challenges',
      'conversation': 'Conversation',
      'lesson': 'Lessons',
      'other': 'Other',
    };

    final typeColors = {
      'quiz': Colors.green,
      'flashcard': Colors.blue,
      'review': Colors.orange,
      'challenge': Colors.purple,
      'conversation': Colors.pink,
      'lesson': Colors.teal,
      'other': Colors.grey,
    };

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XP by Activity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ..._activityByType.entries.map((entry) {
            final label = typeLabels[entry.key] ?? entry.key;
            final color = typeColors[entry.key] ?? Colors.grey;
            final total = _activityByType.values.reduce((a, b) => a + b);
            final percentage = total > 0 ? entry.value / total : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${entry.value} XP',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${(percentage * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyAchievements(Color cardColor, Color textColor) {
    final achievements = <Map<String, dynamic>>[];
    
    if (_wordsLearned >= 10) {
      achievements.add({'icon': '✅', 'title': 'Answer Master', 'desc': '10+ correct answers'});
    }
    if (_quizzesCompleted >= 5) {
      achievements.add({'icon': '🧠', 'title': 'Quiz Master', 'desc': '5+ quizzes completed'});
    }
    if (_averageAccuracy >= 80) {
      achievements.add({'icon': '🎯', 'title': 'Sharp Shooter', 'desc': '80%+ accuracy'});
    }
    if (_streakDays >= 7) {
      achievements.add({'icon': '🔥', 'title': 'Week Warrior', 'desc': '7-day streak'});
    }
    if (_weeklyXP >= 500) {
      achievements.add({'icon': '⭐', 'title': 'XP Champion', 'desc': '500+ XP earned'});
    }

    if (achievements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Keep learning to unlock achievements!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Achievements',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: achievements.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withOpacity(0.1), kAccent.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a['icon'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['title'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        a['desc'],
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadWeeklyReport() async {
    setState(() => _isDownloading = true);
    
    try {
      final success = await _reportService.downloadWeeklyReport();
      
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
                      ? 'Weekly report downloaded successfully!'
                      : 'Failed to download weekly report',
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
