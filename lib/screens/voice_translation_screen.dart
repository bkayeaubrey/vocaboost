import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vocaboost/services/ai_service.dart';
import 'package:intl/intl.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? language;
  final bool isVoiceInput;
  final MessageStatus status;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.language,
    this.isVoiceInput = false,
    this.status = MessageStatus.sent,
  });
}

enum MessageStatus { sending, sent, delivered, error }

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

class _VoiceTranslationScreenState extends State<VoiceTranslationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final AIService _aiService = AIService();
  bool _isListening = false;
  bool _isProcessing = false;
  String _voiceText = '';
  final List<Message> _messages = [];
  Timer? _silenceTimer;
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 2);
  bool _showScrollToBottom = false;
  late AnimationController _micAnimationController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    try {
      _flutterTts = FlutterTts();
      _initializeTts();
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
    }
    _addWelcomeMessage();
    
    _scrollController.addListener(() {
      final showButton = _scrollController.hasClients &&
          _scrollController.offset < _scrollController.position.maxScrollExtent - 100;
      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    });
  }

  Future<void> _initializeTts() async {
    try {
      List<String> languageCodes = ['fil-PH', 'tl-PH', 'fil', 'tl', 'ceb-PH', 'ceb'];
      String? selectedLanguage;
      
      List<dynamic> languages = await _flutterTts.getLanguages;
      
      for (String code in languageCodes) {
        if (languages.contains(code)) {
          selectedLanguage = code;
          break;
        }
      }
      
      if (selectedLanguage == null) {
        for (dynamic lang in languages) {
          String langStr = lang.toString().toLowerCase();
          if (langStr.contains('ph') || langStr.contains('filipino') || 
              langStr.contains('tagalog') || langStr.contains('bisaya') ||
              langStr.contains('cebuano')) {
            selectedLanguage = lang.toString();
            break;
          }
        }
      }
      
      await _flutterTts.setLanguage(selectedLanguage ?? 'en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      try {
        await _flutterTts.setLanguage('en-US');
      } catch (e2) {
        // Continue without TTS
      }
    }
  }

  void _addWelcomeMessage() {
    _messages.add(Message(
      text: 'Kumusta! 👋 I\'m your Bisaya learning assistant.\n\nI can help you:\n• Translate words & phrases\n• Learn pronunciation\n• Practice conversations\n\nJust type or tap the mic to start!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening && _voiceText.isNotEmpty) {
        _sendVoiceMessage();
      }
    });
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        debugPrint('Speech recognition status: $val');
        if (val == 'done' || val == 'notListening') {
          if (_isListening && _voiceText.isNotEmpty) {
            _sendVoiceMessage();
          }
        } else if (val == 'notAvailable') {
          if (mounted) {
            setState(() => _isListening = false);
            _showErrorSnackBar('Speech recognition not available on this device');
          }
        }
      },
      onError: (val) {
        debugPrint('Speech recognition error: $val');
        if (mounted) {
          setState(() => _isListening = false);
          _showErrorSnackBar('Speech recognition error. Please try again.');
        }
      },
    );
    
    if (!available) {
      if (mounted) {
        _showErrorSnackBar('Speech recognition not available. Please check permissions.');
      }
      return;
    }

    setState(() {
      _isListening = true;
      _voiceText = '';
      _messageController.text = '';
    });
    _resetSilenceTimer();
    
    try {
      _speech.listen(
        onResult: (val) {
          setState(() {
            _voiceText = val.recognizedWords;
            _messageController.text = _voiceText;
          });
          if (val.finalResult) {
            _sendVoiceMessage();
          } else {
            _resetSilenceTimer();
          }
        },
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      if (mounted) {
        setState(() => _isListening = false);
        _showErrorSnackBar('Failed to start speech recognition');
      }
    }
  }

  void _stopListening() {
    _silenceTimer?.cancel();
    try {
      _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
    setState(() => _isListening = false);
    if (_voiceText.isNotEmpty) {
      _sendVoiceMessage();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  Future<void> _sendVoiceMessage() async {
    _silenceTimer?.cancel();
    try {
      _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
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
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        return;
      }
    }
    
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
    _lastRequestTime = DateTime.now();

    String aiResponse;
    
    try {
      final conversationHistory = _messages
          .where((msg) => msg != userMessage)
          .map((msg) => {
                'isUser': msg.isUser,
                'text': msg.text,
              })
          .toList();
      
      final history = AIService.convertMessagesToHistory(conversationHistory);
      final response = await _aiService.getAIResponse(text, history);
      
      if (response != null && response.isNotEmpty) {
        aiResponse = response;
      } else {
        aiResponse = 'I\'m sorry, I couldn\'t generate a response. Please try again.';
      }
    } catch (e) {
      debugPrint('AI Service Error: $e');
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      if (errorMessage.contains('API key') || errorMessage.contains('OPENAI_API_KEY')) {
        aiResponse = '⚠️ AI service is not configured. Please check your API key.';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('Network')) {
        aiResponse = '📡 Connection issue. Please check your internet and try again.';
      } else if (errorMessage.contains('Rate limit')) {
        aiResponse = '⏳ Too many requests. Please wait a moment and try again.';
      } else {
        aiResponse = '❌ Something went wrong. Please try again.';
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
    await _speakText(aiResponse);
  }

  Future<void> _speakText(String text) async {
    try {
      String cleanText = text
          .replaceAll(RegExp(r'\n+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[•\-\*⚠️📡⏳❌👋]'), '')
          .trim();
      
      if (cleanText.length > 500) {
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

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Messenger-style colors
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final chatBgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final userBubbleColor = const Color(0xFF0084FF); // Messenger blue
    final aiBubbleColor = isDark ? const Color(0xFF303030) : const Color(0xFFE4E6EB);
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final inputBgColor = isDark ? const Color(0xFF303030) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, backgroundColor, textColor),
      body: Container(
        color: chatBgColor,
        child: Column(
          children: [
            // Chat messages
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show date header for first message or when date changes
                      Widget? dateHeader;
                      if (index < _messages.length) {
                        if (index == 0 || 
                            !_isSameDay(_messages[index].timestamp, _messages[index - 1].timestamp)) {
                          dateHeader = _buildDateHeader(_messages[index].timestamp, secondaryTextColor);
                        }
                      }
                      
                      if (index == _messages.length && _isProcessing) {
                        return _buildTypingIndicator(aiBubbleColor, userBubbleColor);
                      }
                      
                      return Column(
                        children: [
                          if (dateHeader != null) dateHeader,
                          _buildMessageBubble(
                            _messages[index],
                            userBubbleColor,
                            aiBubbleColor,
                            textColor,
                            secondaryTextColor,
                            index,
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Scroll to bottom button
                  if (_showScrollToBottom)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: userBubbleColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Input area
            _buildInputArea(isDark, inputBgColor, textColor, userBubbleColor, backgroundColor),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color backgroundColor, Color textColor) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // AI Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/launcher.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.smart_toy, color: Colors.white, size: 24);
                    },
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: backgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bisaya Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  _isProcessing ? 'Typing...' : 'Active now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _isProcessing ? const Color(0xFF0084FF) : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }

  Widget _buildDateHeader(DateTime date, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatDateHeader(date),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageBubble(
    Message message,
    Color userBubbleColor,
    Color aiBubbleColor,
    Color textColor,
    Color secondaryTextColor,
    int index,
  ) {
    final isUser = message.isUser;
    final showAvatar = !isUser && (index == 0 || _messages[index - 1].isUser);
    final showTail = index == _messages.length - 1 || _messages[index + 1].isUser != isUser;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: showTail ? 8 : 2,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar
          if (!isUser)
            SizedBox(
              width: 32,
              child: showAvatar
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/launcher.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.smart_toy, color: Colors.white, size: 16);
                          },
                        ),
                      ),
                    )
                  : null,
            ),
          
          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? userBubbleColor : aiBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser || !showTail ? 18 : 4),
                    bottomRight: Radius.circular(!isUser || !showTail ? 18 : 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voice indicator
                    if (message.isVoiceInput && isUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Voice message',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Message text
                    Text(
                      message.text,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: isUser ? Colors.white : textColor,
                        height: 1.4,
                      ),
                    ),
                    
                    // Timestamp and actions for AI messages
                    if (!isUser) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // TTS button
                          GestureDetector(
                            onTap: () => _speakText(message.text),
                            child: Icon(
                              Icons.volume_up_outlined,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Copy button
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: message.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Message copied!')),
                              );
                            },
                            child: Icon(
                              Icons.copy_outlined,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textColor = widget.isDarkMode ? Colors.white : Colors.black;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.volume_up, color: textColor),
                  title: Text('Listen', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _speakText(message.text);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy, color: textColor),
                  title: Text('Copy', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied!')),
                    );
                  },
                ),
                if (!message.isUser)
                  ListTile(
                    leading: Icon(Icons.replay, color: textColor),
                    title: Text('Regenerate response', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.pop(context);
                      final index = _messages.indexOf(message);
                      if (index > 0) {
                        final userMsg = _messages[index - 1];
                        if (userMsg.isUser) {
                          _processMessage(userMsg.text, isVoiceInput: userMsg.isVoiceInput);
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(Color aiBubbleColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0084FF), width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/launcher.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.smart_toy, color: Color(0xFF0084FF), size: 16);
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: aiBubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 200)),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.3 + (value * 0.7)),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    bool isDark,
    Color inputBgColor,
    Color textColor,
    Color accentColor,
    Color backgroundColor,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      enabled: !_isListening,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_isListening && !_isProcessing) {
                          _sendTextMessage();
                        }
                      },
                      onChanged: (text) {
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Mic or Send button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _messageController.text.trim().isNotEmpty
                ? Container(
                    key: const ValueKey('send'),
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0084FF), Color(0xFF00C6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isProcessing ? null : _sendTextMessage,
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: _isListening ? _stopListening : _startListening,
                    onLongPress: _startListening,
                    onLongPressEnd: (_) {
                      if (_isListening) _stopListening();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: _isListening
                            ? const LinearGradient(
                                colors: [Colors.red, Colors.redAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF0084FF), Color(0xFF00C6FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedBuilder(
                        animation: _micAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? 1.0 + (_micAnimationController.value * 0.2) : 1.0,
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 22,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.translate,
                      label: 'Translate',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = 'Translate: ';
                        _focusNode.requestFocus();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.record_voice_over,
                      label: 'Pronounce',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = 'How do you pronounce ';
                        _focusNode.requestFocus();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.quiz,
                      label: 'Quiz me',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = 'Quiz me on Bisaya words';
                        _sendTextMessage();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.chat_bubble_outline,
                      label: 'Conversation',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = 'Let\'s practice a conversation in Bisaya';
                        _sendTextMessage();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _micAnimationController.dispose();
    try {
      _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech recognition in dispose: $e');
    }
    try {
      _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
    super.dispose();
  }
}
