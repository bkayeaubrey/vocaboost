import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'voice_translation_screen.dart';
import 'word_vocabulary_screen.dart';
import 'learning_screen.dart';
import 'progress_screen.dart';
import 'favorites_screen.dart';
import 'daily_challenge_screen.dart';
import 'achievement_screen.dart';
import 'weekly_progress_screen.dart';
import 'weak_words_screen.dart';
import 'package:vocaboost/services/word_of_the_day_service.dart';
import 'package:vocaboost/services/user_service.dart';
import 'package:vocaboost/services/tts_service.dart';
import 'package:vocaboost/services/daily_challenge_service.dart';
import 'package:vocaboost/services/achievement_service.dart';
import 'package:vocaboost/services/spaced_repetition_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  final DailyChallengeService _dailyChallengeService = DailyChallengeService();
  final AchievementService _achievementService = AchievementService();
  final SpacedRepetitionService _spacedRepetitionService = SpacedRepetitionService();
  Map<String, String>? _wordOfTheDay;
  bool _isLoadingWord = true;
  String? _profilePictureUrl;
  String? _fullname;
  String? _username;
  
  // Quick access widget data
  List<Map<String, dynamic>> _todaysChallenges = [];
  int _completedChallenges = 0;
  int _unlockedBadges = 0;
  int _totalBadges = 0;
  int _wordsToReview = 0;
  int _totalXP = 0;
  bool _isLoadingQuickAccess = true;
  
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;
  bool _isWordFavorited = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadWordOfTheDay();
    _loadUserProfile();
    _loadQuickAccessData();
    _initializeTts();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      setState(() {
        _isDarkMode = widget.isDarkMode;
      });
    }
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // Try to set Bisaya/Filipino language with fallbacks
      List<String> languageCodes = ['fil-PH', 'tl-PH', 'fil', 'tl', 'ceb-PH', 'ceb'];
      String? selectedLanguage;
      
      // Get available languages
      List<dynamic> languages = await _flutterTts.getLanguages;
      
      // Try to find Bisaya/Filipino language
      for (String code in languageCodes) {
        if (languages.contains(code)) {
          selectedLanguage = code;
          break;
        }
      }
      
      // If no Filipino/Bisaya found, try to find any Philippine language
      if (selectedLanguage == null) {
        for (dynamic lang in languages) {
          String langStr = lang.toString().toLowerCase();
          if (langStr.contains('ph') || langStr.contains('filipino') || 
              langStr.contains('tagalog') || langStr.contains('bisaya') ||
              langStr.contains('cebuano')) {
            selectedLanguage = lang.toString();
            break;
          }
        }
      }
      
      // Set language (use selected or default to en-US)
      await _flutterTts.setLanguage(selectedLanguage ?? 'en-US');
      if (selectedLanguage != null) {
        debugPrint('✅ TTS language set to: $selectedLanguage');
      } else {
        debugPrint('⚠️ Using default English TTS (Bisaya not available)');
      }
      
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      // Fallback to English if initialization fails
      try {
        await _flutterTts.setLanguage('en-US');
        _isTtsInitialized = true;
      } catch (e2) {
        _isTtsInitialized = false;
      }
    }
  }

  // ignore: unused_element
  Future<void> _speakWord(String text) async {
    if (!_isTtsInitialized) {
      await _initializeTts();
    }
    
    try {
      // Try Google Cloud TTS for native Bisaya pronunciation first
      final audioContent = await TTSService().synthesizeBisaya(text);
      if (audioContent != null) {
        print('✅ Using Google Cloud TTS for: $text');
        // For web, the audio would be played differently
        // For mobile, use audioplayers
        await _playWithAudioplayers(audioContent);
      } else {
        // Fallback to Flutter TTS
        print('⚠️ Falling back to Flutter TTS for: $text');
        await _flutterTts.speak(text);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
      // Final fallback
      try {
        await _flutterTts.speak(text);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to play audio'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _playWithAudioplayers(String base64Audio) async {
    try {
      // Placeholder for audio playback
      // This would be implemented based on platform (web vs mobile)
      print('Audio ready: ${base64Audio.substring(0, 50)}...');
    } catch (e) {
      print('Error playing audio: $e');
    }
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

  Future<void> _loadQuickAccessData() async {
    setState(() => _isLoadingQuickAccess = true);
    try {
      // Load daily challenges
      final challenges = await _dailyChallengeService.getTodaysChallenges();
      final completed = challenges.where((c) => c['completed'] == true).length;
      
      // Load achievement stats
      final allBadges = _achievementService.getAllBadges();
      final unlocked = await _achievementService.getUnlockedBadges();
      
      // Load spaced repetition words due
      final dueWords = await _spacedRepetitionService.getWordsDueForReview();
      
      // Load total XP
      final xpService = XPService();
      final totalXP = await xpService.getTotalXP();
      
      if (mounted) {
        setState(() {
          _todaysChallenges = challenges;
          _completedChallenges = completed;
          _totalBadges = allBadges.length;
          _unlockedBadges = unlocked.length;
          _wordsToReview = dueWords.length;
          _totalXP = totalXP;
          _isLoadingQuickAccess = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading quick access data: $e');
      if (mounted) {
        setState(() => _isLoadingQuickAccess = false);
      }
    }
  }

  Future<void> _loadWordOfTheDay() async {
    setState(() => _isLoadingWord = true);
    try {
      final word = await _wordOfTheDayService.getWordOfTheDay();
      bool isFav = false;
      if (word['bisaya'] != null) {
        isFav = await _userService.isFavoriteWord(word['bisaya']!);
      }
      setState(() {
        _wordOfTheDay = word;
        _isWordFavorited = isFav;
        _isLoadingWord = false;
      });
    } catch (e) {
      setState(() => _isLoadingWord = false);
      // Silently fail - will show fallback
    }
  }

  Future<void> _toggleWordOfDayFavorite() async {
    if (_wordOfTheDay == null) return;
    final bisaya = _wordOfTheDay!['bisaya'] ?? '';
    final english = _wordOfTheDay!['english'] ?? '';
    final tagalog = _wordOfTheDay!['tagalog'] ?? '';
    
    try {
      if (_isWordFavorited) {
        await _userService.removeFavoriteWord(bisaya);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from favorites'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        await _userService.addFavoriteWord(bisaya, english, tagalog);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to favorites! ❤️'), duration: Duration(seconds: 1)),
          );
        }
      }
      setState(() => _isWordFavorited = !_isWordFavorited);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
            SizedBox(
              height: 32,
              width: 32,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading logo: $error');
                  return Icon(Icons.language, color: accentColor, size: 20);
                },
              ),
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
              _isLoadingWord ? Icons.refresh : Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _isLoadingWord ? null : () => _loadWordOfTheDay(),
            tooltip: 'Refresh word of the day',
          ),
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                bottom: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    appBarColor,
                    accentColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
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
                      _loadUserProfile();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        backgroundImage: _profilePictureUrl != null
                            ? NetworkImage(_profilePictureUrl!)
                            : null,
                        child: _profilePictureUrl == null
                            ? Text(
                                _getInitials(),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fullname ?? _username ?? user?.email?.split('@').first ?? 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, color: Colors.white.withValues(alpha: 0.8), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user?.email ?? 'Not logged in',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalXP XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _buildMenuItem(Icons.home_rounded, 'Home', () => Navigator.pop(context), const Color(0xFF4CAF50), textColor, subtitle: 'Dashboard overview'),
                  _buildMenuItem(Icons.smart_toy_rounded, 'AI Assistant', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceTranslationScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFF9C27B0), textColor, subtitle: 'Voice translation & chat', showBadge: true),
                  _buildMenuItem(Icons.menu_book_rounded, 'Word Vocabulary', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WordVocabularyScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFFFF9800), textColor, subtitle: 'Browse all words'),
                  _buildMenuItem(Icons.psychology_rounded, 'Spaced Repetition', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFF00BCD4), textColor, subtitle: 'Smart review sessions'),
                  _buildMenuItem(Icons.favorite_rounded, 'Favorite Words', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FavoritesScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFFE91E63), textColor, subtitle: 'Your saved words'),
                  _buildMenuItem(Icons.insights_rounded, 'Progress & Reports', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProgressScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFF673AB7), textColor, subtitle: 'Track your journey'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(color: textColor.withValues(alpha: 0.1)),
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(Icons.tune_rounded, 'Settings', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          isDarkMode: _isDarkMode,
                          onToggleDarkMode: _toggleDarkMode,
                        ),
                      ),
                    );
                  }, const Color(0xFF607D8B), textColor, subtitle: 'App preferences'),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(
                            isDarkMode: _isDarkMode,
                            onToggleDarkMode: _toggleDarkMode,
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Body
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Word of the Day Section - Enhanced Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Header row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Word of the Day',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Learn something new!',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Action buttons
                              if (_wordOfTheDay != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Favorite button
                                    IconButton(
                                      onPressed: _toggleWordOfDayFavorite,
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _isWordFavorited 
                                              ? Colors.pink.withValues(alpha: 0.3)
                                              : Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isWordFavorited ? Icons.favorite : Icons.favorite_border,
                                          color: _isWordFavorited ? Colors.pink[200] : Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    // Speak button
                                    if (_isTtsInitialized)
                                      IconButton(
                                        onPressed: () => _speakWord(_wordOfTheDay!['bisaya'] ?? ''),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.volume_up_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Word content
                          if (_isLoadingWord)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          else if (_wordOfTheDay != null) ...[
                            // Bisaya word
                            Text(
                              _wordOfTheDay!['bisaya'] ?? '',
                              style: const TextStyle(
                                fontSize: 36,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            // Pronunciation
                            if (_wordOfTheDay!['pronunciation']?.isNotEmpty ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '/${_wordOfTheDay!['pronunciation']}/',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Divider
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // English translation
                            Text(
                              _wordOfTheDay!['english'] ?? '',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Category/Part of speech if available
                            if (_wordOfTheDay!['partOfSpeech']?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _wordOfTheDay!['partOfSpeech']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unable to load word',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B5FAE),
                        Color(0xFF2666B4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B5FAE).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LearningScreen(
                              isDarkMode: _isDarkMode,
                              onToggleDarkMode: _toggleDarkMode,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Start Learning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Quick Access Section
              const SizedBox(height: 32),
              _buildQuickAccessSection(accentColor, textColor, backgroundColor),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          user != null ? 'Logged in as: ${user.email}' : 'Not logged in',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, Color iconColor, Color textColor, {String? subtitle, bool showBadge = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withValues(alpha: 0.15),
                        iconColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: textColor.withValues(alpha: 0.3),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build quick access section with cards for key features
  Widget _buildQuickAccessSection(Color accentColor, Color textColor, Color backgroundColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isLoadingQuickAccess)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: accentColor),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Daily Challenges Card
              _buildQuickAccessCard(
                icon: Icons.flag,
                title: 'Daily Challenges',
                subtitle: '$_completedChallenges/${_todaysChallenges.length} completed',
                color: Colors.orange,
                progress: _todaysChallenges.isEmpty 
                    ? 0.0 
                    : _completedChallenges / _todaysChallenges.length,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyChallengeScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                  _loadQuickAccessData();
                },
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
              
              // Achievements Card
              _buildQuickAccessCard(
                icon: Icons.emoji_events,
                title: 'Achievements',
                subtitle: '$_unlockedBadges/$_totalBadges badges',
                color: Colors.amber,
                progress: _totalBadges == 0 ? 0.0 : _unlockedBadges / _totalBadges,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AchievementScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                  _loadQuickAccessData();
                },
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
              
              // Weekly Progress Card
              _buildQuickAccessCard(
                icon: Icons.insights,
                title: 'Weekly Report',
                subtitle: 'View your progress',
                color: Colors.teal,
                progress: null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeeklyProgressScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                  _loadQuickAccessData();
                },
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
              
              // Weak Words Card
              _buildQuickAccessCard(
                icon: Icons.psychology,
                title: 'Weak Words',
                subtitle: 'Practice struggles',
                color: Colors.deepOrange,
                progress: null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeakWordsScreen(
                        isDarkMode: _isDarkMode,
                        onToggleDarkMode: _toggleDarkMode,
                      ),
                    ),
                  );
                  _loadQuickAccessData();
                },
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
            ],
          ),
      ],
    );
  }

  /// Build individual quick access card
  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color textColor,
    double? progress,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    final cardColor = _isDarkMode 
        ? const Color(0xFF20304A) 
        : Colors.white;

    return SizedBox(
      width: 160,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    if (showBadge && badgeCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: color.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    super.dispose();
  }
}
