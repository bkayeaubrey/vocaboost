import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'adaptive_flashcard_screen.dart';
import 'voice_quiz_screen.dart';
import 'practice_mode_screen.dart';
import 'daily_challenge_screen.dart';
import 'achievement_screen.dart';
import 'conversation_screen.dart';
import 'hangman_screen.dart';
import 'flashcard_swipe_screen.dart';
import 'weekly_progress_screen.dart';
import 'weak_words_screen.dart';
import 'sentence_builder_screen.dart';

class LearningScreen extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const LearningScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Blue Hour Harbor Palette
    const Color kPrimary = Color(0xFF3B5FAE);
    const Color kAccent = Color(0xFF2666B4);
    final Color backgroundColor = isDarkMode ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final Color cardColor = isDarkMode ? const Color(0xFF20304A) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF071B34);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Modern Gradient Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary, kAccent, Color(0xFF1E4A8E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 28,
              left: 20,
              right: 20,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                    GestureDetector(
                      onTap: () => onToggleDarkMode(!isDarkMode),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Logo and title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📚', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Learning Center',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Master Bisaya your way!',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Quick Actions Row
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    context: context,
                    emoji: '🎯',
                    label: 'Daily\nChallenge',
                    color: const Color(0xFFF59E0B),
                    cardColor: cardColor,
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DailyChallengeScreen(
                          isDarkMode: isDarkMode,
                          onToggleDarkMode: onToggleDarkMode,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    context: context,
                    emoji: '🏆',
                    label: 'Badges &\nAchievements',
                    color: const Color(0xFFEAB308),
                    cardColor: cardColor,
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AchievementScreen(
                          isDarkMode: isDarkMode,
                          onToggleDarkMode: onToggleDarkMode,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Core Learning Section
            _buildSectionHeader('📖 Core Learning', textColor),
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '🧠',
              title: 'Adaptive Flashcards',
              subtitle: 'AI-powered contextual learning',
              color: kAccent,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdaptiveFlashcardScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '👆',
              title: 'Flashcard Swipe',
              subtitle: 'Quick review with swipe gestures',
              color: const Color(0xFF8B5CF6),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardSwipeScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '💬',
              title: 'Conversation Mode',
              subtitle: 'Practice real-world dialogues',
              color: const Color(0xFF06B6D4),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Practice Section
            _buildSectionHeader('🎮 Practice & Quizzes', textColor),
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '✏️',
              title: 'Fill-in-the-Blank',
              subtitle: 'Fun interactive exercises',
              color: const Color(0xFF10B981),
              cardColor: cardColor,
              textColor: textColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PracticeModeScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '🎤',
              title: 'Voice Quiz',
              subtitle: 'Practice your pronunciation',
              color: const Color(0xFFEC4899),
              cardColor: cardColor,
              textColor: textColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VoiceQuizScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Progress & Review Section
            _buildSectionHeader('📊 Progress & Review', textColor),
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '📈',
              title: 'Weekly Report',
              subtitle: 'Track your learning journey',
              color: const Color(0xFF14B8A6),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeeklyProgressScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '🔄',
              title: 'Weak Words',
              subtitle: 'Focus on words you struggle with',
              color: const Color(0xFFF97316),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeakWordsScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Games Section
            _buildSectionHeader('🎲 Word Games', textColor),
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '🧍',
              title: 'Hangman',
              subtitle: 'Guess the Bisaya word',
              color: const Color(0xFF64748B),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HangmanScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildLearningCard(
              context: context,
              emoji: '🧩',
              title: 'Sentence Builder',
              subtitle: 'Arrange words to form sentences',
              color: const Color(0xFFA855F7),
              cardColor: cardColor,
              textColor: textColor,
              isNew: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SentenceBuilderScreen(
                    isDarkMode: isDarkMode,
                    onToggleDarkMode: onToggleDarkMode,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required String emoji,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardColor, cardColor.withValues(alpha: 0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningCard({
    required BuildContext context,
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
    bool isNew = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardColor, cardColor.withValues(alpha: 0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '✨ NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

