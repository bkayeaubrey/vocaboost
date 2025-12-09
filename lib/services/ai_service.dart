import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // System prompt for Bisaya learning assistant
  static const String _systemPrompt = '''You are a friendly and encouraging Bisaya learning assistant for the VocaBoost app. Your role is to help users learn Bisaya (Cebuano), Tagalog, and English translations.

Your capabilities include:
- Translating between English, Bisaya, and Tagalog
- Providing pronunciation guidance for Bisaya words
- Creating practice sentences
- Engaging in conversational learning
- Being patient, encouraging, and educational

When users speak Bisaya words, you can help them with pronunciation. When they ask for translations, provide clear and accurate translations. Always be supportive and make learning fun!

Keep your responses concise but helpful. If a user asks about pronunciation, provide phonetic guidance. If they ask for translations, give the translation and maybe a usage example.''';

  /// Get AI response from OpenAI API with retry logic
  /// 
  /// [userMessage] - The user's message
  /// [conversationHistory] - List of previous messages in format: [{'role': 'user'|'assistant', 'content': 'message'}]
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// 
  /// Returns the AI's response text, or null if there's an error
  Future<String?> getAIResponse(
    String userMessage,
    List<Map<String, String>> conversationHistory, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
        }

        // Build messages list with system prompt and conversation history
        final List<Map<String, String>> messages = [
          {'role': 'system', 'content': _systemPrompt},
          ...conversationHistory,
          {'role': 'user', 'content': userMessage},
        ];

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 500,
          }),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timeout. Please check your internet connection.');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List;
          if (choices.isNotEmpty) {
            final message = choices[0]['message'] as Map<String, dynamic>;
            return message['content'] as String?;
          }
          return 'Sorry, I couldn\'t generate a response. Please try again.';
        } else if (response.statusCode == 401) {
          throw Exception('Invalid API key. Please check your OPENAI_API_KEY in the .env file.');
        } else if (response.statusCode == 429) {
          // Rate limit exceeded - check if we should retry
          attempt++;
          if (attempt >= maxRetries) {
            // Check for retry-after header
            final retryAfter = response.headers['retry-after'];
            if (retryAfter != null) {
              final seconds = int.tryParse(retryAfter);
              if (seconds != null) {
                throw Exception('Rate limit exceeded. Please wait ${seconds} seconds and try again.');
              }
            }
            throw Exception('Rate limit exceeded. Please wait a moment and try again.');
          }
          
          // Exponential backoff: wait 2^attempt seconds (2s, 4s, 8s)
          final waitSeconds = 2 * (1 << (attempt - 1));
          await Future.delayed(Duration(seconds: waitSeconds));
          continue; // Retry the request
        } else if (response.statusCode >= 500) {
          // Server error - retry with exponential backoff
          attempt++;
          if (attempt >= maxRetries) {
            throw Exception('OpenAI service is temporarily unavailable. Please try again later.');
          }
          final waitSeconds = 2 * (1 << (attempt - 1));
          await Future.delayed(Duration(seconds: waitSeconds));
          continue; // Retry the request
        } else {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final errorMessage = errorData['error']?['message'] as String?;
          throw Exception(errorMessage ?? 'Failed to get AI response. Status code: ${response.statusCode}');
        }
      } on http.ClientException {
        // Network error - retry with exponential backoff
        attempt++;
        if (attempt >= maxRetries) {
          throw Exception('Network error. Please check your internet connection.');
        }
        final waitSeconds = 2 * (1 << (attempt - 1));
        await Future.delayed(Duration(seconds: waitSeconds));
        continue; // Retry the request
      } catch (e) {
        // If it's an exception we want to retry, continue the loop
        if (e.toString().contains('timeout') && attempt < maxRetries - 1) {
          attempt++;
          final waitSeconds = 2 * (1 << (attempt - 1));
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        // Otherwise, rethrow
        if (e is Exception) {
          rethrow;
        }
        throw Exception('An unexpected error occurred: $e');
      }
    }
    
    // Should never reach here, but just in case
    throw Exception('Failed to get AI response after $maxRetries attempts.');
  }

  /// Convert conversation messages to API format
  /// 
  /// Takes a list of Message objects and converts them to the format
  /// expected by the OpenAI API
  static List<Map<String, String>> convertMessagesToHistory(
    List<Map<String, dynamic>> messages,
  ) {
    return messages.map((msg) {
      return {
        'role': msg['isUser'] == true ? 'user' : 'assistant',
        'content': msg['text'] as String,
      };
    }).toList();
  }
}

