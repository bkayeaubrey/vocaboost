import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for translating words using Backenster Translation API
/// API endpoint: https://api-b2b.backenster.com/b1/api/v3/translate
class BackensterTranslationService {
  // Try both possible endpoints
  static const String _baseUrl = 'https://api-b2b.backenster.com/b1/api/v3/translate';
  static const String _altBaseUrl = 'https://api.backenster.com/b1/api/v3/translate';
  
  /// Map app language names to Backenster language codes
  static const Map<String, String> _languageCodes = {
    'English': 'en',
    'Bisaya': 'ceb', // Cebuano (Bisaya)
    'Tagalog': 'tl', // Tagalog
    'Filipino': 'tl', // Filipino uses Tagalog code
  };

  /// Translate text from one language to another
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
      // Get language codes
      final fromCode = _languageCodes[fromLang] ?? 'en';
      final toCode = _languageCodes[toLang] ?? 'en';

      if (fromCode == toCode) {
        return text; // No translation needed
      }

      // Get API key from environment variables
      final apiKey = dotenv.env['BACKENSTER_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Backenster API: WARNING - BACKENSTER_API_KEY not found in .env file');
        throw Exception('Backenster API key not configured. Please add BACKENSTER_API_KEY to your .env file.');
      }

      // Prepare headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Backenster API might use different header formats - try multiple
      if (apiKey.isNotEmpty) {
        // Try Authorization header with Bearer token
        headers['Authorization'] = 'Bearer $apiKey';
        // Also try as X-API-Key
        headers['X-API-Key'] = apiKey;
        // Some APIs use just the key directly
        headers['apiKey'] = apiKey;
      }
      
      debugPrint('Backenster API: Using API key (length: ${apiKey.length})');

      // Try different request body formats
      // Format 1: Nested translate object
      Map<String, dynamic> requestBody1 = {
        'translate': {
          'text': text,
          'from': fromCode,
          'to': toCode,
        },
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      };

      // Format 2: Flat structure
      Map<String, dynamic> requestBody2 = {
        'text': text,
        'from': fromCode,
        'to': toCode,
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      };

      // Format 3: Alternative structure
      Map<String, dynamic> requestBody3 = {
        'source': fromCode,
        'target': toCode,
        'q': text,
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      };
      
      // Format 4: With API key in nested structure
      Map<String, dynamic> requestBody4 = {
        'text': text,
        'from': fromCode,
        'to': toCode,
        'auth': {
          'apiKey': apiKey,
        },
      };

      // Try Format 1 first (most common for v3 APIs)
      http.Response response;
      bool useAltUrl = false;
      
      try {
        debugPrint('Backenster API: Trying format 1 on primary URL - ${jsonEncode(requestBody1)}');
        response = await http.post(
          Uri.parse(_baseUrl),
          headers: headers,
          body: jsonEncode(requestBody1),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Translation request timed out');
          },
        );
        debugPrint('Backenster API Format 1 response: ${response.statusCode} - ${response.body}');
        
        // If we get a 404 or connection error, try alternate URL
        if (response.statusCode == 404 || response.statusCode == 0) {
          debugPrint('Primary URL failed, trying alternate URL');
          useAltUrl = true;
          throw Exception('Primary URL failed, trying alternate');
        }
      } catch (e) {
        debugPrint('Format 1 failed: $e, trying format 2');
        // Try Format 2
        try {
          final url2 = useAltUrl ? _altBaseUrl : _baseUrl;
          debugPrint('Backenster API: Trying format 2 on ${useAltUrl ? "alternate" : "primary"} URL - ${jsonEncode(requestBody2)}');
          response = await http.post(
            Uri.parse(url2),
            headers: headers,
            body: jsonEncode(requestBody2),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Translation request timed out');
            },
          );
          debugPrint('Backenster API Format 2 response: ${response.statusCode} - ${response.body}');
        } catch (e2) {
          debugPrint('Format 2 failed: $e2, trying format 3');
          // Try Format 3
          try {
            final url = useAltUrl ? _altBaseUrl : _baseUrl;
            debugPrint('Backenster API: Trying format 3 on ${useAltUrl ? "alternate" : "primary"} URL - ${jsonEncode(requestBody3)}');
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(requestBody3),
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Translation request timed out');
              },
            );
            debugPrint('Backenster API Format 3 response: ${response.statusCode} - ${response.body}');
            
            if (response.statusCode == 404 && !useAltUrl) {
              useAltUrl = true;
              throw Exception('Primary URL failed, trying alternate');
            }
          } catch (e3) {
            debugPrint('Format 3 failed: $e3, trying format 4');
            // Try Format 4
            try {
              final url = useAltUrl ? _altBaseUrl : _baseUrl;
              debugPrint('Backenster API: Trying format 4 on ${useAltUrl ? "alternate" : "primary"} URL - ${jsonEncode(requestBody4)}');
              response = await http.post(
                Uri.parse(url),
                headers: headers,
                body: jsonEncode(requestBody4),
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('Translation request timed out');
                },
              );
              debugPrint('Backenster API Format 4 response: ${response.statusCode} - ${response.body}');
            } catch (e4) {
              debugPrint('All formats failed. Last error: $e4');
              return null;
            }
          }
        }
      }

      debugPrint('Backenster API Final response status: ${response.statusCode}');
      debugPrint('Backenster API Response body: ${response.body}');
      debugPrint('Backenster API Response headers: ${response.headers}');

      // Handle successful responses (200-299)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Parse response - try multiple possible structures
          String? translation;
          
          // Try direct keys
          if (responseData.containsKey('result')) {
            final result = responseData['result'];
            if (result is String) {
              translation = result;
            } else if (result is Map) {
              translation = _extractTranslation(result as Map<String, dynamic>);
            }
          }
          
          if (translation == null && responseData.containsKey('translatedText')) {
            translation = responseData['translatedText'] as String?;
          }
          
          if (translation == null && responseData.containsKey('text')) {
            translation = responseData['text'] as String?;
          }
          
          if (translation == null && responseData.containsKey('translation')) {
            translation = responseData['translation'] as String?;
          }
          
          // Try nested structures
          translation ??= _extractTranslation(responseData);
          
          // Try to find any string value that might be the translation
          translation ??= _findTranslationInMap(responseData);
          
          if (translation != null && translation.isNotEmpty) {
            debugPrint('Backenster API translation found: $translation');
            return translation;
          }
          
          debugPrint('Backenster API: No translation found in response. Full response: ${response.body}');
          // Try to return the raw response body as string if it looks like a translation
          final bodyStr = response.body.trim();
          if (bodyStr.isNotEmpty && bodyStr.length < 500 && !bodyStr.startsWith('{') && !bodyStr.startsWith('[')) {
            debugPrint('Backenster API: Returning raw response as translation: $bodyStr');
            return bodyStr;
          }
          return null;
        } catch (e) {
          debugPrint('Backenster API JSON parse error: $e');
          debugPrint('Response body: ${response.body}');
          // If JSON parsing fails, try returning the raw body if it looks like text
          final bodyStr = response.body.trim();
          if (bodyStr.isNotEmpty && bodyStr.length < 500 && !bodyStr.startsWith('{') && !bodyStr.startsWith('[')) {
            debugPrint('Backenster API: JSON parse failed, returning raw response: $bodyStr');
            return bodyStr;
          }
          return null;
        }
      } else {
        // Try to extract error message
        String errorMsg = 'Unknown error';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
          if (errorData != null) {
            errorMsg = errorData['message'] as String? ?? 
                      errorData['error'] as String? ?? 
                      errorData['errorMessage'] as String? ?? 
                      response.body;
          }
        } catch (_) {
          errorMsg = response.body;
        }
        debugPrint('Backenster API error: ${response.statusCode} - $errorMsg');
        
        // For 401/403, it's likely an auth issue
        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('Backenster API: Authentication failed. Check API key.');
        }
        
        return null;
      }
    } catch (e) {
      debugPrint('Error translating text: $e');
      return null;
    }
  }

  /// Extract translation from various possible response structures
  String? _extractTranslation(Map<String, dynamic> data) {
    // Try common nested structures
    if (data.containsKey('data')) {
      final dataObj = data['data'];
      if (dataObj is Map) {
        if (dataObj.containsKey('translatedText')) {
          return dataObj['translatedText'] as String?;
        }
        if (dataObj.containsKey('text')) {
          return dataObj['text'] as String?;
        }
        if (dataObj.containsKey('result')) {
          return dataObj['result'] as String?;
        }
      } else if (dataObj is String) {
        return dataObj;
      }
    }
    
    if (data.containsKey('responseData')) {
      final responseData = data['responseData'];
      if (responseData is Map) {
        if (responseData.containsKey('translatedText')) {
          return responseData['translatedText'] as String?;
        }
        if (responseData.containsKey('text')) {
          return responseData['text'] as String?;
        }
      } else if (responseData is String) {
        return responseData;
      }
    }
    
    if (data.containsKey('translate')) {
      final translateObj = data['translate'];
      if (translateObj is Map) {
        if (translateObj.containsKey('result')) {
          return translateObj['result'] as String?;
        }
        if (translateObj.containsKey('text')) {
          return translateObj['text'] as String?;
        }
      }
    }
    
    return null;
  }

  /// Recursively search for translation string in map
  String? _findTranslationInMap(Map<String, dynamic> data) {
    for (var value in data.values) {
      if (value is String && value.isNotEmpty && value.length < 500) {
        // Likely a translation if it's a reasonable length string
        return value;
      } else if (value is Map) {
        final result = _findTranslationInMap(value as Map<String, dynamic>);
        if (result != null) return result;
      } else if (value is List) {
        for (var item in value) {
          if (item is Map) {
            final result = _findTranslationInMap(item as Map<String, dynamic>);
            if (result != null) return result;
          }
        }
      }
    }
    return null;
  }

  /// Get supported language code for a language name
  String? getLanguageCode(String languageName) {
    return _languageCodes[languageName];
  }

  /// Check if a language is supported
  bool isLanguageSupported(String languageName) {
    return _languageCodes.containsKey(languageName);
  }
}

