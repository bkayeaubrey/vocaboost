import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'voice_translation_screen.dart';
import 'word_vocabulary_screen.dart';
import 'quiz_selection_screen.dart';
import 'progress_screen.dart';
import 'package:vocaboost/services/word_of_the_day_service.dart';
import 'package:vocaboost/services/user_service.dart';

class DashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;

  const DashboardScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleDarkMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late bool _isDarkMode;
  final WordOfTheDayService _wordOfTheDayService = WordOfTheDayService();
  final UserService _userService = UserService();
  Map<String, String>? _wordOfTheDay;
  bool _isLoadingWord = true;
  String? _profilePictureUrl;
  String? _fullname;
  String? _username;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadWordOfTheDay();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await _userService.getUserData();
      if (mounted) {
        setState(() {
          _profilePictureUrl = userData?['profilePictureUrl'] as String?;
          _fullname = userData?['fullname'] as String?;
          _username = userData?['username'] as String?;
        });
      }
    } catch (e) {
      // Silently fail - will show default avatar
    }
  }

  String _getInitials() {
    if (_fullname != null && _fullname!.isNotEmpty) {
      final parts = _fullname!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
      }
      return _fullname![0].toUpperCase();
    }
    if (_username != null && _username!.isNotEmpty) {
      return _username![0].toUpperCase();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email![0].toUpperCase();
    }
    return '?';
  }

  Future<void> _loadWordOfTheDay() async {
    setState(() => _isLoadingWord = true);
    try {
      final word = await _wordOfTheDayService.getWordOfTheDay();
      setState(() {
        _wordOfTheDay = word;
        _isLoadingWord = false;
      });
    } catch (e) {
      setState(() => _isLoadingWord = false);
      // Silently fail - will show fallback
    }
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    widget.onToggleDarkMode?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🎨 Blue Hour Colors
    final backgroundColor = _isDarkMode ? const Color(0xFF071B34) : const Color(0xFFC7D4E8);
    final textColor = _isDarkMode ? const Color(0xFFC7D4E8) : const Color(0xFF071B34);
    final accentColor = _isDarkMode ? const Color(0xFF2666B4) : const Color(0xFF3B5FAE);
    final drawerBg = _isDarkMode ? const Color(0xFF20304A) : Colors.white;
    final appBarColor = _isDarkMode ? const Color(0xFF071B34) : const Color(0xFF3B5FAE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 36,
              width: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading logo: $error');
                return Icon(Icons.language, color: accentColor, size: 18);
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'VocaBoost',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => _toggleDarkMode(!_isDarkMode),
          ),
        ],
      ),

      // Drawer
      drawer: Drawer(
        backgroundColor: drawerBg,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: appBarColor),
              currentAccountPicture: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                  // Reload profile after returning from profile screen
                  _loadUserProfile();
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: _profilePictureUrl != null
                      ? NetworkImage(_profilePictureUrl!)
                      : null,
                  child: _profilePictureUrl == null
                      ? Text(
                          _getInitials(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        )
                      : null,
                ),
              ),
              accountName: Text(
                _fullname ?? _username ?? user?.email?.split('@').first ?? 'Guest User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? 'Not logged in'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(Icons.home, 'Home', () => Navigator.pop(context), accentColor, textColor),
                  _buildMenuItem(Icons.quiz, 'Take a Quiz', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizSelectionScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                  _buildMenuItem(Icons.mic, 'AI Assistant', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceTranslationScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                  _buildMenuItem(Icons.translate, 'Word Vocabulary', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WordVocabularyScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                  _buildMenuItem(Icons.bookmark, 'Review Saved Words', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SavedScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                  _buildMenuItem(Icons.bar_chart, 'Progress and Reports', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProgressScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                  _buildMenuItem(Icons.settings, 'Settings', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, accentColor, textColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),

      // Body
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_circle, size: 70, color: accentColor),
              const SizedBox(height: 16),
              Text(
                'Word of the Day',
                style: TextStyle(color: accentColor, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingWord)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: accentColor),
                )
              else if (_wordOfTheDay != null) ...[
                Text(
                  '"${_wordOfTheDay!['bisaya'] ?? ''}" — means "${_wordOfTheDay!['english'] ?? ''}"',
                  style: TextStyle(fontSize: 18, color: textColor.withOpacity(0.9)),
                ),
                if (_wordOfTheDay!['pronunciation']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Pronunciation: ${_wordOfTheDay!['pronunciation']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ] else
                Text(
                  'Unable to load word of the day',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizSelectionScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.quiz),
                label: const Text('Take a Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          user != null ? 'Logged in as: ${user.email}' : 'Not logged in',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, Color iconColor, Color textColor) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor, fontSize: 16)),
      onTap: onTap,
    );
  }
}
