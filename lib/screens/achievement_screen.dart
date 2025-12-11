import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/achievement_service.dart';

class AchievementScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const AchievementScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  final AchievementService _achievementService = AchievementService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _badges = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'All', 'icon': Icons.apps},
    {'id': 'learning', 'name': 'Learning', 'icon': Icons.school},
    {'id': 'quiz', 'name': 'Quiz', 'icon': Icons.quiz},
    {'id': 'streak', 'name': 'Streak', 'icon': Icons.local_fire_department},
    {'id': 'xp', 'name': 'XP', 'icon': Icons.stars},
    {'id': 'special', 'name': 'Special', 'icon': Icons.auto_awesome},
    {'id': 'games', 'name': 'Games', 'icon': Icons.extension},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedCategory = _categories[_tabController.index]['id'] as String;
      });
    });
    _loadBadges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    try {
      final badges = await _achievementService.getBadgesWithStatus();
      final stats = await _achievementService.getBadgeStats();
      setState(() {
        _badges = badges;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBadges {
    if (_selectedCategory == 'all') return _badges;
    return _badges.where((b) => b['category'] == _selectedCategory).toList();
  }

  List<Map<String, dynamic>> get _unlockedBadges {
    return _filteredBadges.where((b) => b['unlocked'] == true).toList();
  }

  List<Map<String, dynamic>> get _lockedBadges {
    return _filteredBadges.where((b) => b['unlocked'] != true).toList();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star': return Icons.star;
      case 'collections_bookmark': return Icons.collections_bookmark;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'emoji_events': return Icons.emoji_events;
      case 'school': return Icons.school;
      case 'quiz': return Icons.quiz;
      case 'assignment_turned_in': return Icons.assignment_turned_in;
      case 'verified': return Icons.verified;
      case 'military_tech': return Icons.military_tech;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'whatshot': return Icons.whatshot;
      case 'bolt': return Icons.bolt;
      case 'flash_on': return Icons.flash_on;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'stars': return Icons.stars;
      case 'grade': return Icons.grade;
      case 'diamond': return Icons.diamond;
      case 'rocket_launch': return Icons.rocket_launch;
      case 'nightlight': return Icons.nightlight;
      case 'wb_sunny': return Icons.wb_sunny;
      case 'explore': return Icons.explore;
      case 'record_voice_over': return Icons.record_voice_over;
      case 'extension': return Icons.extension;
      case 'chat': return Icons.chat;
      default: return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color kPrimary = const Color(0xFF3B5FAE);
    final Color accentColor = const Color(0xFF2666B4);
    final Color backgroundColor = widget.isDarkMode ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = widget.isDarkMode ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = widget.isDarkMode ? Colors.white : const Color(0xFF071B34);

    final unlockedCount = _stats['unlocked'] ?? 0;
    final totalCount = _stats['total'] ?? 0;
    final progressPercent = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Achievements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _categories.map((cat) => Tab(
            icon: Icon(cat['icon'] as IconData, size: 20),
            text: cat['name'] as String,
          )).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, kPrimary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                              const SizedBox(width: 12),
                              Text(
                                '$unlockedCount / $totalCount',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Badges Unlocked',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.amber),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Unlocked Badges Section
                    if (_unlockedBadges.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.check_circle,
                        title: 'Unlocked',
                        count: _unlockedBadges.length,
                        color: Colors.green,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _unlockedBadges.length,
                        itemBuilder: (context, index) {
                          final badge = _unlockedBadges[index];
                          return _buildBadgeCard(
                            badge: badge,
                            cardColor: cardColor,
                            textColor: textColor,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Locked Badges Section
                    if (_lockedBadges.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.lock_outline,
                        title: 'Locked',
                        count: _lockedBadges.length,
                        color: Colors.grey,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _lockedBadges.length,
                        itemBuilder: (context, index) {
                          final badge = _lockedBadges[index];
                          return _buildBadgeCard(
                            badge: badge,
                            cardColor: cardColor,
                            textColor: textColor,
                          );
                        },
                      ),
                    ],
                    
                    // Empty state
                    if (_unlockedBadges.isEmpty && _lockedBadges.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 48),
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 64,
                              color: textColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No badges in this category',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard({
    required Map<String, dynamic> badge,
    required Color cardColor,
    required Color textColor,
  }) {
    final isUnlocked = badge['unlocked'] == true;
    final badgeColor = Color(badge['color'] as int? ?? 0xFF9E9E9E);

    return GestureDetector(
      onTap: () => _showBadgeDetails(badge),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isUnlocked
              ? Border.all(color: badgeColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? badgeColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(badge['icon'] ?? 'emoji_events'),
                color: isUnlocked ? badgeColor : Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge['name'] ?? 'Badge',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? textColor : textColor.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isUnlocked)
              Icon(
                Icons.lock,
                size: 14,
                color: textColor.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final isUnlocked = badge['unlocked'] == true;
    final badgeColor = Color(badge['color'] as int? ?? 0xFF9E9E9E);
    final requirement = badge['requirement'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF20304A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF071B34);
        
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? badgeColor.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(badge['icon'] ?? 'emoji_events'),
                  color: isUnlocked ? badgeColor : Colors.grey,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge['name'] ?? 'Badge',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge['description'] ?? '',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isUnlocked && badge['unlockedAt'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked!',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (requirement != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getRequirementText(requirement),
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _getRequirementText(Map<String, dynamic> requirement) {
    final type = requirement['type'] as String?;
    final count = requirement['count'] as int?;

    switch (type) {
      case 'words_learned':
        return 'Learn $count words';
      case 'quizzes_completed':
        return 'Complete $count quizzes';
      case 'perfect_quiz':
        return 'Get $count perfect scores';
      case 'streak':
        return 'Maintain $count day streak';
      case 'total_xp':
        return 'Earn $count XP';
      case 'voice_exercises':
        return 'Complete $count voice exercises';
      case 'hangman_wins':
        return 'Win $count Hangman games';
      case 'conversations':
        return 'Complete $count conversations';
      case 'categories':
        return 'Explore $count categories';
      case 'study_time':
        final hour = requirement['hour'] as int?;
        if (hour != null && hour >= 22) {
          return 'Study after 10 PM';
        } else {
          return 'Study before 7 AM';
        }
      default:
        return 'Complete the requirement';
    }
  }
}
