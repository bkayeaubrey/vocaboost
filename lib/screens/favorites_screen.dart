import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocaboost/services/user_service.dart';

class FavoritesScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const FavoritesScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadFavorites();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await _userService.getFavoriteWords();
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Error loading favorites: $e', Icons.error, Colors.red);
      }
    }
  }

  Future<void> _removeFavorite(String bisayaWord) async {
    try {
      await _userService.removeFavoriteWord(bisayaWord);
      await _loadFavorites();
      if (mounted) {
        _showSnackBar('Removed from favorites', Icons.heart_broken, Colors.grey);
      }
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

  List<Map<String, dynamic>> get _filteredFavorites {
    if (_searchQuery.isEmpty) return _favorites;
    return _favorites.where((word) {
      final bisaya = word['bisaya']?.toLowerCase() ?? '';
      final english = word['english']?.toLowerCase() ?? '';
      final tagalog = word['tagalog']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return bisaya.contains(query) || english.contains(query) || tagalog.contains(query);
    }).toList();
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
          // Modern App Bar
          _buildModernAppBar(isDark, textColor, kAccent),
          
          // Search Section
          _buildSearchSection(cardColor, textColor, surfaceColor, kAccent),
          
          // Favorites List
          Expanded(
            child: _buildFavoritesList(isDark, cardColor, textColor, surfaceColor, kAccent, kPrimary),
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
              : [const Color(0xFFE91E63), const Color(0xFFAD1457)],
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
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorite Words',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_favorites.length} words saved',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Refresh button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: _loadFavorites,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(Color cardColor, Color textColor, Color surfaceColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: GoogleFonts.poppins(fontSize: 16, color: textColor),
          decoration: InputDecoration(
            hintText: 'Search your favorites...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.4),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.pink, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: textColor.withValues(alpha: 0.5)),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList(bool isDark, Color cardColor, Color textColor, Color surfaceColor, Color accentColor, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            const SizedBox(height: 16),
            Text(
              'Loading favorites...',
              style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    if (_filteredFavorites.isEmpty) {
      return _buildEmptyState(textColor);
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: Colors.pink,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredFavorites.length,
        itemBuilder: (context, index) {
          final word = _filteredFavorites[index];
          return _buildWordCard(word, isDark, cardColor, textColor, surfaceColor, index);
        },
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
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
                    Colors.pink.withValues(alpha: 0.15),
                    Colors.pink.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isEmpty ? Icons.favorite_border_rounded : Icons.search_off_rounded,
                size: 56,
                color: Colors.pink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty ? 'No Favorites Yet' : 'No Matches Found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Words you favorite will appear here.\nTap the heart icon on any word to save it!'
                  : 'Try a different search term',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word, bool isDark, Color cardColor, Color textColor, Color surfaceColor, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Could navigate to word details
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Word Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink.shade400, Colors.pink.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (word['bisaya'] ?? 'W')[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Word Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word['bisaya'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🇺🇸',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                word['english'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🇵🇭',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                word['tagalog'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: textColor.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Delete Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                      onPressed: () => _showDeleteConfirmation(word['bisaya']),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String bisayaWord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text('Remove Word?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$bisayaWord" from your favorites?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeFavorite(bisayaWord);
            },
            child: Text('Remove', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
