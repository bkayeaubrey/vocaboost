import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Use Cloud Function for web/PWA, direct API for native
  static String get _baseUrl {
    if (kIsWeb) {
      // Route web/PWA traffic through the deployed proxy (project: vocaboost-fb)
      return 'https://us-central1-vocaboost-fb.cloudfunctions.net/openaiProxy';
    }
    return 'https://api.openai.com/v1/chat/completions';
  }
  
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
        // Build messages list with system prompt and conversation history
        final List<Map<String, String>> messages = [
          {'role': 'system', 'content': _systemPrompt},
          ...conversationHistory,
          {'role': 'user', 'content': userMessage},
        ];

        Map<String, String> headers = {'Content-Type': 'application/json'};
        
        // Only add API key for native apps (not web/PWA)
        if (!kIsWeb) {
          final apiKey = dotenv.env['OPENAI_API_KEY'];
          if (apiKey == null || apiKey.isEmpty) {
            throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
          }
          headers['Authorization'] = 'Bearer $apiKey';
        }

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: headers,
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
                throw Exception('Rate limit exceeded. Please wait $seconds seconds and try again.');
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

  /// Translate text using OpenAI API
  /// 
  /// [text] - The text to translate
  /// [fromLang] - Source language (English, Bisaya, Tagalog)
  /// [toLang] - Target language (English, Bisaya, Tagalog)
  /// 
  /// Returns the translated text, or null if translation fails
  Future<String?> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      // Create a translation-specific prompt with emphasis on accuracy
      final translationPrompt = '''Translate the following text from $fromLang to $toLang with 99% accuracy. 
Only return the translation, nothing else. No explanations, no additional text, just the translated word or phrase.

Text to translate: "$text"
Translation:''';

      Map<String, String> headers = {'Content-Type': 'application/json'};
      
      // Only add API key for native apps (not web/PWA)
      if (!kIsWeb) {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
        }
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert translation assistant specializing in Bisaya (Cebuano), English, and Tagalog. Provide 99% accurate translations. Only return the translation, no explanations.',
            },
            {
              'role': 'user',
              'content': translationPrompt,
            },
          ],
          'temperature': 0.3, // Lower temperature for more consistent translations
          'max_tokens': 100, // Short responses for translations
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Translation request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final translation = message['content'] as String?;
          // Clean up the translation (remove quotes, extra whitespace)
          if (translation != null) {
            var cleaned = translation.trim();
            // Remove surrounding quotes if present
            if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
                (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
              cleaned = cleaned.substring(1, cleaned.length - 1);
            }
            return cleaned;
          }
        }
        return null;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] as String?;
        throw Exception(errorMessage ?? 'Translation failed. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OpenAI translation error: $e');
      return null;
    }
  }

  /// Generate a complete dictionary entry for a Mindanao Bisaya word with strict validation
  /// 
  /// [word] - The word to validate and create an entry for
  /// 
  /// Returns a map with all dictionary components, or null if generation fails or word is invalid
  Future<Map<String, String>?> generateDictionaryEntry({
    required String word,
  }) async {
    if (word.trim().isEmpty) return null;

    try {
      // Create Mindanao Bisaya validation and dictionary entry prompt with deep analysis
      final dictionaryPrompt = '''You are a deep Mindanao Bisaya vocabulary expert and validator. Your job is to receive a single word and determine whether it is a valid Bisaya/Cebuano word used in Mindanao (regional Cebuano used in Mindanao: Davao, Butuan, Agusan, Surigao, CDO, etc.).

IMPORTANT: Accept words that are used in Mindanao Bisaya, even if they are also used in Central Visayas Cebuano. Common Bisaya words like "hilanat" (fever), "kaon" (eat), "balay" (house) are valid as they are used in Mindanao.

VALIDATION RULES:

1. VALIDATION
   - If the input is NOT a valid Bisaya/Cebuano word used in Mindanao, return:
     {
       "valid": false,
       "reason": "not a Bisaya word"
     }
   - Reject: misspellings, English words, Tagalog words, internet slang, unintelligible strings.
   - ACCEPT: Common Bisaya/Cebuano words used in Mindanao (even if also used in Central Visayas).
   - ACCEPT: Regional Mindanao Bisaya slang and unique words (e.g., "sukna" meaning "to press someone for an answer").
   - ACCEPT: Standard Bisaya vocabulary that is actively used in Mindanao regions.

2. IF VALID - DEEP DICTIONARY ENTRY
   Return a complete, deep dictionary entry in this exact JSON format:
   {
     "valid": true,
     "word": "<normalized Mindanao Bisaya word>",
     "part_of_speech": "<noun/verb/adj/slang/etc.>",
     "english_meaning": "<deep, comprehensive Mindanao Bisaya meaning with context, usage, and nuances (30-50 words)>",
     "tagalog_meaning": "<deep, comprehensive Tagalog translation with context>",
     "category": "<choose ONE: Emotion, Action, Object, Tool, Clothing, Household Item, Food, Animal, Body Part, Nature, Place, People/Relations, Measurement/Time, Culture, Slang/Vulgar, Everyday Item>",
     "sample_sentence_bisaya": "<natural, conversational Mindanao Bisaya sentence showing deep usage context>",
     "english_translation": "<accurate, detailed translation>",
     "tagalog_translation": "<accurate, detailed translation>",
     "usage_note": "<deep usage context, when/how to use, cultural significance, regional variations if any>",
     "synonyms": "<comma-separated list of related Mindanao Bisaya words or phrases>",
     "confidence": <0-100 integer>,
     "note": "<null or short note for regional meaning>"
   }

3. SENTENCE RULES
   - Sentences must be **natural, conversational Mindanao Bisaya**, not machine-like.
   - The sample sentence MUST demonstrate deep, contextual usage of the word.
   - Show the word in a realistic, meaningful context that reveals its true usage.

4. ACCURACY REQUIREMENTS
   - Meanings and usage should reflect Mindanao Bisaya usage and context.
   - Provide DEEP, comprehensive meanings that capture nuances, context, and cultural significance.
   - Include usage notes that explain when, how, and in what context the word is used.
   - For regional Mindanao meanings, provide detailed context and regional variations.
   - When in doubt about a common Bisaya word, accept it if it's a legitimate Bisaya/Cebuano word (bias towards acceptance for common vocabulary).

5. OUTPUT RULES
   - Output JSON only.
   - No explanations outside JSON.
   - Use temperature 0.0 for maximum accuracy.

Word to validate: $word''';

      Map<String, String> headers = {'Content-Type': 'application/json'};
      
      // Only add API key for native apps (not web/PWA)
      if (!kIsWeb) {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
        }
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a Mindanao Bisaya vocabulary expert and validator. Work with Bisaya/Cebuano words used in Mindanao (Davao, Butuan, Agusan, Surigao, CDO, etc.). Accept common Bisaya words used in Mindanao, even if also used in Central Visayas. Return JSON only. Reject misspellings, English, Tagalog, and internet slang. Accept legitimate Bisaya/Cebuano words used in Mindanao. Use natural conversational Mindanao Bisaya sentences. Bias towards acceptance for common Bisaya vocabulary.',
            },
            {
              'role': 'user',
              'content': dictionaryPrompt,
            },
          ],
          'temperature': 0.0, // Maximum accuracy for strict validation
          'max_tokens': 800, // Increased for deep dictionary entries with usage notes and synonyms
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Dictionary entry generation request timed out');
        },
      );

      debugPrint('=== [AIService Dictionary Entry] START OF REQUEST ===');
      debugPrint('[AIService] Word to validate: $word');
      debugPrint('[AIService] Base URL: $_baseUrl');
      debugPrint('[AIService] Response status code: ${response.statusCode}');
      debugPrint('[AIService] Response headers: ${response.headers}');
      debugPrint('[AIService] Raw response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final content = message['content'] as String?;
          
          if (content != null && content.isNotEmpty) {
            debugPrint('Dictionary entry response: $content');
            
            // Parse JSON response
            try {
              // Clean the content to extract JSON (remove markdown code blocks if present)
              String jsonContent = content.trim();
              
              // Remove markdown code blocks
              if (jsonContent.startsWith('```json')) {
                jsonContent = jsonContent.substring(7).trim();
              } else if (jsonContent.startsWith('```')) {
                jsonContent = jsonContent.substring(3).trim();
              }
              if (jsonContent.endsWith('```')) {
                jsonContent = jsonContent.substring(0, jsonContent.length - 3).trim();
              }
              
              // Find JSON object boundaries if there's extra text
              final jsonStart = jsonContent.indexOf('{');
              final jsonEnd = jsonContent.lastIndexOf('}');
              if (jsonStart >= 0 && jsonEnd > jsonStart) {
                jsonContent = jsonContent.substring(jsonStart, jsonEnd + 1);
              }
              
              jsonContent = jsonContent.trim();
              debugPrint('Cleaned JSON content: $jsonContent');
              
              final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;
              debugPrint('Decoded JSON data: $jsonData');
              
              // Check if word is valid
              final isValid = jsonData['valid'] as bool? ?? false;
              if (!isValid) {
                final reason = jsonData['reason']?.toString() ?? 'not a Mindanao Bisaya word';
                debugPrint('Word is not valid Mindanao Bisaya: $reason');
                // Return a special entry with error information
                return {
                  'valid': 'false',
                  'reason': reason,
                };
              }
              
              // Convert JSON response to our internal format
              final parsed = _parseJsonDictionaryEntry(jsonData);
              debugPrint('Parsed dictionary entry: $parsed');
              
              // Validate that we have at least the word
              if (parsed['word'] == null || parsed['word']!.isEmpty) {
                debugPrint('WARNING: Parsed entry has no word, falling back to old parser');
                final fallbackParsed = _parseDictionaryEntry(content);
                return fallbackParsed;
              }
              
              return parsed;
            } catch (e, stackTrace) {
              debugPrint('Error parsing JSON response: $e');
              debugPrint('Stack trace: $stackTrace');
              debugPrint('Original content: $content');
              // Fallback to old parsing method
              try {
                final parsed = _parseDictionaryEntry(content);
                debugPrint('Fallback parsing successful: $parsed');
                return parsed;
              } catch (fallbackError) {
                debugPrint('Fallback parsing also failed: $fallbackError');
                return null;
              }
            }
          } else {
            debugPrint('WARNING: Content is null or empty');
          }
        } else {
          debugPrint('WARNING: No choices in response');
        }
        return null;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] as String?;
        throw Exception(errorMessage ?? 'Dictionary entry generation failed. Status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('OpenAI dictionary entry generation error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse the dictionary entry response into structured components
  Map<String, String> _parseDictionaryEntry(String content) {
    final Map<String, String> entry = {};
    
    // Split by lines and parse each component
    final lines = content.split('\n');
    String currentKey = '';
    String currentValue = '';
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Check if line starts with a known label
      if (line.toLowerCase().startsWith('word:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'word';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('part of speech:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'partOfSpeech';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('category:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'category';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('english meaning:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'englishMeaning';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('tagalog meaning:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'tagalogMeaning';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('sample sentence (bisaya):')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'sampleSentenceBisaya';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('english translation:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'englishTranslation';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.toLowerCase().startsWith('tagalog translation:')) {
        if (currentKey.isNotEmpty) entry[currentKey] = currentValue.trim();
        currentKey = 'tagalogTranslation';
        currentValue = line.substring(line.indexOf(':') + 1).trim();
      } else if (currentKey.isNotEmpty) {
        // Continuation of previous value
        currentValue += ' $line';
      }
    }
    
    // Add the last entry
    if (currentKey.isNotEmpty) {
      entry[currentKey] = currentValue.trim();
    }
    
    return entry;
  }

  /// Parse JSON dictionary entry response into structured components
  Map<String, String> _parseJsonDictionaryEntry(Map<String, dynamic> jsonData) {
    final Map<String, String> entry = {};
    
    // Safely extract all fields with null handling
    entry['word'] = (jsonData['word']?.toString() ?? '').trim();
    entry['partOfSpeech'] = (jsonData['part_of_speech']?.toString() ?? '').trim();
    entry['englishMeaning'] = (jsonData['english_meaning']?.toString() ?? '').trim();
    entry['tagalogMeaning'] = (jsonData['tagalog_meaning']?.toString() ?? '').trim();
    entry['category'] = (jsonData['category']?.toString() ?? '').trim();
    entry['sampleSentenceBisaya'] = (jsonData['sample_sentence_bisaya']?.toString() ?? '').trim();
    entry['englishTranslation'] = (jsonData['english_translation']?.toString() ?? '').trim();
    entry['tagalogTranslation'] = (jsonData['tagalog_translation']?.toString() ?? '').trim();
    
    // Add deep dictionary fields if available
    if (jsonData['usage_note'] != null && jsonData['usage_note'].toString().toLowerCase() != 'null') {
      entry['usageNote'] = jsonData['usage_note'].toString().trim();
    }
    if (jsonData['synonyms'] != null && jsonData['synonyms'].toString().toLowerCase() != 'null') {
      entry['synonyms'] = jsonData['synonyms'].toString().trim();
    }
    
    // Add confidence and note if available
    if (jsonData['confidence'] != null) {
      entry['confidence'] = jsonData['confidence'].toString();
    }
    if (jsonData['note'] != null && jsonData['note'].toString().toLowerCase() != 'null') {
      entry['note'] = jsonData['note'].toString().trim();
    }
    
    debugPrint('Parsed JSON entry - word: ${entry['word']}, partOfSpeech: ${entry['partOfSpeech']}, englishMeaning: ${entry['englishMeaning']}');
    
    return entry;
  }

  /// Generate a sample sentence using the word
  /// 
  /// [word] - The word to create a sentence with
  /// [language] - The language of the word (English, Bisaya, Tagalog)
  /// 
  /// Returns a sample sentence, or null if generation fails
  Future<String?> generateSampleSentence({
    required String word,
    required String language,
  }) async {
    if (word.trim().isEmpty) return null;

    try {
      // Create a sentence generation prompt
      final sentencePrompt = '''Create a simple, natural sentence using the $language word "$word". 
The sentence should be:
- Short and easy to understand
- Use the word naturally in context
- Be appropriate for language learning
- Only return the sentence, nothing else

Sentence:''';

      Map<String, String> headers = {'Content-Type': 'application/json'};
      
      // Only add API key for native apps (not web/PWA)
      if (!kIsWeb) {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('OpenAI API key not found. Please add OPENAI_API_KEY to your .env file.');
        }
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a language learning assistant. Create simple, natural sentences for language learners.',
            },
            {
              'role': 'user',
              'content': sentencePrompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 100,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Sentence generation request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final sentence = message['content'] as String?;
          if (sentence != null) {
            var cleaned = sentence.trim();
            // Remove surrounding quotes if present
            if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
                (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
              cleaned = cleaned.substring(1, cleaned.length - 1);
            }
            return cleaned;
          }
        }
        return null;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] as String?;
        throw Exception(errorMessage ?? 'Sentence generation failed. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OpenAI sentence generation error: $e');
      return null;
    }
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

