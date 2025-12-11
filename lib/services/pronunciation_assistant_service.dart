import 'dart:convert';
import 'package:vocaboost/services/ai_service.dart';
import 'package:flutter/foundation.dart';

/// Service for AI-powered pronunciation error correction and feedback
class PronunciationAssistantService {
  final AIService _aiService = AIService();

  /// Get detailed pronunciation feedback using AI
  /// 
  /// [spokenText] - What the user actually said
  /// [correctWord] - The correct word they should have said
  /// [pronunciationGuide] - The pronunciation guide for the word
  /// 
  /// Returns detailed feedback about pronunciation errors
  Future<Map<String, dynamic>> getPronunciationFeedback({
    required String spokenText,
    required String correctWord,
    String? pronunciationGuide,
  }) async {
    try {
      final prompt = '''You are a Bisaya pronunciation expert. Analyze the user's pronunciation attempt and provide detailed feedback.

User said: "$spokenText"
Correct word: "$correctWord"
Pronunciation guide: ${pronunciationGuide ?? 'Not provided'}

Provide feedback in this JSON format:
{
  "isCorrect": true/false,
  "overallScore": 0-100,
  "errors": [
    {
      "type": "vowel/consonant/stress/syllable",
      "position": "beginning/middle/end",
      "expected": "what should be said",
      "actual": "what was said",
      "suggestion": "how to fix it"
    }
  ],
  "feedback": "encouraging feedback message",
  "tips": ["tip1", "tip2"],
  "practiceSentence": "a practice sentence using the word"
}

Be specific about:
- Which sounds are mispronounced
- Stress pattern errors
- Syllable mistakes
- How to improve

If pronunciation is correct, still provide encouraging feedback and tips for improvement.''';

      final response = await _aiService.getAIResponse(prompt, []);
      
      if (response == null || response.isEmpty) {
        return _getDefaultFeedback(spokenText, correctWord);
      }

      // Try to parse JSON from response
      try {
        // Extract JSON from response (might be wrapped in markdown)
        String jsonStr = response.trim();
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7).trim();
        } else if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3).trim();
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3).trim();
        }

        // Find JSON object
        final jsonStart = jsonStr.indexOf('{');
        final jsonEnd = jsonStr.lastIndexOf('}');
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);
        }

        // Parse JSON
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return {
          'isCorrect': data['isCorrect'] ?? false,
          'overallScore': data['overallScore'] ?? 50,
          'errors': data['errors'] ?? [],
          'feedback': data['feedback'] ?? 'Keep practicing!',
          'tips': data['tips'] ?? [],
          'practiceSentence': data['practiceSentence'] ?? '',
        };
      } catch (e) {
        debugPrint('Error parsing AI response as JSON: $e');
        // Fallback: extract feedback from text response
        return {
          'isCorrect': false,
          'overallScore': 50,
          'errors': [],
          'feedback': response,
          'tips': [],
          'practiceSentence': '',
        };
      }
    } catch (e) {
      debugPrint('Error getting pronunciation feedback: $e');
      return _getDefaultFeedback(spokenText, correctWord);
    }
  }

  /// Get default feedback when AI is unavailable
  Map<String, dynamic> _getDefaultFeedback(String spokenText, String correctWord) {
    final isSimilar = _calculateSimilarity(spokenText.toLowerCase(), correctWord.toLowerCase());
    
    return {
      'isCorrect': isSimilar > 0.8,
      'overallScore': (isSimilar * 100).round(),
      'errors': [],
      'feedback': isSimilar > 0.8
          ? 'Good pronunciation! Keep practicing to make it perfect.'
          : 'Try to match the pronunciation more closely. Listen to the guide and practice.',
      'tips': [
        'Listen carefully to the pronunciation guide',
        'Break the word into syllables',
        'Pay attention to stress patterns',
      ],
      'practiceSentence': '',
    };
  }

  /// Calculate simple similarity between two strings
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Simple Levenshtein-based similarity
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.isEmpty) return 1.0;
    
    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Get real-time pronunciation tips for a word
  Future<String> getPronunciationTips(String word, String pronunciationGuide) async {
    try {
      final prompt = '''Provide 3 concise tips for pronouncing the Bisaya word "$word" correctly.

Pronunciation guide: $pronunciationGuide

Give tips in a simple, actionable format. Keep each tip to one sentence.''';

      final response = await _aiService.getAIResponse(prompt, []);
      return response ?? 'Listen carefully to the pronunciation guide and practice slowly.';
    } catch (e) {
      debugPrint('Error getting pronunciation tips: $e');
      return 'Listen carefully to the pronunciation guide and practice slowly.';
    }
  }
}

