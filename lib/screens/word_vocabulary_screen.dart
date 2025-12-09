import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/translation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WordVocabularyScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const WordVocabularyScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<WordVocabularyScreen> createState() => _WordVocabularyScreenState();
}

class _WordVocabularyScreenState extends State<WordVocabularyScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TranslationService _translationService = TranslationService();
  
  String? _currentWord;
  String? _currentTranslation;
  String? _currentPronunciation;
  bool _isProcessing = false;

  // Translation dictionary
  final Map<String, Map<String, String>> _translations = {
    'how are you': {'Bisaya': 'Kumusta na ka?', 'Tagalog': 'Kumusta ka?'},
    'good morning': {'Bisaya': 'Maayong buntag', 'Tagalog': 'Magandang umaga'},
    'good afternoon': {'Bisaya': 'Maayong hapon', 'Tagalog': 'Magandang hapon'},
    'good evening': {'Bisaya': 'Maayong gabii', 'Tagalog': 'Magandang gabi'},
    'thank you': {'Bisaya': 'Salamat', 'Tagalog': 'Salamat'},
    'beautiful': {'Bisaya': 'Gwapa', 'Tagalog': 'Maganda'},
    'water': {'Bisaya': 'Tubig', 'Tagalog': 'Tubig'},
    'hello': {'Bisaya': 'Kumusta', 'Tagalog': 'Kumusta'},
    'yes': {'Bisaya': 'Oo', 'Tagalog': 'Oo'},
    'no': {'Bisaya': 'Dili', 'Tagalog': 'Hindi'},
    'please': {'Bisaya': 'Palihug', 'Tagalog': 'Pakisuyo'},
    'sorry': {'Bisaya': 'Pasaylo', 'Tagalog': 'Paumanhin'},
    'kumusta na ka': {'English': 'How are you?'},
    'maayong buntag': {'English': 'Good morning'},
    'salamat': {'English': 'Thank you'},
    'gwapa': {'English': 'Beautiful'},
    'tubig': {'English': 'Water'},
  };

  // Pronunciation dictionary for Bisaya words
  final Map<String, Map<String, dynamic>> _pronunciationGuide = {
    'kumusta': {
      'correct': 'kumusta',
      'alternatives': ['kumusta', 'kumusta ka', 'kumusta na'],
      'pronunciation': 'koo-MOOS-tah',
      'tip': 'Emphasize "MOOS" in the middle',
      'practiceSentences': [
        'Kumusta ka? (How are you?)',
        'Kumusta na ka? (How are you now?)',
        'Kumusta ang imong adlaw? (How is your day?)'
      ],
    },
    'maayong buntag': {
      'correct': 'maayong buntag',
      'alternatives': ['maayong buntag', 'maayo buntag', 'maayong buntag'],
      'pronunciation': 'mah-AH-yong BOON-tag',
      'tip': 'Stress "AH" in maayong and "BOON" in buntag',
      'practiceSentences': [
        'Maayong buntag! (Good morning!)',
        'Maayong buntag kaninyong tanan! (Good morning to all of you!)',
        'Maayong buntag, kumusta ka? (Good morning, how are you?)'
      ],
    },
    'salamat': {
      'correct': 'salamat',
      'alternatives': ['salamat', 'sala mat', 'sah la mat'],
      'pronunciation': 'sah-LAH-maht',
      'tip': 'Stress the second syllable "LAH"',
      'practiceSentences': [
        'Salamat kaayo! (Thank you very much!)',
        'Salamat sa imong tabang. (Thank you for your help.)',
        'Dili salamat. (No, thank you.)'
      ],
    },
    'gwapa': {
      'correct': 'gwapa',
      'alternatives': ['gwapa', 'gwa pa', 'gwah pah'],
      'pronunciation': 'GWAH-pah',
      'tip': 'Stress the first syllable "GWAH"',
      'practiceSentences': [
        'Gwapa kaayo ka. (You are very beautiful.)',
        'Gwapa ang dapit. (The place is beautiful.)',
        'Gwapa kaayo ang dapit. (The place is very beautiful.)'
      ],
    },
    'tubig': {
      'correct': 'tubig',
      'alternatives': ['tubig', 'too big', 'tu big'],
      'pronunciation': 'TOO-big',
      'tip': 'Stress the first syllable "TOO"',
      'practiceSentences': [
        'Gikuha ang tubig. (Get the water.)',
        'Inom og tubig. (Drink water.)',
        'Asa ang tubig? (Where is the water?)'
      ],
    },
    'maayo': {
      'correct': 'maayo',
      'alternatives': ['maayo', 'ma ayo', 'mah ayo'],
      'pronunciation': 'mah-AH-yo',
      'tip': 'Emphasize the middle syllable "AH"',
      'practiceSentences': [
        'Maayo kaayo! (Very good!)',
        'Maayo ang imong ginhawa. (You are breathing well.)',
        'Maayo ang panahon. (The weather is good.)'
      ],
    },
    'panagsa': {
      'correct': 'panagsa',
      'alternatives': ['panagsa', 'panag sa', 'panagsa'],
      'pronunciation': 'pah-NAHG-sah',
      'tip': 'Emphasize the second syllable "NAHG"',
      'practiceSentences': [
        'Panagsa lang ko moadto. (I only go sometimes.)',
        'Panagsa ra siya moanhi. (He only comes sometimes.)',
        'Panagsa lang nako makita. (I only see it sometimes.)'
      ],
    },
  };

  String _detectLanguage(String text) {
    final lowerText = text.toLowerCase();
    final bisayaWords = ['kumusta', 'maayong', 'salamat', 'gwapa', 'tubig', 'panagsa', 'maayo', 'dili', 'palihug', 'pasaylo'];
    final tagalogWords = ['magandang', 'kumusta', 'salamat', 'maganda', 'tubig', 'oo', 'hindi', 'pakisuyo', 'paumanhin'];
    
    if (bisayaWords.any((word) => lowerText.contains(word))) {
      return 'Bisaya';
    } else if (tagalogWords.any((word) => lowerText.contains(word))) {
      return 'Tagalog';
    }
    return 'English';
  }

  Future<void> _searchWord(String word) async {
    if (word.trim().isEmpty) return;
    
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final lowerText = word.toLowerCase().trim();
    final detectedLang = _detectLanguage(word);
    String translation = '';
    String pronunciation = '';

    // Try to find translation
    if (_translations.containsKey(lowerText)) {
      final translations = _translations[lowerText]!;
      if (detectedLang == 'English') {
        translation = translations['Bisaya'] ?? translations['Tagalog'] ?? '';
      } else if (detectedLang == 'Bisaya') {
        translation = translations['English'] ?? '';
      } else {
        translation = translations['English'] ?? translations['Bisaya'] ?? '';
      }
    } else {
      // Reverse lookup
      for (var entry in _translations.entries) {
        if (entry.value.containsKey(detectedLang) && 
            entry.value[detectedLang]!.toLowerCase() == lowerText) {
          if (detectedLang == 'Bisaya' || detectedLang == 'Tagalog') {
            translation = entry.value['English'] ?? entry.key;
          } else {
            translation = entry.value['Bisaya'] ?? entry.value['Tagalog'] ?? '';
          }
          break;
        }
      }
    }

    // Find pronunciation if available
    if (translation.isNotEmpty) {
      final pronunciationKey = detectedLang == 'English' ? translation.toLowerCase() : lowerText;
      if (_pronunciationGuide.containsKey(pronunciationKey)) {
        pronunciation = _pronunciationGuide[pronunciationKey]!['pronunciation'] ?? '';
      }
    }

    // Store dictionary entry and update UI
    setState(() {
      _currentWord = word;
      _currentTranslation = translation.isNotEmpty ? translation : null;
      _currentPronunciation = pronunciation.isNotEmpty ? pronunciation : null;
      _isProcessing = false;
      _searchController.clear();
    });
  }

  Future<void> _saveMessage(String input, String output) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Detect languages for proper saving
      final fromLang = _detectLanguage(input);
      String toLang = 'Bisaya';
      
      if (fromLang == 'English') {
        toLang = 'Bisaya';
      } else if (fromLang == 'Bisaya' || fromLang == 'Tagalog') {
        toLang = 'English';
      }
      
      await _translationService.saveTranslation(
        input: input,
        output: output,
        fromLanguage: fromLang,
        toLanguage: toLang,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to your word list!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final textColor = isDark ? kTextLight : kTextDark;
    final cardColor = isDark ? kDarkCard : Colors.white;
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'Word Vocabulary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => widget.onToggleDarkMode(!isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search for a word...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: accentColor),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _searchWord(value.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                    child: IconButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              if (_searchController.text.trim().isNotEmpty) {
                                _searchWord(_searchController.text.trim());
                              }
                            },
                      icon: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Dictionary content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dictionary Entry
                  if (_currentWord != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Word
                          Text(
                            _currentWord!,
                            style: GoogleFonts.poppins(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Translation
                          if (_currentTranslation != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Translation: ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _currentTranslation!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Pronunciation
                          if (_currentPronunciation != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pronunciation: ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _currentPronunciation!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontStyle: FontStyle.italic,
                                      color: textColor.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // Save button
                          if (_currentTranslation != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.bookmark_border),
                                  color: accentColor,
                                  onPressed: () {
                                    _saveMessage(_currentWord!, _currentTranslation!);
                                  },
                                  tooltip: 'Save word',
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Empty state
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 64, color: textColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Enter a word to see its translation',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}



