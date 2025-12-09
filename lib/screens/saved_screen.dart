import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedScreen extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const SavedScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view saved words.')),
      );
    }

    // 🎨 Blue Hour Palette
    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = isDarkMode ? kDarkBackground : kLightBackground;
    final cardColor = isDarkMode ? kDarkCard : Colors.white;
    final textColor = isDarkMode ? kTextLight : kTextDark;
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Saved Translations',
          style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimary,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: kTextLight,
            ),
            onPressed: () => onToggleDarkMode(!isDarkMode),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_words')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 🔄 Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          // ❌ Error fetching data
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong. Please try again later.',
                style: TextStyle(color: textColor),
              ),
            );
          }

          // 🕊 No saved words
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No Saved Words',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          // ✅ Display saved words
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isDarkMode ? 0 : 4,
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: accentColor),
                  title: Text(
                    data['input'] ?? 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    data['output'] ?? '',
                    style: TextStyle(color: textColor.withOpacity(0.8)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
