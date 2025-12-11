import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Blue Hour Color Palette
const Color kPrimary = Color(0xFF3B5FAE);
const Color kAccent = Color(0xFF2666B4);
const Color kLightBackground = Color(0xFFC7D4E8);
const Color kDarkBackground = Color(0xFF071B34);

class SavedScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const SavedScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? kDarkBackground : kLightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: kAccent.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'Please log in to view saved words',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = widget.isDarkMode;
    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final cardColor = isDark ? const Color(0xFF1A2E4A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Modern Gradient Header
          _buildGradientHeader(textColor),
          
          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_words')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: kAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Loading saved words...',
                          style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: GoogleFonts.poppins(fontSize: 16, color: textColor),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(textColor);
                }

                // Filter by search query
                final docs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final input = (data['input'] ?? '').toString().toLowerCase();
                  final output = (data['output'] ?? '').toString().toLowerCase();
                  return input.contains(_searchQuery.toLowerCase()) ||
                      output.contains(_searchQuery.toLowerCase());
                }).toList();

                if (docs.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: textColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No words match "$_searchQuery"',
                          style: GoogleFonts.poppins(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  );
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildWordCard(data, docs[index].id, cardColor, textColor, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(Color textColor) {
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Words',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Your vocabulary collection',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search saved words...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.8)),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_border, size: 64, color: kAccent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Words Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start learning and save words\nto build your vocabulary!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimary, kAccent]),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tap the bookmark icon to save!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(Map<String, dynamic> data, String docId, Color cardColor, Color textColor, int index) {
    final input = data['input'] ?? 'N/A';
    final output = data['output'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    String dateStr = '';
    if (timestamp != null) {
      final date = timestamp.toDate();
      dateStr = '${date.day}/${date.month}/${date.year}';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(docId),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Delete Word?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text('Are you sure you want to remove "$input" from your saved words?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('saved_words')
                .doc(docId)
                .delete();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$input" removed'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: kPrimary,
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Flag Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🇵🇭', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                
                // Word Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        input,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('🇺🇸', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              output,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Saved on $dateStr',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Bookmark Icon
                Icon(Icons.bookmark, color: kAccent, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
