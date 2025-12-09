import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vocaboost/services/ai_service.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? language;
  final bool isVoiceInput; // Track if message came from voice

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.language,
    this.isVoiceInput = false,
  });
}

class VoiceTranslationScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const VoiceTranslationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<VoiceTranslationScreen> createState() => _VoiceTranslationScreenState();
}

class _VoiceTranslationScreenState extends State<VoiceTranslationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final AIService _aiService = AIService();
  bool _isListening = false;
  bool _isProcessing = false;
  String _voiceText = '';
  final List<Message> _messages = [];
  Timer? _silenceTimer; // Timer for auto-send after silence
  DateTime? _lastRequestTime; // Track last API request to prevent spam
  static const Duration _minRequestInterval = Duration(seconds: 2); // Minimum time between requests

  // Translation dictionary
  final Map<String, Map<String, String>> _translations = {
    'how are you': {'Bisaya': 'Kumusta na ka?', 'Tagalog': 'Kumusta ka?'},
    'good morning': {'Bisaya': 'Maayong buntag', 'Tagalog': 'Magandang umaga'},
    'good afternoon': {'Bisaya': 'Maayong hapon', 'Tagalog': 'Magandang hapon'},
    'good evening': {'Bisaya': 'Maayong gabii', 'Tagalog': 'Magandang gabi'},
    'thank you': {'Bisaya': 'Salamat', 'Tagalog': 'Salamat'},
    'beautiful': {'Bisaya': 'Gwapa', 'Tagalog': 'Maganda'},
    'water': {'Bisaya': 'Tubig', 'Tagalog': 'Tubig'},
    'hello': {'Bisaya': 'Kumusta', 'Tagalog': 'Kumusta'},
    'yes': {'Bisaya': 'Oo', 'Tagalog': 'Oo'},
    'no': {'Bisaya': 'Dili', 'Tagalog': 'Hindi'},
    'please': {'Bisaya': 'Palihug', 'Tagalog': 'Pakisuyo'},
    'sorry': {'Bisaya': 'Pasaylo', 'Tagalog': 'Paumanhin'},
    'kumusta na ka': {'English': 'How are you?'},
    'maayong buntag': {'English': 'Good morning'},
    'salamat': {'English': 'Thank you'},
    'gwapa': {'English': 'Beautiful'},
    'tubig': {'English': 'Water'},
  };

  // Pronunciation dictionary for Bisaya words
  final Map<String, Map<String, dynamic>> _pronunciationGuide = {
    'kumusta': {
      'correct': 'kumusta',
      'alternatives': ['kumusta', 'kumusta ka', 'kumusta na'],
      'pronunciation': 'koo-MOOS-tah',
      'tip': 'Emphasize "MOOS" in the middle',
      'practiceSentences': [
        'Kumusta ka? (How are you?)',
        'Kumusta na ka? (How are you now?)',
        'Kumusta ang imong adlaw? (How is your day?)'
      ],
    },
    'maayong buntag': {
      'correct': 'maayong buntag',
      'alternatives': ['maayong buntag', 'maayo buntag', 'maayong buntag'],
      'pronunciation': 'mah-AH-yong BOON-tag',
      'tip': 'Stress "AH" in maayong and "BOON" in buntag',
      'practiceSentences': [
        'Maayong buntag! (Good morning!)',
        'Maayong buntag kaninyong tanan! (Good morning to all of you!)',
        'Maayong buntag, kumusta ka? (Good morning, how are you?)'
      ],
    },
    'salamat': {
      'correct': 'salamat',
      'alternatives': ['salamat', 'sala mat', 'sah la mat'],
      'pronunciation': 'sah-LAH-maht',
      'tip': 'Stress the second syllable "LAH"',
      'practiceSentences': [
        'Salamat kaayo! (Thank you very much!)',
        'Salamat sa imong tabang. (Thank you for your help.)',
        'Daghang salamat! (Many thanks!)'
      ],
    },
    'gwapa': {
      'correct': 'gwapa',
      'alternatives': ['gwapa', 'guapa', 'gwa pa'],
      'pronunciation': 'GWAH-pah',
      'tip': 'Pronounce "Gw" like "Gua" with emphasis on first syllable',
      'practiceSentences': [
        'Gwapa ka kaayo! (You are very beautiful!)',
        'Gwapa ang imong nawong. (Your face is beautiful.)',
        'Gwapa kaayo ang dapit. (The place is very beautiful.)'
      ],
    },
    'tubig': {
      'correct': 'tubig',
      'alternatives': ['tubig', 'too big', 'tu big'],
      'pronunciation': 'TOO-big',
      'tip': 'Stress the first syllable "TOO"',
      'practiceSentences': [
        'Gikuha ang tubig. (Get the water.)',
        'Inom og tubig. (Drink water.)',
        'Asa ang tubig? (Where is the water?)'
      ],
    },
    'maayo': {
      'correct': 'maayo',
      'alternatives': ['maayo', 'ma ayo', 'mah ayo'],
      'pronunciation': 'mah-AH-yo',
      'tip': 'Emphasize the middle syllable "AH"',
      'practiceSentences': [
        'Maayo kaayo! (Very good!)',
        'Maayo ang imong ginhawa. (You are breathing well.)',
        'Maayo ang panahon. (The weather is good.)'
      ],
    },
    'panagsa': {
      'correct': 'panagsa',
      'alternatives': ['panagsa', 'panag sa', 'panagsa'],
      'pronunciation': 'pah-NAHG-sah',
      'tip': 'Emphasize the second syllable "NAHG"',
      'practiceSentences': [
        'Panagsa lang ko moadto. (I only go sometimes.)',
        'Panagsa ra siya moanhi. (He only comes sometimes.)',
        'Panagsa lang nako makita. (I only see it sometimes.)'
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    try {
      _flutterTts = FlutterTts();
      _initializeTts();
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
      // Continue without TTS
    }
    _addWelcomeMessage();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      // Continue without TTS if it fails
    }
  }

  void _addWelcomeMessage() {
    _messages.add(Message(
      text: 'Hello! I\'m your AI-powered Bisaya learning assistant. I can help you:\n\n• Translate between English, Bisaya, and Tagalog\n• Provide pronunciation guidance for Bisaya words\n• Create practice sentences\n• Engage in conversational learning\n\nTry speaking or typing a message, and I\'ll help you learn Bisaya!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      // Auto-send after 10 seconds of silence
      if (_isListening && _voiceText.isNotEmpty) {
        _sendVoiceMessage();
      }
    });
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        debugPrint('onStatus: $val');
        if (val == 'done' || val == 'notListening') {
          // Speech recognition stopped
          if (_isListening && _voiceText.isNotEmpty) {
            _sendVoiceMessage();
          }
        }
      },
      onError: (val) => debugPrint('onError: $val'),
    );
    if (available) {
      setState(() {
        _isListening = true;
        _voiceText = '';
        _messageController.text = '';
      });
      _resetSilenceTimer();
      _speech.listen(
        onResult: (val) {
          setState(() {
            _voiceText = val.recognizedWords;
            _messageController.text = _voiceText;
          });
          // Reset timer on each new word
          if (val.finalResult) {
            // Final result - send immediately
            _sendVoiceMessage();
          } else {
            // Partial result - reset silence timer
            _resetSilenceTimer();
          }
        },
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  void _stopListening() {
    _silenceTimer?.cancel();
    _speech.stop();
    setState(() => _isListening = false);
    // Send voice message if there's text
    if (_voiceText.isNotEmpty) {
      _sendVoiceMessage();
    }
  }

  String _detectLanguage(String text) {
    final lowerText = text.toLowerCase();
    final bisayaWords = ['kumusta', 'maayong', 'salamat', 'gwapa', 'tubig', 'panagsa', 'maayo', 'dili', 'palihug', 'pasaylo'];
    final tagalogWords = ['magandang', 'kumusta', 'salamat', 'maganda', 'tubig', 'oo', 'hindi', 'pakisuyo', 'paumanhin'];
    
    if (bisayaWords.any((word) => lowerText.contains(word))) {
      return 'Bisaya';
    } else if (tagalogWords.any((word) => lowerText.contains(word))) {
      return 'Tagalog';
    }
    return 'English';
  }

  String _translateText(String text, String fromLang, String toLang) {
    final lowerText = text.toLowerCase().trim();
    
    // Direct translation lookup
    if (_translations.containsKey(lowerText)) {
      final translations = _translations[lowerText]!;
      if (translations.containsKey(toLang)) {
        return translations[toLang]!;
      }
    }

    // Reverse lookup
    for (var entry in _translations.entries) {
      if (entry.value.containsKey(fromLang) && 
          entry.value[fromLang]!.toLowerCase() == lowerText) {
        if (entry.value.containsKey(toLang)) {
          return entry.value[toLang]!;
        }
        if (toLang == 'English') {
          return entry.key;
        }
      }
    }

    // Simple word-by-word for common phrases
    if (fromLang == 'English' && toLang == 'Bisaya') {
      if (lowerText.contains('how are you')) return 'Kumusta na ka?';
      if (lowerText.contains('good morning')) return 'Maayong buntag';
      if (lowerText.contains('thank you')) return 'Salamat';
    }

    // Default: return original with note
    return text;
  }

  Map<String, dynamic>? _checkPronunciation(String spokenText) {
    final lowerSpoken = spokenText.toLowerCase().trim();
    
    // Check against pronunciation guide
    for (var entry in _pronunciationGuide.entries) {
      final word = entry.key;
      final guide = entry.value;
      final correct = guide['correct'] as String;
      final alternatives = (guide['alternatives'] as List<dynamic>)
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      
      // Check if spoken text matches or is close
      if (lowerSpoken == correct.toLowerCase() || 
          alternatives.contains(lowerSpoken) ||
          lowerSpoken.contains(word) ||
          word.contains(lowerSpoken.split(' ').first)) {
        // Check accuracy
        final isExact = lowerSpoken == correct.toLowerCase() || 
                       alternatives.contains(lowerSpoken);
        final similarity = _calculateSimilarity(lowerSpoken, correct.toLowerCase());
        
        return {
          'word': word,
          'correct': correct,
          'pronunciation': guide['pronunciation'],
          'tip': guide['tip'],
          'practiceSentences': guide['practiceSentences'],
          'isExact': isExact,
          'similarity': similarity,
          'spoken': spokenText,
        };
      }
    }
    
    return null;
  }

  double _calculateSimilarity(String spoken, String correct) {
    // Simple similarity calculation
    if (spoken == correct) return 1.0;
    
    final spokenWords = spoken.split(' ');
    final correctWords = correct.split(' ');
    
    int matches = 0;
    for (var word in spokenWords) {
      if (correctWords.any((cw) => cw.contains(word) || word.contains(cw))) {
        matches++;
      }
    }
    
    return matches / correctWords.length;
  }

  String _generateCorrectionalResponse(Map<String, dynamic> pronunciationCheck) {
    final correct = pronunciationCheck['correct'] as String;
    final pronunciation = pronunciationCheck['pronunciation'] as String;
    final tip = pronunciationCheck['tip'] as String;
    final practiceSentences = pronunciationCheck['practiceSentences'] as List<dynamic>;
    final isExact = pronunciationCheck['isExact'] as bool;
    final similarity = pronunciationCheck['similarity'] as double;
    final spoken = pronunciationCheck['spoken'] as String;

    String response = '';
    
    if (isExact || similarity > 0.8) {
      response = '✓ Excellent pronunciation! You said "$spoken" correctly.\n\n';
      response += 'Pronunciation: $pronunciation\n\n';
      response += 'Here are some practice sentences:\n';
      for (var sentence in practiceSentences) {
        response += '• $sentence\n';
      }
    } else if (similarity > 0.5) {
      response = '⚠ Good attempt! You said "$spoken" but the correct pronunciation is "$correct".\n\n';
      response += 'Pronunciation guide: $pronunciation\n';
      response += 'Tip: $tip\n\n';
      response += 'Try saying it again. Here are practice sentences:\n';
      for (var sentence in practiceSentences) {
        response += '• $sentence\n';
      }
    } else {
      response = '✗ Let me help you with the pronunciation.\n\n';
      response += 'You said: "$spoken"\n';
      response += 'Correct: "$correct"\n';
      response += 'Pronunciation: $pronunciation\n';
      response += 'Tip: $tip\n\n';
      response += 'Practice these sentences:\n';
      for (var sentence in practiceSentences) {
        response += '• $sentence\n';
      }
      response += '\nTry saying "$correct" again, focusing on the pronunciation guide.';
    }
    
    return response;
  }

  Future<void> _sendVoiceMessage() async {
    _silenceTimer?.cancel();
    _speech.stop();
    setState(() => _isListening = false);
    
    final text = _voiceText.trim();
    if (text.isEmpty) return;

    await _processMessage(text, isVoiceInput: true);
    setState(() {
      _voiceText = '';
      _messageController.clear();
    });
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _processMessage(text, isVoiceInput: false);
    setState(() {
      _messageController.clear();
      _voiceText = '';
    });
  }

  Future<void> _processMessage(String text, {required bool isVoiceInput}) async {
    // Prevent too frequent requests
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = (_minRequestInterval - timeSinceLastRequest).inSeconds;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait $waitTime second${waitTime > 1 ? 's' : ''} before sending another message.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    
    // Add user message
    final userMessage = Message(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      language: _detectLanguage(text),
      isVoiceInput: isVoiceInput,
    );
    setState(() {
      _messages.add(userMessage);
      _isProcessing = true;
    });

    _scrollToBottom();
    
    // Update last request time
    _lastRequestTime = DateTime.now();

    String aiResponse;
    
    try {
      // Convert message history to API format (exclude the current user message)
      final conversationHistory = _messages
          .where((msg) => msg != userMessage)
          .map((msg) => {
                'isUser': msg.isUser,
                'text': msg.text,
              })
          .toList();
      
      final history = AIService.convertMessagesToHistory(conversationHistory);
      
      // Get AI response from OpenAI API (with automatic retry on rate limits)
      final response = await _aiService.getAIResponse(text, history);
      
      if (response != null && response.isNotEmpty) {
        aiResponse = response;
      } else {
        aiResponse = 'I\'m sorry, I couldn\'t generate a response. Please try again.';
      }
    } catch (e) {
      // Handle errors gracefully
      debugPrint('AI Service Error: $e');
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Provide user-friendly error message
      if (errorMessage.contains('API key') || errorMessage.contains('OPENAI_API_KEY')) {
        aiResponse = 'AI service is not configured. Please add your OpenAI API key to the .env file.\n\n'
            'Error: $errorMessage';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('Network')) {
        aiResponse = 'I\'m having trouble connecting to the AI service. Please check your internet connection and try again.';
      } else if (errorMessage.contains('Rate limit')) {
        // Extract wait time if available
        final waitMatch = RegExp(r'wait (\d+)').firstMatch(errorMessage);
        if (waitMatch != null) {
          final waitSeconds = waitMatch.group(1);
          aiResponse = 'Rate limit exceeded. Please wait $waitSeconds seconds before trying again.\n\n'
              'The app will automatically retry your request, but you may need to wait a bit longer.';
        } else {
          aiResponse = 'Rate limit exceeded. The app is automatically retrying your request. Please wait a moment...\n\n'
              'If this persists, you may have reached your API usage limit. Please check your OpenAI account.';
        }
      } else {
        aiResponse = 'Sorry, I encountered an error: $errorMessage\n\nPlease try again.';
      }
    }

    final aiMessage = Message(
      text: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
      _isProcessing = false;
    });

    _scrollToBottom();
    
    // Auto-speak AI response
    await _speakText(aiResponse);
  }

  Future<void> _speakText(String text) async {
    try {
      // Clean up the text - remove markdown-like formatting and extra whitespace
      String cleanText = text
          .replaceAll(RegExp(r'\n+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // Remove common prefixes that aren't useful for TTS
      cleanText = cleanText.replaceAll(RegExp(r'^[•\-\*]\s*'), '');
      
      // If text is too long, speak a reasonable portion
      if (cleanText.length > 500) {
        // Take first 500 characters and find the last sentence
        final truncated = cleanText.substring(0, 500);
        final lastPeriod = truncated.lastIndexOf('.');
        if (lastPeriod > 0) {
          cleanText = truncated.substring(0, lastPeriod + 1);
        } else {
          cleanText = truncated;
        }
      }
      
      if (cleanText.isNotEmpty) {
        await _flutterTts.speak(cleanText);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
      // Silently fail - TTS is optional
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = isDark ? kDarkBackground : kLightBackground;
    final textColor = isDark ? kTextLight : kTextDark;
    final cardColor = isDark ? kDarkCard : Colors.white;
    final accentColor = kAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text(
          'AI Conversation Assistant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => widget.onToggleDarkMode(!isDark),
          ),
        ],
      ),
      body: Column(
          children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isProcessing) {
                  return _buildTypingIndicator(cardColor, accentColor);
                }
                return _buildMessageBubble(_messages[index], textColor, cardColor, accentColor, backgroundColor);
              },
            ),
          ),

          // Input area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Voice input button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.redAccent : accentColor,
                      ),
                      child: IconButton(
                        onPressed: _isListening ? _stopListening : _startListening,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening...' : 'Type or speak your message...',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        enabled: !_isListening, // Disable text input when listening
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (!_isListening) {
                            _sendTextMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Send button (text only)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                      child: IconButton(
                        onPressed: _isProcessing || _isListening ? null : _sendTextMessage,
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildMessageBubble(Message message, Color textColor, Color cardColor, Color accentColor, Color backgroundColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: accentColor,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? accentColor : cardColor,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: message.isUser ? const Radius.circular(4) : null,
                  bottomLeft: !message.isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: message.isUser ? Colors.white : textColor,
                    ),
                  ),
                  if (!message.isUser) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Only show TTS button if message contains quotes (AI Assistant mode)
                        if (message.text.contains('"')) ...[
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 18),
                            color: accentColor,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              try {
                                final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(message.text);
                                if (quoteMatch != null) {
                                  await _flutterTts.speak(quoteMatch.group(1)!);
                                } else {
                                  await _flutterTts.speak(message.text);
                                }
                              } catch (e) {
                                debugPrint('TTS error: $e');
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade400,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Color cardColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accentColor,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0, accentColor),
                const SizedBox(width: 4),
                _buildDot(1, accentColor),
                const SizedBox(width: 4),
                _buildDot(2, accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity((value + index * 0.3) % 1.0),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _silenceTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    try {
      _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
    super.dispose();
  }
}
