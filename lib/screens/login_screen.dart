import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vocaboost/screens/signup_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.isDarkMode = false,
    required this.onToggleDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // 🎨 Blue Hour Theme Colors
  final Color kLightBackground = const Color(0xFFC7D4E8);
  final Color kPrimary = const Color(0xFF3B5FAE);
  final Color kAccent = const Color(0xFF2666B4);
  final Color kTextDark = const Color(0xFF071B34);

  final Color kDarkBackground = const Color(0xFF071B34);
  final Color kDarkCard = const Color(0xFF20304A);
  final Color kTextLight = const Color(0xFFC7D4E8);

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                isDarkMode: widget.isDarkMode,
                onToggleDarkMode: widget.onToggleDarkMode,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
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
    final isDark = widget.isDarkMode;
    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final textColor = isDark ? kTextLight : kTextDark;
    final fieldFill = isDark ? kDarkCard : Colors.white;
    final primaryColor = kPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 2,
        title: const Text(
          'Time to boost words!',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              widget.onToggleDarkMode(!widget.isDarkMode);
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo1.png',
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.language, size: 100, color: kAccent);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'VocaBoost Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.8)),
                  prefixIcon: Icon(Icons.email, color: kAccent),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.8)),
                  prefixIcon: Icon(Icons.lock, color: kAccent),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _login,
                icon: const Icon(Icons.login),
                label: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                },
                child: Text(
                  'Don’t have an account? Sign up',
                  style: TextStyle(color: kAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
