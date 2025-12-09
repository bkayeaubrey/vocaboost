import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onSignUpSuccess;

  const SignUpScreen({super.key, this.onSignUpSuccess});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;

  // 🎨 Blue Hour Palette (used)
  static const kAccent = Color(0xFF2666B4);
  static const kLightBackground = Color(0xFFC7D4E8);
  static const kDarkBackground = Color(0xFF071B34);
  static const kDarkCard = Color(0xFF20304A);
  static const kTextDark = Color(0xFF071B34);
  static const kTextLight = Color(0xFFC7D4E8);

  Future<void> _signUp() async {
    if (_passwordController.text.trim() != _confirmController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_fullnameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fullname': _fullnameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        if (widget.onSignUpSuccess != null) {
          widget.onSignUpSuccess!();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password should be at least 6 characters.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final textColor = isDark ? kTextLight : kTextDark;
    final fieldFillColor = isDark ? kDarkCard : Colors.white;
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 100,
                width: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.language, size: 100, color: accentColor);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),

              // 🔹 Full Name
              _buildTextField(
                controller: _fullnameController,
                label: 'Full Name',
                icon: Icons.person,
                textColor: textColor,
                fillColor: fieldFillColor,
              ),
              const SizedBox(height: 12),

              // 🔹 Username
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                icon: Icons.account_circle,
                textColor: textColor,
                fillColor: fieldFillColor,
              ),
              const SizedBox(height: 12),

              // 🔹 Email
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                textColor: textColor,
                fillColor: fieldFillColor,
              ),
              const SizedBox(height: 12),

              // 🔹 Password
              _buildTextField(
                controller: _passwordController,
                label: 'Create Password',
                icon: Icons.lock,
                textColor: textColor,
                fillColor: fieldFillColor,
                obscureText: true,
              ),
              const SizedBox(height: 12),

              // 🔹 Confirm Password
              _buildTextField(
                controller: _confirmController,
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                textColor: textColor,
                fillColor: fieldFillColor,
                obscureText: true,
              ),
              const SizedBox(height: 20),

              // 🔹 Sign Up button
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: kTextLight,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: kTextLight)
                    : const Text('Sign Up'),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: Text(
                  'Already have an account? Log in',
                  style: TextStyle(
                    color: isDark ? kTextLight.withOpacity(0.7) : accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color fillColor,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kAccent),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: fillColor,
        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
      ),
    );
  }
}
