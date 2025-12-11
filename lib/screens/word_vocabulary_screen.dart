import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/translation_service.dart';
import 'package:vocaboost/services/nlp_model_service.dart';
import 'package:vocaboost/services/ai_service.dart';
import 'package:vocaboost/services/bisaya_expert_dictionary.dart';
import 'package:vocaboost/services/user_service.dart';
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

class _WordVocabularyScreenState extends State<WordVocabularyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final NLPModelService _nlpService = NLPModelService.instance;
  final AIService _aiService = AIService();
  final BisayaExpertDictionary _expertDictionary = BisayaExpertDictionary();
  final UserService _userService = UserService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _pulseController;
  
  bool _modelLoaded = false;
  bool _isCurrentWordFavorited = false;
  
  String? _currentWord;
  String _currentTagalogTranslation = '';
  String _currentEnglishTranslation = '';
  String? _currentPartOfSpeech;
  String? _currentCategory;
  String? _currentEnglishMeaning;
  String? _currentTagalogMeaning;
  String? _currentSampleSentenceBisaya;
  String? _currentSampleEnglishTranslation;
  String? _currentSampleTagalogTranslation;
  String? _currentUsageNote;
  String? _currentSynonyms;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isSearchingViaAPI = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _loadModel();
    _initializeExpertDictionary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFavorited(String word) async {
    try {
      final isFav = await _userService.isFavoriteWord(word);
      if (mounted) {
        setState(() => _isCurrentWordFavorited = isFav);
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentWord == null) return;
    
    try {
      if (_isCurrentWordFavorited) {
        await _userService.removeFavoriteWord(_currentWord!);
        if (mounted) {
          _showSnackBar('Removed from favorites', Icons.heart_broken, Colors.grey);
        }
      } else {
        await _userService.addFavoriteWord(
          _currentWord!,
          _currentEnglishTranslation,
          _currentTagalogTranslation,
        );
        if (mounted) {
          _showSnackBar('Added to favorites! ❤️', Icons.favorite, Colors.pink);
        }
      }
      setState(() => _isCurrentWordFavorited = !_isCurrentWordFavorited);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Icons.error, Colors.red);
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _initializeExpertDictionary() async {
    try {
      await _expertDictionary.initialize();
      debugPrint('[Word Vocabulary] Expert dictionary initialized with ${_expertDictionary.getSize()} words');
    } catch (e) {
      debugPrint('[Word Vocabulary] Expert dictionary init error: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      if (!_nlpService.isLoaded) {
        await _nlpService.loadModel();
      }
      setState(() {
        _modelLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        _showSnackBar('Failed to load model: $e', Icons.error, Colors.red);
      }
    }
  }

  String _detectLanguage(String text) {
    if (!_modelLoaded) return 'English';
    
    final lowerText = text.toLowerCase().trim();
    
    if (_nlpService.getWordMetadata(lowerText) != null) {
      return 'Bisaya';
    }
    
    final searchResults = _nlpService.searchWord(lowerText, limit: 1);
    if (searchResults.isNotEmpty) {
      final metadata = searchResults[0]['metadata'] as Map<String, dynamic>;
      final bisaya = (metadata['bisaya'] as String? ?? '').toLowerCase();
      final tagalog = (metadata['tagalog'] as String? ?? '').toLowerCase();
      
      if (bisaya.contains(lowerText) || lowerText.contains(bisaya)) {
        return 'Bisaya';
      } else if (tagalog.contains(lowerText) || lowerText.contains(tagalog)) {
        return 'Tagalog';
      }
    }
    
    return 'English';
  }

  Future<void> _searchWord(String word) async {
    if (word.trim().isEmpty) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _currentWord = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final originalWord = word.trim();
    
    // PRIORITY 1: Check Expert Dictionary first
    final expertWord = _expertDictionary.getWord(originalWord);
    if (expertWord != null) {
      debugPrint('Word Vocabulary: [Expert Dictionary] Found: "$originalWord"');
      
      try {
        final enhanced = await _expertDictionary.getWordWithAPIEnhancement(originalWord);
        if (enhanced != null) {
          setState(() {
            _currentWord = enhanced['word'] as String?;
            _currentEnglishTranslation = enhanced['englishMeaning'] as String? ?? '';
            _currentTagalogTranslation = enhanced['tagalogMeaning'] as String? ?? '';
            _currentPartOfSpeech = enhanced['partOfSpeech'] as String?;
            _currentCategory = enhanced['category'] as String?;
            _currentEnglishMeaning = enhanced['englishMeaning'] as String?;
            _currentTagalogMeaning = enhanced['tagalogMeaning'] as String?;
            _currentSampleSentenceBisaya = enhanced['sampleSentenceBisaya'] as String?;
            _currentSampleEnglishTranslation = enhanced['englishTranslation'] as String?;
            _currentSampleTagalogTranslation = enhanced['tagalogTranslation'] as String?;
            _currentUsageNote = enhanced['usageNote'] as String?;
            _currentSynonyms = enhanced['synonyms'] as String?;
            _errorMessage = null;
            _isProcessing = false;
            _searchController.clear();
          });
          _checkIfFavorited(_currentWord!);
          return;
        }
      } catch (e) {
        debugPrint('[Word Vocabulary] API enhancement error: $e');
      }
      
      setState(() {
        _currentWord = expertWord['word'] as String?;
        _currentEnglishTranslation = expertWord['englishMeaning'] as String? ?? '';
        _currentTagalogTranslation = expertWord['tagalogMeaning'] as String? ?? '';
        _currentPartOfSpeech = expertWord['partOfSpeech'] as String?;
        _currentCategory = expertWord['category'] as String?;
        _currentEnglishMeaning = expertWord['englishMeaning'] as String?;
        _currentTagalogMeaning = expertWord['tagalogMeaning'] as String?;
        _currentSampleSentenceBisaya = expertWord['sampleSentenceBisaya'] as String?;
        _currentSampleEnglishTranslation = expertWord['englishTranslation'] as String?;
        _currentSampleTagalogTranslation = expertWord['tagalogTranslation'] as String?;
        _currentSynonyms = _formatRelatedWords(expertWord);
        _errorMessage = null;
        _isProcessing = false;
        _searchController.clear();
      });
      _checkIfFavorited(_currentWord!);
      return;
    }
    
    // PRIORITY 2: Use OpenAI API for words not in expert dictionary
    try {
      debugPrint('Word Vocabulary: [API Fallback] Searching API for: "$originalWord"');
      
      setState(() {
        _isSearchingViaAPI = true;
      });
      
      final dictionaryEntry = await _aiService.generateDictionaryEntry(
        word: originalWord,
      );
      
      setState(() {
        _isSearchingViaAPI = false;
      });
      
      if (dictionaryEntry == null || dictionaryEntry.isEmpty) {
        debugPrint('Word Vocabulary: [API] Empty response for "$originalWord"');
        setState(() {
          _currentWord = null;
          _errorMessage = 'This is not a valid Bisaya word.';
          _isProcessing = false;
          _searchController.clear();
        });
        return;
      }
      
      bool isInvalid = false;
      final validValue = dictionaryEntry['valid'];
      if (validValue is String) {
        isInvalid = validValue.toLowerCase() == 'false';
      }
      
      if (isInvalid) {
        setState(() {
          _currentWord = null;
          _errorMessage = 'This is not a valid Bisaya word.';
          _isProcessing = false;
          _searchController.clear();
        });
        return;
      }
      
      if (dictionaryEntry.isNotEmpty) {
        final entryWord = dictionaryEntry['word'];
        final correctedWord = (entryWord != null && entryWord.toString().isNotEmpty) 
            ? entryWord.toString() 
            : originalWord;
        
        setState(() {
          _currentWord = correctedWord;
          _currentTagalogTranslation = dictionaryEntry['tagalogMeaning']?.toString() ?? '';
          _currentEnglishTranslation = dictionaryEntry['englishMeaning']?.toString() ?? '';
          _currentPartOfSpeech = dictionaryEntry['partOfSpeech']?.toString();
          _currentCategory = dictionaryEntry['category']?.toString();
          _currentEnglishMeaning = dictionaryEntry['englishMeaning']?.toString();
          _currentTagalogMeaning = dictionaryEntry['tagalogMeaning']?.toString();
          _currentSampleSentenceBisaya = dictionaryEntry['sampleSentenceBisaya']?.toString();
          _currentSampleEnglishTranslation = dictionaryEntry['englishTranslation']?.toString();
          _currentSampleTagalogTranslation = dictionaryEntry['tagalogTranslation']?.toString();
          _currentUsageNote = dictionaryEntry['usageNote']?.toString();
          _currentSynonyms = dictionaryEntry['synonyms']?.toString();
          _isProcessing = false;
          _searchController.clear();
        });
        _checkIfFavorited(correctedWord);
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('[Expert API] Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _currentWord = null;
        _errorMessage = 'Unable to validate word. Please check your connection and try again.';
        _isProcessing = false;
        _isSearchingViaAPI = false;
        _searchController.clear();
      });
    }
  }

  Future<void> _saveMessage(String input, String output) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
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
        _showSnackBar('Saved to your word list!', Icons.bookmark, Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save: $e', Icons.error, Colors.red);
      }
    }
  }

  String _formatRelatedWords(Map<String, dynamic> entry) {
    final bisayaWords = (entry['relatedWordsBisaya'] as List?)?.join(', ') ?? '';
    final englishWords = (entry['relatedWordsEnglish'] as List?)?.join(', ') ?? '';
    
    if (bisayaWords.isNotEmpty && englishWords.isNotEmpty) {
      return '$bisayaWords ($englishWords)';
    } else if (bisayaWords.isNotEmpty) {
      return bisayaWords;
    }
    return englishWords;
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
    final surfaceColor = isDark ? const Color(0xFF1E3250) : const Color(0xFFE3EBF3);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Modern App Bar with gradient
          _buildModernAppBar(isDark, textColor),
          
          // Search Section
          _buildSearchSection(isDark, cardColor, textColor, surfaceColor, kAccent),
          
          // Content Area
          Expanded(
            child: _buildContentArea(isDark, cardColor, textColor, surfaceColor, kAccent, kPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark, Color textColor) {
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
              : [const Color(0xFF3B5FAE), const Color(0xFF2666B4)],
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
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Dictionary',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Mindanao Bisaya vocabulary',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(bool isDark, Color cardColor, Color textColor, Color surfaceColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search hint
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search any Bisaya word to see its meaning',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter a Bisaya word...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        color: textColor.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _searchWord(value.trim());
                      }
                    },
                  ),
                ),
                // Search button
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isProcessing 
                            ? [Colors.grey, Colors.grey.shade600]
                            : [accentColor, const Color(0xFF3B5FAE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isProcessing
                            ? null
                            : () {
                                if (_searchController.text.trim().isNotEmpty) {
                                  _searchWord(_searchController.text.trim());
                                }
                              },
                        child: Center(
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(bool isDark, Color cardColor, Color textColor, Color surfaceColor, Color accentColor, Color primaryColor) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // API Search Indicator
          if (_isSearchingViaAPI)
            _buildSearchingIndicator(accentColor),
          
          // Error Message
          if (_errorMessage != null && _errorMessage!.isNotEmpty)
            _buildErrorCard(textColor),
          
          // Dictionary Entry
          if (_currentWord != null)
            _buildDictionaryCard(isDark, cardColor, textColor, surfaceColor, accentColor, primaryColor)
          else if (!_isSearchingViaAPI && _errorMessage == null)
            _buildEmptyState(textColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildSearchingIndicator(Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.1),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Searching dictionary...',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(
                  'Validating Bisaya word with AI',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Not Found',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 56,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Discover Bisaya Words',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a word above to see its meaning,\ntranslations, and example sentences',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.5),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Quick search suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['Kumusta', 'Salamat', 'Maayo', 'Tubig'].map((word) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = word;
                  _searchWord(word);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    word,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryCard(bool isDark, Color cardColor, Color textColor, Color surfaceColor, Color accentColor, Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word Header
          _buildWordHeader(isDark, textColor, accentColor, primaryColor),
          
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: textColor.withValues(alpha: 0.1),
          ),
          
          // Meanings Section
          _buildMeaningsSection(textColor, surfaceColor),
          
          // Example Sentence
          if (_currentSampleSentenceBisaya != null && _currentSampleSentenceBisaya!.isNotEmpty)
            _buildExampleSection(isDark, textColor, surfaceColor, accentColor),
          
          // Usage Note
          if (_currentUsageNote != null && _currentUsageNote!.isNotEmpty)
            _buildUsageSection(textColor, surfaceColor, accentColor),
          
          // Related Words
          if (_currentSynonyms != null && _currentSynonyms!.isNotEmpty)
            _buildRelatedWordsSection(textColor),
          
          // Action Buttons
          _buildActionButtons(textColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildWordHeader(bool isDark, Color textColor, Color accentColor, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E3A5F).withValues(alpha: 0.5), Colors.transparent]
              : [accentColor.withValues(alpha: 0.08), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.translate_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          
          // Word and tags
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentWord!,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Part of Speech
                    if (_currentPartOfSpeech != null && _currentPartOfSpeech!.isNotEmpty)
                      _buildTag(
                        _currentPartOfSpeech!,
                        accentColor,
                        accentColor.withValues(alpha: 0.15),
                      ),
                    // Category
                    if (_currentCategory != null && _currentCategory!.isNotEmpty)
                      _buildCategoryTag(_currentCategory!),
                  ],
                ),
              ],
            ),
          ),
          
          // Favorite button
          GestureDetector(
            onTap: _toggleFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCurrentWordFavorited 
                    ? Colors.pink.withValues(alpha: 0.15)
                    : textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isCurrentWordFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isCurrentWordFavorited ? Colors.pink : textColor.withValues(alpha: 0.5),
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildCategoryTag(String category) {
    final isSlang = category.toLowerCase().contains('slang') || 
                    category.toLowerCase().contains('vulgar');
    final isUnsure = category.toLowerCase().contains('unsure');
    
    final color = isSlang ? Colors.orange : (isUnsure ? Colors.grey : Colors.green);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        category,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMeaningsSection(Color textColor, Color surfaceColor) {
    final hasEnglish = _currentEnglishMeaning != null && _currentEnglishMeaning!.isNotEmpty ||
                       _currentEnglishTranslation.isNotEmpty;
    final hasTagalog = _currentTagalogMeaning != null && _currentTagalogMeaning!.isNotEmpty ||
                       _currentTagalogTranslation.isNotEmpty;
    
    if (!hasEnglish && !hasTagalog) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // English Meaning
          if (hasEnglish)
            _buildMeaningCard(
              icon: '🇺🇸',
              label: 'English',
              meaning: _currentEnglishMeaning ?? _currentEnglishTranslation,
              color: const Color(0xFF10B981),
              textColor: textColor,
              surfaceColor: surfaceColor,
            ),
          
          if (hasEnglish && hasTagalog) const SizedBox(height: 12),
          
          // Tagalog Meaning
          if (hasTagalog)
            _buildMeaningCard(
              icon: '🇵🇭',
              label: 'Tagalog',
              meaning: _currentTagalogMeaning ?? _currentTagalogTranslation,
              color: const Color(0xFF3B82F6),
              textColor: textColor,
              surfaceColor: surfaceColor,
            ),
        ],
      ),
    );
  }

  Widget _buildMeaningCard({
    required String icon,
    required String label,
    required String meaning,
    required Color color,
    required Color textColor,
    required Color surfaceColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meaning,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleSection(bool isDark, Color textColor, Color surfaceColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
            accentColor.withValues(alpha: isDark ? 0.08 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.format_quote_rounded, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Example Sentence',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Bisaya sentence
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentSampleSentenceBisaya!,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: textColor,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
          
          // Translations
          if ((_currentSampleEnglishTranslation != null && _currentSampleEnglishTranslation!.isNotEmpty) ||
              (_currentSampleTagalogTranslation != null && _currentSampleTagalogTranslation!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentSampleEnglishTranslation != null && _currentSampleEnglishTranslation!.isNotEmpty)
                    Text(
                      _currentSampleEnglishTranslation!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  if (_currentSampleTagalogTranslation != null && _currentSampleTagalogTranslation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _currentSampleTagalogTranslation!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageSection(Color textColor, Color surfaceColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber.shade600),
              const SizedBox(width: 10),
              Text(
                'Usage & Context',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentUsageNote!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedWordsSection(Color textColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: Colors.purple),
              const SizedBox(width: 10),
              Text(
                'Related Words',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentSynonyms!.split(',').map((synonym) {
              final trimmed = synonym.trim();
              if (trimmed.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  _searchController.text = trimmed;
                  _searchWord(trimmed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trimmed,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.purple.shade400,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color textColor, Color accentColor) {
    if (_currentTagalogTranslation.isEmpty && _currentEnglishTranslation.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () {
              String translationToSave = '';
              if (_currentTagalogTranslation.isNotEmpty) {
                translationToSave = _currentTagalogTranslation;
              } else if (_currentEnglishTranslation.isNotEmpty) {
                translationToSave = _currentEnglishTranslation;
              }
              if (translationToSave.isNotEmpty && _currentWord != null) {
                _saveMessage(_currentWord!, translationToSave);
              }
            },
            icon: Icon(Icons.bookmark_add_outlined, size: 20, color: accentColor),
            label: Text(
              'Save Word',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: accentColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



