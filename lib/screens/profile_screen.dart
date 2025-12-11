import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vocaboost/services/user_service.dart';
import 'package:vocaboost/services/xp_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final XPService _xpService = XPService();
  
  // User data
  String? _profilePictureUrl;
  String? _fullname;
  String? _username;
  String? _email;
  DateTime? _memberSince;
  
  // Stats
  int _totalXP = 0;
  int _level = 1;
  int _currentStreak = 0;
  int _wordsLearned = 0;
  int _quizzesCompleted = 0;
  int _badgesEarned = 0;
  
  bool _isLoading = true;
  bool _isUploading = false;

  // 🎨 Blue Hour Palette
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);
  static const Color kLightBackground = Color(0xFFC7D4E8);
  static const Color kDarkBackground = Color(0xFF071B34);
  static const Color kDarkCard = Color(0xFF20304A);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load user profile data
      final userData = await _userService.getUserData();
      _profilePictureUrl = userData?['profilePictureUrl'] as String?;
      _fullname = userData?['fullname'] as String?;
      _username = userData?['username'] as String?;
      _email = user.email;
      
      final createdAt = userData?['createdAt'] as Timestamp?;
      _memberSince = createdAt?.toDate();

      // Load XP and level
      final xpData = await _xpService.getXPData();
      _totalXP = xpData['totalXP'] ?? 0;
      _level = xpData['level'] ?? 1;

      // Load streak data
      final streakDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learning_data')
          .doc('streak')
          .get();
      if (streakDoc.exists) {
        _currentStreak = (streakDoc.data()?['currentStreak'] as num?)?.toInt() ?? 0;
      }

      // Load words learned count
      final reviewWords = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('review_words')
          .get();
      _wordsLearned = reviewWords.docs.length;

      // Load quizzes completed
      final quizResults = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .get();
      _quizzesCompleted = quizResults.docs.length;

      // Load badges earned
      final badgesDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc('badges')
          .get();
      if (badgesDoc.exists) {
        final badges = badgesDoc.data()?['unlockedBadges'] as List<dynamic>? ?? [];
        _badgesEarned = badges.length;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;

    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Profile Picture',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library, color: kAccent),
                ),
                title: Text('Choose from Gallery', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt, color: kAccent),
                ),
                title: Text('Take a Photo', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              if (_profilePictureUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  title: const Text('Remove Picture', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePicture();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);

      // Use web-compatible method that handles bytes internally
      final url = await _userService.pickAndUploadProfilePicture(source: source);
      
      if (url == null || !mounted) {
        setState(() => _isUploading = false);
        return;
      }
      
      if (mounted) {
        setState(() {
          _profilePictureUrl = url;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    try {
      setState(() => _isUploading = true);
      await _userService.deleteProfilePicture();
      
      if (mounted) {
        setState(() {
          _profilePictureUrl = null;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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
    if (_email != null && _email!.isNotEmpty) {
      return _email![0].toUpperCase();
    }
    return '?';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? kDarkBackground : kLightBackground;
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kAccent))
          : CustomScrollView(
              slivers: [
                // Custom App Bar with Profile Header
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: kPrimary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kPrimary, kAccent],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Profile Picture
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Stack(
                                children: [
                                  if (_isUploading)
                                    const CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.white24,
                                      child: CircularProgressIndicator(color: Colors.white),
                                    )
                                  else if (_profilePictureUrl != null && _profilePictureUrl!.startsWith('assets/'))
                                    CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.white24,
                                      child: ClipOval(
                                        child: SvgPicture.asset(
                                          _profilePictureUrl!,
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.white24,
                                      backgroundImage: _profilePictureUrl != null
                                          ? NetworkImage(_profilePictureUrl!)
                                          : null,
                                      child: _profilePictureUrl == null
                                          ? Text(
                                              _getInitials(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(Icons.camera_alt, size: 20, color: kAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name
                            Text(
                              _fullname ?? 'VocaBoost User',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_username != null && _username!.isNotEmpty)
                              Text(
                                '@$_username',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadAllData,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimary.withOpacity(0.8), kAccent],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars, color: Colors.amber, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Level $_level',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_totalXP XP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Account Information Section
                        _buildSectionHeader('Account Information', Icons.person_outline, textColor),
                        const SizedBox(height: 12),
                        _buildInfoCard(cardColor, textColor, [
                          _buildInfoRow(Icons.email_outlined, 'Email', _email ?? 'Not set', textColor),
                          _buildInfoRow(Icons.calendar_today_outlined, 'Member Since', _formatDate(_memberSince), textColor),
                        ]),
                        const SizedBox(height: 24),

                        // Learning Stats Section
                        _buildSectionHeader('Learning Stats', Icons.bar_chart_rounded, textColor),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _buildStatCard(
                              icon: Icons.local_fire_department,
                              value: '$_currentStreak',
                              label: 'Day Streak',
                              color: Colors.orange,
                              cardColor: cardColor,
                              textColor: textColor,
                            ),
                            _buildStatCard(
                              icon: Icons.menu_book,
                              value: '$_wordsLearned',
                              label: 'Words Learned',
                              color: Colors.blue,
                              cardColor: cardColor,
                              textColor: textColor,
                            ),
                            _buildStatCard(
                              icon: Icons.quiz,
                              value: '$_quizzesCompleted',
                              label: 'Quizzes Done',
                              color: Colors.green,
                              cardColor: cardColor,
                              textColor: textColor,
                            ),
                            _buildStatCard(
                              icon: Icons.emoji_events,
                              value: '$_badgesEarned',
                              label: 'Badges Earned',
                              color: Colors.purple,
                              cardColor: cardColor,
                              textColor: textColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Actions Section
                        _buildSectionHeader('Account Actions', Icons.settings_outlined, textColor),
                        const SizedBox(height: 12),
                        _buildInfoCard(cardColor, textColor, [
                          _buildActionRow(
                            Icons.logout,
                            'Log Out',
                            'Sign out of your account',
                            Colors.red,
                            () => _showLogoutDialog(),
                          ),
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: kAccent, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Color cardColor, Color textColor, List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 18),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: textColor.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      isDarkMode: widget.isDarkMode,
                      onToggleDarkMode: widget.onToggleDarkMode,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
