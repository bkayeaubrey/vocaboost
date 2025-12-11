import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Cloud-based TTS service using Google Cloud Text-to-Speech API
/// Provides native-sounding Bisaya/Filipino pronunciation
class CloudTTSService {
  static const String _baseUrl = 'https://texttospeech.googleapis.com/v1/text:synthesize';
  
  String? _apiKey;
  String _selectedVoice = 'fil-PH-Standard-A'; // Default to Filipino female voice
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  CloudTTSService() {
    _apiKey = dotenv.env['GOOGLE_CLOUD_TTS_API_KEY'];
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
  
  /// Initialize the service and select the best available voice
  Future<void> initialize() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('⚠️ Google Cloud TTS API key not found. Using device TTS fallback.');
      return;
    }
    
    // Try to get available voices (optional - we'll use default if this fails)
    try {
      final response = await http.get(
        Uri.parse('https://texttospeech.googleapis.com/v1/voices?languageCode=fil-PH'),
        headers: {
          'X-Goog-Api-Key': _apiKey!,
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final voices = data['voices'] as List?;
        if (voices != null && voices.isNotEmpty) {
          // Prefer female voice for clearer pronunciation
          final preferredVoice = voices.firstWhere(
            (v) => v['name']?.toString().contains('Standard-A') ?? false,
            orElse: () => voices.first,
          );
          _selectedVoice = preferredVoice['name'] as String? ?? _selectedVoice;
          debugPrint('✅ Cloud TTS initialized with voice: $_selectedVoice');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not fetch voices list, using default: $e');
      // Continue with default voice
    }
  }
  
  /// Check if cloud TTS is available
  bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;
  
  /// Synthesize speech from text using Google Cloud TTS
  /// Returns audio data as base64-encoded string, or null if failed
  Future<String?> synthesizeSpeech(String text, {
    String? languageCode,
    double speechRate = 1.0,
    double pitch = 0.0,
    double volumeGainDb = 0.0,
  }) async {
    if (!isAvailable) {
      debugPrint('⚠️ Cloud TTS not available, API key missing');
      return null;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'input': {
            'text': text,
          },
          'voice': {
            'languageCode': languageCode ?? 'fil-PH',
            'name': _selectedVoice,
            'ssmlGender': 'FEMALE', // Female voices typically clearer for learning
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': speechRate,
            'pitch': pitch,
            'volumeGainDb': volumeGainDb,
            'sampleRateHertz': 24000, // High quality
          },
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final audioContent = data['audioContent'] as String?;
        if (audioContent != null) {
          debugPrint('✅ Cloud TTS synthesized: ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
          return audioContent;
        }
      } else {
        debugPrint('❌ Cloud TTS error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Cloud TTS synthesis error: $e');
    }
    
    return null;
  }
  
  /// Get the audio URL or data for playback
  /// This returns base64 audio data that can be played using audio_player or similar
  Future<Uint8List?> getAudioData(String text, {
    String? languageCode,
    double speechRate = 1.0,
    double pitch = 0.0,
  }) async {
    final base64Audio = await synthesizeSpeech(
      text,
      languageCode: languageCode,
      speechRate: speechRate,
      pitch: pitch,
    );
    if (base64Audio != null) {
      return base64Decode(base64Audio);
    }
    return null;
  }
  
  /// Play the synthesized speech directly
  /// Returns true if successful, false otherwise
  Future<bool> speak(String text, {
    String? languageCode,
    double speechRate = 1.0,
    double pitch = 0.0,
  }) async {
    try {
      final audioData = await getAudioData(
        text,
        languageCode: languageCode,
        speechRate: speechRate,
        pitch: pitch,
      );
      
      if (audioData != null) {
        // Save to temporary file and play
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(audioData);
        
        // Play from file
        await _audioPlayer.play(DeviceFileSource(file.path));
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error playing cloud TTS audio: $e');
    }
    
    return false;
  }
  
  /// Stop any currently playing audio
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }
}

