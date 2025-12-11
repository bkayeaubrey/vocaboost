import 'package:http/http.dart' as http;
import 'dart:convert';

class TTSService {
  static const String _apiKey = 'AIzaSyAmhgAb2mWNvuLoIWQci19UktCVKUP_pPA'; // Add your API key
  static const String _baseUrl = 'https://texttospeech.googleapis.com/v1/text:synthesize';

  /// Synthesize text to speech using Google Cloud Text-to-Speech API
  /// Returns audio content as base64 encoded string
  Future<String?> synthesizeBisaya(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': 'ceb-PH', // Cebuano (Bisaya) - Philippines
            'name': 'ceb-PH-Neural2-A', // Natural-sounding voice
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'pitch': 0.0,
            'speakingRate': 0.9,
          },
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['audioContent'] as String;
      } else {
        print('TTS Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('TTS Exception: $e');
      return null;
    }
  }

  /// Play the synthesized audio content
  static Future<void> playAudioContent(String audioContent) async {
    try {
      // Decode base64 audio
      final audioBytes = base64Decode(audioContent);
      
      // For web, we can create a blob and play it
      // For mobile, use audioplayers package
      print('Audio ready to play: ${audioBytes.length} bytes');
    } catch (e) {
      print('Play Error: $e');
    }
  }
}
