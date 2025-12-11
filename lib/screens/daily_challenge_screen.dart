import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/daily_challenge_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/widgets/badge_notification.dart';
import 'package:confetti/confetti.dart';

/// Color constants
const Color kPrimary = Color(0xFF3B5FAE);
const Color kAccent = Color(0xFF2666B4);
const Color kDarkBg = Color(0xFF071B34);
const Color kDarkCard = Color(0xFF20304A);

class DailyChallengeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const DailyChallengeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> 
    with SingleTickerProviderStateMixin {
  final DailyChallengeService _challengeService = DailyChallengeService();
  final XPService _xpService = XPService();
  final AchievementService _achievementService = AchievementService();
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  
  List<Map<String, dynamic>> _challenges = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadChallenges();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    try {
      final challenges = await _challengeService.getTodaysChallenges();
      final stats = await _challengeService.getChallengeStats();
      setState(() {
        _challenges = challenges;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading challenges: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _claimReward(Map<String, dynamic> challenge) async {
    if (challenge['completed'] != true || challenge['claimed'] == true) return;
    if (_claimingId != null) return;

    final challengeId = challenge['id'] as String;
    setState(() => _claimingId = challengeId);

    try {
      // Mark as claimed in Firebase
      final success = await _challengeService.claimChallengeReward(challengeId);
      if (!success) {
        throw Exception('Failed to claim reward');
      }

      final xpReward = (challenge['xpReward'] as num?)?.toInt() ?? 50;
      await _xpService.earnXP(
        amount: xpReward,
        activityType: 'daily_challenge',
      );

      _confettiController.play();

      // Check streak achievements
      final currentStreak = (_stats['currentStreak'] as num?)?.toInt() ?? 0;
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(
        currentStreak: currentStreak,
      );
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 8),
                Text('+$xpReward XP earned! 🎉'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      await _loadChallenges();
    } catch (e) {
      debugPrint('Error claiming reward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming reward: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claimingId = null);
      }
    }
  }

  IconData _getChallengeIcon(String iconName) {
    switch (iconName) {
      case 'school': return Icons.school_rounded;
      case 'quiz': return Icons.quiz_rounded;
      case 'style': return Icons.style_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      case 'local_fire_department': return Icons.local_fire_department_rounded;
      case 'mic': return Icons.mic_rounded;
      case 'timer': return Icons.timer_rounded;
      case 'category': return Icons.category_rounded;
      default: return Icons.star_rounded;
    }
  }

  Color _getChallengeColor(String type) {
    switch (type) {
      case 'learn': return const Color(0xFF4CAF50);
      case 'quiz': return const Color(0xFF2196F3);
      case 'flashcard': return const Color(0xFF9C27B0);
      case 'practice': return const Color(0xFFFF9800);
      case 'streak': return const Color(0xFFF44336);
      case 'voice': return const Color(0xFF00BCD4);
      case 'time': return const Color(0xFF795548);
      case 'category': return const Color(0xFF607D8B);
      default: return kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final backgroundColor = isDark ? kDarkBg : const Color(0xFFC7D4E8);
    final cardColor = isDark ? kDarkCard : Colors.white;
    final textColor = isDark ? Colors.white : kDarkBg;

    final completedCount = _challenges.where((c) => c['completed'] == true).length;
    final totalCount = _challenges.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: kPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: _loadChallenges,
                  ),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: Colors.white,
                    ),
                    onPressed: () => widget.onToggleDarkMode(!isDark),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kPrimary, kAccent],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Challenges',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete challenges to earn bonus XP!',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const Spacer(),
                            // Progress indicator
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$completedCount of $totalCount completed',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: totalCount > 0 
                                              ? completedCount / totalCount 
                                              : 0,
                                          backgroundColor: Colors.white.withOpacity(0.3),
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_stats['currentStreak'] ?? 0}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle_rounded,
                          value: '${_stats['totalCompleted'] ?? 0}',
                          label: 'Completed',
                          color: Colors.green,
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department_rounded,
                          value: '${_stats['currentStreak'] ?? 0}',
                          label: 'Day Streak',
                          color: Colors.orange,
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.stars_rounded,
                          value: '${_stats['totalXPEarned'] ?? 0}',
                          label: 'XP Earned',
                          color: Colors.amber,
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: kAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Today's Tasks",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading or Challenges
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: kAccent)),
                )
              else if (_challenges.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 64,
                          color: textColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No challenges available',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildChallengeCard(
                        challenge: _challenges[index],
                        cardColor: cardColor,
                        textColor: textColor,
                        index: index,
                      ),
                      childCount: _challenges.length,
                    ),
                  ),
                ),
            ],
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
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
                Colors.red,
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard({
    required Map<String, dynamic> challenge,
    required Color cardColor,
    required Color textColor,
    required int index,
  }) {
    final isCompleted = challenge['completed'] == true;
    final isClaimed = challenge['claimed'] == true;
    final isClaiming = _claimingId == challenge['id'];
    final type = challenge['type'] as String? ?? 'learn';
    final color = _getChallengeColor(type);
    
    final progress = (challenge['currentProgress'] as num?)?.toInt() ?? 0;
    final target = challenge['targetCount'] ?? 
                   challenge['targetScore'] ?? 
                   challenge['targetMinutes'] ?? 
                   1;
    final progressPercent = (progress / target).clamp(0.0, 1.0);
    final xpReward = (challenge['xpReward'] as num?)?.toInt() ?? 50;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isCompleted
              ? Border.all(
                  color: isClaimed ? Colors.grey.shade400 : Colors.green,
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: (isCompleted && !isClaimed)
                  ? Colors.green.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isCompleted
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [color.withOpacity(0.8), color],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isCompleted ? Colors.green : color)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : _getChallengeIcon(challenge['icon'] ?? 'star'),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge['title'] ?? 'Challenge',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              decoration: isClaimed 
                                  ? TextDecoration.lineThrough 
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            challenge['description'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // XP Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.orange.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$xpReward',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Progress section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: progressPercent,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isCompleted
                                          ? [Colors.green.shade400, Colors.green.shade600]
                                          : [color.withOpacity(0.7), color],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$progress / $target',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? Colors.green : color,
                          ),
                        ),
                      ],
                    ),

                    // Claim button (only for completed, unclaimed challenges)
                    if (isCompleted && !isClaimed) ...[
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.03),
                            child: child,
                          );
                        },
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isClaiming ? null : () => _claimReward(challenge),
                            icon: isClaiming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.card_giftcard_rounded),
                            label: Text(
                              isClaiming ? 'Claiming...' : 'Claim Reward',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: Colors.green.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Claimed badge
                    if (isClaimed) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Reward Claimed',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
