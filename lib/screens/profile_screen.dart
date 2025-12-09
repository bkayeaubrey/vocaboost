import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vocaboost/services/user_service.dart';
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
  String? _profilePictureUrl;
  String? _fullname;
  String? _username;
  bool _isLoading = true;
  bool _isUploading = false;

  // 🎨 Blue Hour Palette
  final Color kLightBackground = const Color(0xFFC7D4E8);
  final Color kPrimary = const Color(0xFF3B5FAE);
  final Color kAccent = const Color(0xFF2666B4);
  final Color kTextDark = const Color(0xFF071B34);
  final Color kDarkBackground = const Color(0xFF071B34);
  final Color kDarkCard = const Color(0xFF20304A);
  final Color kTextLight = const Color(0xFFC7D4E8);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _userService.getUserData();
      if (mounted) {
        setState(() {
          _profilePictureUrl = userData?['profilePictureUrl'] as String?;
          _fullname = userData?['fullname'] as String?;
          _username = userData?['username'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            if (_profilePictureUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Picture', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);

      final imageFile = await _userService.pickImage(source: source);
      if (imageFile == null || !mounted) {
        setState(() => _isUploading = false);
        return;
      }

      final url = await _userService.uploadProfilePicture(imageFile);
      
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
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // Print full error for debugging
        debugPrint('Image upload error: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $e')),
        );
      }
    }
  }

  String _getInitials() {
    final user = FirebaseAuth.instance.currentUser;
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
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email![0].toUpperCase();
    }
    return '?';
  }

  Widget _buildAvatar() {
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;

    if (_isUploading) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: kPrimary,
            child: const CircularProgressIndicator(color: Colors.white),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: kPrimary,
            backgroundImage: _profilePictureUrl != null
                ? NetworkImage(_profilePictureUrl!)
                : null,
            child: _profilePictureUrl == null
                ? Text(
                    _getInitials(),
                    style: const TextStyle(
                      fontSize: 36,
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kAccent,
                shape: BoxShape.circle,
                border: Border.all(color: cardColor, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final backgroundColor = widget.isDarkMode ? kDarkBackground : kLightBackground;
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;
    final textColor = widget.isDarkMode ? kTextLight : kTextDark;
    final iconColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showImageSourceDialog,
                    child: Text(
                      _profilePictureUrl != null ? 'Change Picture' : 'Add Picture',
                      style: TextStyle(color: kAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_fullname != null && _fullname!.isNotEmpty)
                    Text(
                      _fullname!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  if (_username != null && _username!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@${_username!}',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? 'No email found',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to VocaBoost — your Bisaya learning companion!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: iconColor),
                      title: Text(
                        'Log Out',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
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
    );
  }
}
