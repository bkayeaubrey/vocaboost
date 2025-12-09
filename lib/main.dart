import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vocaboost/screens/login_screen.dart';
import 'package:vocaboost/screens/dashboard_screen.dart';
import 'firebase_options.dart';
import 'package:vocaboost/theme.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(VocaBoostApp(initialDarkMode: isDarkMode));
}

class VocaBoostApp extends StatefulWidget {
  final bool initialDarkMode;
  const VocaBoostApp({super.key, required this.initialDarkMode});

  @override
  State<VocaBoostApp> createState() => _VocaBoostAppState();
}

class _VocaBoostAppState extends State<VocaBoostApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VocaBoost',
      theme: VocaBoostTheme.lightTheme, // Use custom light theme
      darkTheme: VocaBoostTheme.darkTheme, // Use custom dark theme
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: AuthWrapper(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

/// Wrapper widget that checks if user is already logged in
class AuthWrapper extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const AuthWrapper({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? const Color(0xFF2666B4) : const Color(0xFF3B5FAE),
              ),
            ),
          );
        }

        // If user is logged in, show dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return DashboardScreen(
            isDarkMode: isDarkMode,
            onToggleDarkMode: onToggleDarkMode,
          );
        }

        // If no user, show login screen
        return LoginScreen(
          onLoginSuccess: () {
            // This callback is handled by the auth state stream
            // Navigation happens automatically when auth state changes
          },
        );
      },
    );
  }
}
