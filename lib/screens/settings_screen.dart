import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vocaboost/services/feedback_service.dart';
import 'package:vocaboost/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkMode;
  final FeedbackService _feedbackService = FeedbackService();
  final NotificationService _notificationService = NotificationService();
  bool _notificationsEnabled = true;
  int _reminderHour = 9;
  int _reminderMinute = 0;
  
  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    final time = await _notificationService.getReminderTime();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _reminderHour = time['hour'] ?? 9;
        _reminderMinute = time['minute'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🎨 Blue Hour Palette
    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = _darkMode ? kDarkBackground : kLightBackground;
    final textColor = _darkMode ? kTextLight : kTextDark;
    final cardColor = _darkMode ? kDarkCard : Colors.white;
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingCard(
            title: 'Dark Mode',
            icon: Icons.dark_mode,
            iconColor: accentColor,
            trailing: Switch(
              value: _darkMode,
              activeThumbColor: accentColor,
              onChanged: (value) {
                setState(() => _darkMode = value);
                widget.onToggleDarkMode(value);
              },
            ),
            textColor: textColor,
            cardColor: cardColor,
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            title: 'Push Notifications',
            subtitle: _notificationsEnabled ? 'Daily reminder at ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}' : 'Disabled',
            icon: Icons.notifications,
            iconColor: accentColor,
            trailing: Switch(
              value: _notificationsEnabled,
              activeThumbColor: accentColor,
              onChanged: (value) async {
                if (value) {
                  await _notificationService.requestPermissions();
                }
                await _notificationService.setNotificationsEnabled(value);
                setState(() => _notificationsEnabled = value);
              },
            ),
            textColor: textColor,
            cardColor: cardColor,
            onTap: _notificationsEnabled ? () => _showReminderTimePicker(context, textColor, cardColor, accentColor) : null,
          ),
          const SizedBox(height: 12),
          _buildAccountCard(
            user: user,
            textColor: textColor,
            cardColor: cardColor,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
            onTap: () => _showAccountDetails(context, user, textColor, cardColor, accentColor, backgroundColor),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            title: 'Language',
            subtitle: 'English (default)',
            icon: Icons.language,
            iconColor: accentColor,
            textColor: textColor,
            cardColor: cardColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('More languages coming soon!'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            title: 'Send Feedback',
            icon: Icons.feedback,
            iconColor: accentColor,
            textColor: textColor,
            cardColor: cardColor,
            onTap: () => _showFeedbackDialog(context, textColor, cardColor, accentColor),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            title: 'About VocaBoost',
            icon: Icons.info_outline,
            iconColor: accentColor,
            textColor: textColor,
            cardColor: cardColor,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'VocaBoost',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(Icons.translate, color: accentColor),
                children: [
                  Text(
                    'VocaBoost — a Bisaya learning app developed at DOrSU.',
                    style: TextStyle(color: textColor),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required Color cardColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: _darkMode ? 2 : 4,
      shadowColor: _darkMode ? Colors.black54 : iconColor.withValues(alpha: 0.2),

      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: textColor.withValues(alpha: 0.7)),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildAccountCard({
    required User? user,
    required Color textColor,
    required Color cardColor,
    required Color accentColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return _buildSettingCard(
      title: 'Account Details',
      subtitle: user?.email ?? 'Not logged in',
      icon: Icons.account_circle,
      iconColor: accentColor,
      textColor: textColor,
      cardColor: cardColor,
      trailing: Icon(Icons.chevron_right, color: accentColor),
      onTap: onTap,
    );
  }

  Future<void> _showReminderTimePicker(
    BuildContext context,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _notificationService.updateReminderTime(picked.hour, picked.minute);
      if (mounted) {
        setState(() {
          _reminderHour = picked.hour;
          _reminderMinute = picked.minute;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'),
            backgroundColor: accentColor,
          ),
        );
      }
    }
  }

  Future<void> _showAccountDetails(
    BuildContext context,
    User? user,
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color backgroundColor,
  ) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view account details')),
      );
      return;
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accentColor),
                const SizedBox(height: 16),
                Text(
                  'Loading account details...',
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Load current user data from Firestore
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      
      final fullname = userData['fullname'] ?? 'Not set';
      final username = userData['username'] ?? 'Not set';
      final email = user.email ?? 'Not set';
      final createdAt = userData['createdAt'] as Timestamp?;
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Get profile picture URL
      final profilePictureUrl = userData['profilePictureUrl'] as String?;
      
      // Show account details dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.account_circle, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Account Details',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    Center(
                      child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                          ? (profilePictureUrl.startsWith('assets/')
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.transparent,
                                  child: ClipOval(
                                    child: SvgPicture.asset(
                                      profilePictureUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(profilePictureUrl),
                                  backgroundColor: accentColor.withValues(alpha: 0.2),
                                ))
                          : CircleAvatar(
                              radius: 40,
                              backgroundColor: accentColor,
                              child: Text(
                                _getInitialsFromData(fullname, username, email),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      Icons.person,
                      'Full Name',
                      fullname,
                      textColor,
                      accentColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.alternate_email,
                      'Username',
                      username,
                      textColor,
                      accentColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.email,
                      'Email',
                      email,
                      textColor,
                      accentColor,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Member Since',
                        _formatDate(createdAt.toDate()),
                        textColor,
                        accentColor,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load account details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color accentColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getInitialsFromData(String fullname, String username, String email) {
    if (fullname != 'Not set' && fullname.isNotEmpty) {
      final parts = fullname.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
      }
      return fullname[0].toUpperCase();
    }
    if (username != 'Not set' && username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    if (email != 'Not set' && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _showFeedbackDialog(
    BuildContext context,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) async {
    final TextEditingController messageController = TextEditingController();
    String selectedCategory = 'general';
    int? selectedRating;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.feedback, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Send Feedback',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We\'d love to hear from you!',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Category Selection
                    Text(
                      'Category',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accentColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: cardColor,
                      ),
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General')),
                        DropdownMenuItem(value: 'bug', child: Text('Bug Report')),
                        DropdownMenuItem(value: 'feature', child: Text('Feature Request')),
                        DropdownMenuItem(value: 'improvement', child: Text('Improvement')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value ?? 'general';
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Rating (Optional)
                    Text(
                      'Rating (Optional)',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedRating = selectedRating == rating ? null : rating;
                            });
                          },
                          child: Icon(
                            selectedRating != null && rating <= selectedRating!
                                ? Icons.star
                                : Icons.star_border,
                            color: selectedRating != null && rating <= selectedRating!
                                ? Colors.amber
                                : textColor.withValues(alpha: 0.5),
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    
                    // Message Field
                    Text(
                      'Your Feedback',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Tell us what you think...',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accentColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: cardColor,
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    messageController.dispose();
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (messageController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your feedback'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    // Show loading
                    setDialogState(() {});

                    try {
                      await _feedbackService.submitFeedback(
                        message: messageController.text.trim(),
                        category: selectedCategory,
                        rating: selectedRating,
                      );

                      if (dialogContext.mounted) {
                        messageController.dispose();
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your feedback!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit feedback: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
