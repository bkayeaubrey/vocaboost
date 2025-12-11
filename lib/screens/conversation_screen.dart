import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/xp_service.dart';
import '../services/achievement_service.dart';
import '../widgets/badge_notification.dart';

class ConversationScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? onToggleDarkMode;
  
  const ConversationScreen({super.key, this.isDarkMode = false, this.onToggleDarkMode});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with TickerProviderStateMixin {
  // Theme colors
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);
  static const Color kCorrect = Color(0xFF4CAF50);
  static const Color kWrong = Color(0xFFE53935);

  // Services
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ConfettiController _confettiController;
  final XPService _xpService = XPService();
  final AchievementService _achievementService = AchievementService();

  // State
  int _currentScenarioIndex = 0;
  int _currentDialogueIndex = 0;
  int _streak = 0;
  int _totalXP = 0;
  bool _isLoading = false;
  bool _showingFeedback = false;
  bool _isCorrect = false;
  String _feedbackMessage = '';
  String _correctedText = '';
  final List<Map<String, dynamic>> _chatHistory = [];
  int? _selectedOptionIndex;
  bool _useTyping = false; // Toggle between choices and typing

  // Scenarios with dialogues
  final List<Map<String, dynamic>> _scenarios = [
    {
      'id': 'market',
      'title': 'At the Market',
      'titleBisaya': 'Sa Merkado',
      'icon': Icons.store,
      'dialogues': [
        {
          'speaker': 'Tindera',
          'speakerEnglish': 'Vendor',
          'text': 'Maayong buntag! Unsa imong gusto paliton?',
          'translation': 'Good morning! What would you like to buy?',
          'userPrompt': 'Greet back and ask how much the mangoes cost',
          'expectedKeywords': ['maayong buntag', 'tagpila', 'mangga', 'pila'],
          'correctExamples': ['Maayong buntag! Tagpila ang mangga?'],
          'hints': ['Start with "Maayong buntag"', 'Use "Tagpila" to ask price'],
          'options': [
            {'text': 'Maayong buntag! Tagpila ang mangga?', 'translation': 'Good morning! How much are the mangoes?', 'correct': true},
            {'text': 'Asa ang CR?', 'translation': 'Where is the bathroom?', 'correct': false},
            {'text': 'Salamat kaayo!', 'translation': 'Thank you very much!', 'correct': false},
            {'text': 'Maayong buntag! Tagpila ang saging?', 'translation': 'Good morning! How much are the bananas?', 'correct': false},
          ],
        },
        {
          'speaker': 'Tindera',
          'speakerEnglish': 'Vendor',
          'text': 'Ang mangga kay bente pesos kada kilo.',
          'translation': 'The mangoes are twenty pesos per kilo.',
          'userPrompt': 'Say you want to buy two kilos',
          'expectedKeywords': ['gusto', 'duha', 'kilo', 'paliton', 'palit'],
          'correctExamples': ['Gusto ko mopalit ug duha ka kilo.', 'Paliton ko duha ka kilo.'],
          'hints': ['Use "Gusto ko" for "I want"', '"Duha ka kilo" means two kilos'],
          'options': [
            {'text': 'Gusto ko mopalit ug duha ka kilo.', 'translation': 'I want to buy two kilos.', 'correct': true},
            {'text': 'Dili ko ganahan.', 'translation': 'I don\'t like it.', 'correct': false},
            {'text': 'Mahal ra kaayo!', 'translation': 'That\'s too expensive!', 'correct': false},
            {'text': 'Asa gikan ni?', 'translation': 'Where is this from?', 'correct': false},
          ],
        },
        {
          'speaker': 'Tindera',
          'speakerEnglish': 'Vendor',
          'text': 'Sige, kuwarenta pesos tanan. Salamat!',
          'translation': 'Okay, forty pesos total. Thank you!',
          'userPrompt': 'Thank her and say goodbye',
          'expectedKeywords': ['salamat', 'babay', 'daghang salamat'],
          'correctExamples': ['Daghang salamat! Babay!', 'Salamat kaayo! Babay!'],
          'hints': ['"Salamat" means thank you', '"Babay" means goodbye'],
          'options': [
            {'text': 'Daghang salamat! Babay!', 'translation': 'Thank you very much! Goodbye!', 'correct': true},
            {'text': 'Pila ka tuig ka na?', 'translation': 'How old are you?', 'correct': false},
            {'text': 'Unsang oras na?', 'translation': 'What time is it?', 'correct': false},
            {'text': 'Nindot kaayo!', 'translation': 'Very beautiful!', 'correct': false},
          ],
        },
      ],
    },
    {
      'id': 'directions',
      'title': 'Asking Directions',
      'titleBisaya': 'Nangutana ug Direksyon',
      'icon': Icons.directions,
      'dialogues': [
        {
          'isUserStart': true,
          'userPrompt': 'Ask where the hospital is',
          'expectedKeywords': ['asa', 'hospital', 'ospital'],
          'correctExamples': ['Asa man ang hospital?', 'Asa ang ospital?'],
          'hints': ['"Asa" means where', 'Hospital in Bisaya is "ospital" or "hospital"'],
          'options': [
            {'text': 'Asa man ang hospital?', 'translation': 'Where is the hospital?', 'correct': true},
            {'text': 'Pila ang pamasahe?', 'translation': 'How much is the fare?', 'correct': false},
            {'text': 'Unsa ang imong ngalan?', 'translation': 'What is your name?', 'correct': false},
            {'text': 'Tagpila ni?', 'translation': 'How much is this?', 'correct': false},
          ],
        },
        {
          'speaker': 'Tao sa dalan',
          'speakerEnglish': 'Person on street',
          'text': 'Diretso lang, dayon liko sa wala pagkahuman sa simbahan.',
          'translation': 'Go straight, then turn left after the church.',
          'userPrompt': 'Ask if it\'s far from here',
          'expectedKeywords': ['layo', 'diri', 'dinhi', 'halayo'],
          'correctExamples': ['Layo ba diri?', 'Halayo ba gikan diri?'],
          'hints': ['"Layo" means far', '"Diri/dinhi" means here'],
          'options': [
            {'text': 'Layo ba gikan diri?', 'translation': 'Is it far from here?', 'correct': true},
            {'text': 'Pila ka minuto?', 'translation': 'How many minutes?', 'correct': false},
            {'text': 'Nindot ang simbahan!', 'translation': 'The church is beautiful!', 'correct': false},
            {'text': 'Dili ko kasabot.', 'translation': 'I don\'t understand.', 'correct': false},
          ],
        },
        {
          'speaker': 'Tao sa dalan',
          'speakerEnglish': 'Person on street',
          'text': 'Dili kaayo. Mga lima ka minuto ra kung maglakaw.',
          'translation': 'Not really. About five minutes if walking.',
          'userPrompt': 'Thank them for the help',
          'expectedKeywords': ['salamat', 'tabang', 'daghang'],
          'correctExamples': ['Salamat sa tabang!', 'Daghang salamat!'],
          'hints': ['"Salamat" means thank you', '"Tabang" means help'],
          'options': [
            {'text': 'Salamat sa tabang!', 'translation': 'Thanks for the help!', 'correct': true},
            {'text': 'Maayo kaayo!', 'translation': 'Very good!', 'correct': false},
            {'text': 'Sige, lakaw na ko.', 'translation': 'Okay, I\'ll go now.', 'correct': false},
            {'text': 'Amping!', 'translation': 'Take care!', 'correct': false},
          ],
        },
      ],
    },
    {
      'id': 'restaurant',
      'title': 'At the Restaurant',
      'titleBisaya': 'Sa Restawran',
      'icon': Icons.restaurant,
      'dialogues': [
        {
          'speaker': 'Weyter',
          'speakerEnglish': 'Waiter',
          'text': 'Maayong gabii! Pila ka buok mo?',
          'translation': 'Good evening! How many of you?',
          'userPrompt': 'Say there are two of you',
          'expectedKeywords': ['duha', 'kami', 'duha mi'],
          'correctExamples': ['Duha ra mi.', 'Duha ka buok kami.'],
          'hints': ['"Duha" means two', '"Kami/mi" means we/us'],
          'options': [
            {'text': 'Duha ra mi.', 'translation': 'Just two of us.', 'correct': true},
            {'text': 'Usa ra ko.', 'translation': 'Just me alone.', 'correct': false},
            {'text': 'Daghan mi!', 'translation': 'There are many of us!', 'correct': false},
            {'text': 'Maayong gabii!', 'translation': 'Good evening!', 'correct': false},
          ],
        },
        {
          'speaker': 'Weyter',
          'speakerEnglish': 'Waiter',
          'text': 'Sige, mao ni ang menu. Unsa ang inyong gusto imnon?',
          'translation': 'Okay, here is the menu. What would you like to drink?',
          'userPrompt': 'Order water please',
          'expectedKeywords': ['tubig', 'palihug', 'gusto', 'imnon'],
          'correctExamples': ['Tubig lang palihug.', 'Gusto ko ug tubig.'],
          'hints': ['"Tubig" means water', '"Palihug" means please'],
          'options': [
            {'text': 'Tubig lang palihug.', 'translation': 'Just water please.', 'correct': true},
            {'text': 'Coke palihug.', 'translation': 'Coke please.', 'correct': false},
            {'text': 'Wala ko uhaw.', 'translation': 'I\'m not thirsty.', 'correct': false},
            {'text': 'Unsa ang espesyal?', 'translation': 'What\'s the special?', 'correct': false},
          ],
        },
        {
          'speaker': 'Weyter',
          'speakerEnglish': 'Waiter',
          'text': 'Andam na mo mo-order ug pagkaon?',
          'translation': 'Are you ready to order food?',
          'userPrompt': 'Ask what they recommend',
          'expectedKeywords': ['unsa', 'recommend', 'rekomendar', 'maayo', 'lami'],
          'correctExamples': ['Unsa ang inyong girerekomendar?', 'Unsa ang lami diri?'],
          'hints': ['"Unsa" means what', '"Lami" means delicious'],
          'options': [
            {'text': 'Unsa ang inyong girerekomendar?', 'translation': 'What do you recommend?', 'correct': true},
            {'text': 'Pila ang presyo?', 'translation': 'What\'s the price?', 'correct': false},
            {'text': 'Busog na ko.', 'translation': 'I\'m already full.', 'correct': false},
            {'text': 'Nindot ang lugar!', 'translation': 'Nice place!', 'correct': false},
          ],
        },
      ],
    },
    {
      'id': 'meeting',
      'title': 'Meeting Someone New',
      'titleBisaya': 'Pagkita ug Bag-ong Tawo',
      'icon': Icons.people,
      'dialogues': [
        {
          'isUserStart': true,
          'userPrompt': 'Greet and introduce yourself',
          'expectedKeywords': ['maayong', 'buntag', 'ako', 'ngalan', 'si'],
          'correctExamples': ['Maayong buntag! Ako si Juan.', 'Kumusta! Ang akong ngalan kay Maria.'],
          'hints': ['"Ako si [name]" means I am [name]', '"Maayong buntag" means good morning'],
          'options': [
            {'text': 'Maayong buntag! Ako si Juan.', 'translation': 'Good morning! I am Juan.', 'correct': true},
            {'text': 'Kumusta ka?', 'translation': 'How are you?', 'correct': false},
            {'text': 'Asa ka gikan?', 'translation': 'Where are you from?', 'correct': false},
            {'text': 'Nindot ang adlaw!', 'translation': 'Nice day!', 'correct': false},
          ],
        },
        {
          'speaker': 'Bag-ong higala',
          'speakerEnglish': 'New friend',
          'text': 'Maayong buntag! Ako si Maria. Taga asa ka?',
          'translation': 'Good morning! I am Maria. Where are you from?',
          'userPrompt': 'Say where you are from (Manila)',
          'expectedKeywords': ['taga', 'manila', 'gikan', 'ako'],
          'correctExamples': ['Taga Manila ko.', 'Gikan ko sa Manila.'],
          'hints': ['"Taga [place]" means from [place]', '"Gikan" also means from'],
          'options': [
            {'text': 'Taga Manila ko.', 'translation': 'I\'m from Manila.', 'correct': true},
            {'text': 'Taga Cebu ko.', 'translation': 'I\'m from Cebu.', 'correct': false},
            {'text': 'Bag-o lang ko diri.', 'translation': 'I\'m new here.', 'correct': false},
            {'text': 'Nindot diri!', 'translation': 'It\'s nice here!', 'correct': false},
          ],
        },
        {
          'speaker': 'Bag-ong higala',
          'speakerEnglish': 'New friend',
          'text': 'Ah nice! Unsa ang imong trabaho?',
          'translation': 'Ah nice! What is your job?',
          'userPrompt': 'Say you are a teacher',
          'expectedKeywords': ['maestro', 'maestra', 'teacher', 'magtutudlo'],
          'correctExamples': ['Ako kay magtutudlo.', 'Maestro/Maestra ko.'],
          'hints': ['"Magtutudlo" means teacher', '"Ako kay" means I am'],
          'options': [
            {'text': 'Magtutudlo ko.', 'translation': 'I\'m a teacher.', 'correct': true},
            {'text': 'Estudyante ko.', 'translation': 'I\'m a student.', 'correct': false},
            {'text': 'Wala koy trabaho.', 'translation': 'I don\'t have a job.', 'correct': false},
            {'text': 'Busy kaayo ko.', 'translation': 'I\'m very busy.', 'correct': false},
          ],
        },
      ],
    },
  ];

  Map<String, dynamic> get _currentScenario => _scenarios[_currentScenarioIndex];
  List<Map<String, dynamic>> get _dialogues => 
      List<Map<String, dynamic>>.from(_currentScenario['dialogues']);
  Map<String, dynamic> get _currentDialogue => _dialogues[_currentDialogueIndex];
  bool get _isUserTurn => _currentDialogue['isUserStart'] == true || 
      _chatHistory.isNotEmpty && _chatHistory.last['isNPC'] == true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initTTS();
    _startConversation();
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('fil-PH');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _startConversation() {
    _chatHistory.clear();
    _currentDialogueIndex = 0;
    _showingFeedback = false;
    _selectedOptionIndex = null;
    _useTyping = false;
    
    // If NPC starts, add their message
    if (_currentDialogue['isUserStart'] != true) {
      _addNPCMessage(_currentDialogue);
    }
    setState(() {});
  }

  void _addNPCMessage(Map<String, dynamic> dialogue) {
    _chatHistory.add({
      'isNPC': true,
      'speaker': dialogue['speaker'] ?? '',
      'speakerEnglish': dialogue['speakerEnglish'] ?? '',
      'text': dialogue['text'] ?? '',
      'translation': dialogue['translation'] ?? '',
    });
    _speak(dialogue['text'] ?? '');
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Track conversation completion and check achievements
  Future<void> _trackConversationCompletion() async {
    try {
      // Get conversations count from Firebase
      final conversationsCount = await _getConversationsCount();
      
      // Check conversation achievements
      final unlockedBadges = await _achievementService.checkAndUnlockBadges(
        conversations: conversationsCount,
      );
      
      // Show badge notifications
      if (mounted && unlockedBadges.isNotEmpty) {
        BadgeNotification.showMultiple(context, unlockedBadges);
      }
    } catch (e) {
      debugPrint('Error tracking conversation completion: $e');
    }
  }

  /// Get total conversations completed count
  Future<int> _getConversationsCount() async {
    // For now, we'll estimate based on scenarios completed
    // Each scenario completion counts as one conversation
    return _currentScenarioIndex + 1;
  }

  void _selectOption(int index) {
    if (_showingFeedback || _isLoading) return;
    
    setState(() {
      _selectedOptionIndex = index;
    });
    
    final options = List<Map<String, dynamic>>.from(_currentDialogue['options']);
    final selectedOption = options[index];
    final isCorrect = selectedOption['correct'] == true;
    
    _processAnswer(selectedOption['text'], isCorrect, isFromChoice: true);
  }

  Future<void> _submitTypedAnswer() async {
    if (_textController.text.trim().isEmpty || _isLoading) return;
    
    final userText = _textController.text.trim();
    setState(() {
      _isLoading = true;
    });
    
    // Check with AI
    final result = await _checkWithAI(userText);
    _processAnswer(userText, result['isCorrect'], 
        aiCorrection: result['correction'],
        isFromChoice: false);
    
    _textController.clear();
  }

  void _processAnswer(String userText, bool isCorrect, {String? aiCorrection, bool isFromChoice = false}) {
    // Add user message to chat
    _chatHistory.add({
      'isNPC': false,
      'text': userText,
      'translation': isFromChoice ? 
          List<Map<String, dynamic>>.from(_currentDialogue['options'])
              .firstWhere((o) => o['text'] == userText)['translation'] ?? '' : '',
      'isCorrect': isCorrect,
    });

    if (isCorrect) {
      _streak++;
      int xpGained = 10 + (_streak > 3 ? 5 : 0);
      _totalXP += xpGained;
      _xpService.earnXP(amount: xpGained, activityType: 'conversation');
      
      _feedbackMessage = _streak > 3 
          ? '🔥 On Fire! +$xpGained XP' 
          : '✨ Correct! +$xpGained XP';
      _correctedText = '';
      
      if (_streak >= 5) {
        _confettiController.play();
      }
    } else {
      _streak = 0;
      final correctOption = List<Map<String, dynamic>>.from(_currentDialogue['options'])
          .firstWhere((o) => o['correct'] == true);
      _feedbackMessage = '❌ Not quite right';
      _correctedText = aiCorrection ?? 'Try: ${correctOption['text']}';
    }

    setState(() {
      _isCorrect = isCorrect;
      _showingFeedback = true;
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<Map<String, dynamic>> _checkWithAI(String userText) async {
    try {
      final prompt = '''
You are a Bisaya language teacher checking a student's response.

Scenario: ${_currentScenario['title']}
Task: ${_currentDialogue['userPrompt']}
Expected keywords/phrases: ${_currentDialogue['expectedKeywords'].join(', ')}
Good examples: ${_currentDialogue['correctExamples'].join(' OR ')}

Student's response: "$userText"

Check if the response:
1. Addresses the task appropriately
2. Uses correct Bisaya grammar and vocabulary
3. Contains relevant keywords or their valid alternatives

Respond in JSON format:
{
  "isCorrect": true/false,
  "correction": "If incorrect, provide the corrected version with explanation. If correct, leave empty."
}
''';

      final response = await http.post(
        Uri.parse('https://us-central1-vocaboost-fb.cloudfunctions.net/openaiProxy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful Bisaya language tutor.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final parsed = jsonDecode(jsonMatch.group(0)!);
          return {
            'isCorrect': parsed['isCorrect'] ?? false,
            'correction': parsed['correction'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('AI check error: $e');
    }
    
    // Fallback: simple keyword matching
    final keywords = List<String>.from(_currentDialogue['expectedKeywords']);
    final lowerText = userText.toLowerCase();
    final hasKeyword = keywords.any((k) => lowerText.contains(k.toLowerCase()));
    
    return {
      'isCorrect': hasKeyword,
      'correction': hasKeyword ? '' : 'Try using: ${keywords.take(2).join(", ")}',
    };
  }

  void _continueConversation() {
    setState(() {
      _showingFeedback = false;
      _selectedOptionIndex = null;
      _useTyping = false;
    });

    // Move to next dialogue
    if (_currentDialogueIndex < _dialogues.length - 1) {
      _currentDialogueIndex++;
      
      // Add NPC response if not user start
      if (_currentDialogue['isUserStart'] != true) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _addNPCMessage(_currentDialogue);
          setState(() {});
        });
      } else {
        setState(() {});
      }
    } else {
      // Scenario complete
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    _confettiController.play();
    
    // Track conversation completion and check achievements
    _trackConversationCompletion();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎉 ', style: TextStyle(fontSize: 32)),
            const Expanded(
              child: Text('Conversation Complete!', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withOpacity(0.1), kAccent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '+$_totalXP XP',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best Streak: $_streak 🔥',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _selectNextScenario();
            },
            child: const Text('Next Scenario'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _selectNextScenario() {
    setState(() {
      _currentScenarioIndex = (_currentScenarioIndex + 1) % _scenarios.length;
      _totalXP = 0;
      _streak = 0;
    });
    _startConversation();
  }

  void _showHints() {
    final hints = List<String>.from(_currentDialogue['hints'] ?? []);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Hints', style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...hints.map((hint) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(hint, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Text(
              'Example: ${_currentDialogue['correctExamples'][0]}',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_currentScenario['icon'] as IconData, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentScenario['title'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_currentScenario['titleBisaya'],
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          // Streak badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text('$_streak', style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          // XP badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text('$_totalXP', style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentDialogueIndex + 1) / _dialogues.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                minHeight: 4,
              ),
              
              // Chat history
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatHistory.length + (_isUserTurn && !_showingFeedback ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatHistory.length) {
                      // User prompt card
                      return _buildUserPromptCard();
                    }
                    return _buildChatBubble(_chatHistory[index]);
                  },
                ),
              ),

              // Feedback banner
              if (_showingFeedback)
                _buildFeedbackBanner(),

              // Input area
              if (_isUserTurn && !_showingFeedback)
                _buildInputArea(),
            ],
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> message) {
    final isNPC = message['isNPC'] == true;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isNPC ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNPC) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: kAccent,
              child: Text(
                (message['speaker'] as String? ?? 'N')[0],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isNPC ? Colors.white : 
                    (message['isCorrect'] == true ? kCorrect.withOpacity(0.1) :
                     message['isCorrect'] == false ? kWrong.withOpacity(0.1) : kPrimary),
                borderRadius: BorderRadius.circular(16),
                border: isNPC ? Border.all(color: Colors.grey.shade200) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNPC && message['speaker'] != null && message['speaker'] != '') ...[
                    Text(
                      '${message['speaker']} (${message['speakerEnglish']})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  GestureDetector(
                    onTap: () => _speak(message['text'] ?? ''),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            message['text'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: isNPC ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isNPC) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.volume_up, size: 18, color: kPrimary.withOpacity(0.7)),
                        ],
                      ],
                    ),
                  ),
                  if (message['translation'] != null && message['translation'] != '') ...[
                    const SizedBox(height: 6),
                    Text(
                      message['translation'],
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isNPC ? Colors.grey[600] : Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isNPC) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: message['isCorrect'] == true ? kCorrect :
                  message['isCorrect'] == false ? kWrong : kPrimary,
              child: const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserPromptCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimary.withOpacity(0.1), kAccent.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Turn',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showHints,
                icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                tooltip: 'Show hints',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentDialogue['userPrompt'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final options = List<Map<String, dynamic>>.from(_currentDialogue['options'] ?? []);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Toggle between choices and typing
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToggleButton('Choices', !_useTyping, () {
                  setState(() => _useTyping = false);
                }),
                const SizedBox(width: 12),
                _buildToggleButton('Type Answer', _useTyping, () {
                  setState(() => _useTyping = true);
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Choices or typing input
            if (!_useTyping) ...[
              // Multiple choice options
              ...List.generate(options.length, (index) {
                final option = options[index];
                final isSelected = _selectedOptionIndex == index;
                final showTranslation = _showingFeedback; // Only show after answer
                final isCorrectOption = option['correct'] == true;
                
                // Determine border/background color based on state
                Color borderColor = Colors.grey[300]!;
                Color bgColor = Colors.grey[50]!;
                
                if (_showingFeedback) {
                  if (isCorrectOption) {
                    borderColor = kCorrect;
                    bgColor = kCorrect.withOpacity(0.1);
                  } else if (isSelected && !isCorrectOption) {
                    borderColor = kWrong;
                    bgColor = kWrong.withOpacity(0.1);
                  }
                } else if (isSelected) {
                  borderColor = kPrimary;
                  bgColor = kPrimary.withOpacity(0.1);
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: _showingFeedback ? null : () => _selectOption(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: (isSelected || (_showingFeedback && isCorrectOption)) ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option['text'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _showingFeedback
                                        ? (isCorrectOption ? kCorrect : (isSelected ? kWrong : Colors.black87))
                                        : (isSelected ? kPrimary : Colors.black87),
                                  ),
                                ),
                                // Only show translation after answering
                                if (showTranslation) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    option['translation'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Show correct/wrong icon after feedback
                          if (_showingFeedback && isCorrectOption)
                            const Icon(Icons.check_circle, color: kCorrect, size: 22)
                          else if (_showingFeedback && isSelected && !isCorrectOption)
                            const Icon(Icons.cancel, color: kWrong, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ] else ...[
              // Text input for typing
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your response in Bisaya...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitTypedAnswer(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimary, kAccent]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _submitTypedAnswer,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI will check your answer and provide corrections',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? kPrimary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _isCorrect ? kCorrect.withOpacity(0.1) : kWrong.withOpacity(0.1),
      child: SafeArea(
        child: Column(
          children: [
            Text(
              _feedbackMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isCorrect ? kCorrect : kWrong,
              ),
            ),
            if (_correctedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _correctedText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _continueConversation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCorrect ? kCorrect : kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                _currentDialogueIndex < _dialogues.length - 1 ? 'Continue' : 'Complete',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
