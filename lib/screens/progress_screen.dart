import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vocaboost/services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  const ProgressScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressService _progressService = ProgressService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  Map<String, dynamic> _wordMastery = {};
  Map<String, dynamic> _pronunciationScore = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final progressData = await _progressService.getAllProgressData(forceRefresh: forceRefresh);
      setState(() {
        _stats = (progressData['stats'] as Map<String, dynamic>?) ?? {};
        _weeklyData =
            (progressData['weeklyData'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        _wordMastery =
            (progressData['wordMastery'] as Map<String, dynamic>?) ?? {};
        _pronunciationScore = (progressData['pronunciationScore']
                as Map<String, dynamic>?) ??
            {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load progress: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Blue Hour Palette
    const kPrimary = Color(0xFF3B5FAE);
    const kAccent = Color(0xFF2666B4);
    const kLightBackground = Color(0xFFC7D4E8);
    const kDarkBackground = Color(0xFF071B34);
    const kDarkCard = Color(0xFF20304A);
    const kTextDark = Color(0xFF071B34);
    const kTextLight = Color(0xFFC7D4E8);

    final backgroundColor = widget.isDarkMode ? kDarkBackground : kLightBackground;
    final cardColor = widget.isDarkMode ? kDarkCard : Colors.white;
    final textColor = widget.isDarkMode ? kTextLight : kTextDark;
    final secondaryButtonColor = widget.isDarkMode ? kDarkCard : Color(0xFFE6EEF9);
    final chartColor = kAccent;

    final overallAccuracy = _stats['overallAccuracy']?.toDouble() ?? 0.0;
    final totalQuizzes = _stats['totalQuizzes'] ?? 0;
    final totalSavedWords = _stats['totalSavedWords'] ?? 0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: Text(
          'Progress',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: textColor,
            ),
            tooltip: 'Toggle Dark Mode',
            onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: textColor,
            tooltip: 'Refresh',
            onPressed: () => _loadProgress(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: chartColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Progress & Review',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Quizzes',
                          totalQuizzes.toString(),
                          Icons.quiz,
                          chartColor,
                          cardColor,
                          textColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Saved Words',
                          totalSavedWords.toString(),
                          Icons.bookmark,
                          Colors.green,
                          cardColor,
                          textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Accuracy Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Overall Accuracy',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${overallAccuracy.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: chartColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pronunciation Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, color: Colors.purple, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Pronunciation Score',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_pronunciationScore['pronunciationAccuracy'] ?? 0.0).toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_pronunciationScore['totalPronunciationQuizzes'] ?? 0} pronunciation quizzes',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Word Mastery Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Word Mastery',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMasteryStat(
                                'Mastered',
                                '${_wordMastery['masteredWords'] ?? 0}',
                                Colors.green,
                                textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMasteryStat(
                                'Learning',
                                '${_wordMastery['learningWords'] ?? 0}',
                                Colors.orange,
                                textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMasteryStat(
                                'Total',
                                '${_wordMastery['totalWords'] ?? 0}',
                                chartColor,
                                textColor,
                              ),
                            ),
                          ],
                        ),
                        if ((_wordMastery['wordStats'] as Map?)?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Top Words',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._buildTopWordsList(cardColor, textColor, chartColor),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Charts Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              sections: [
                                PieChartSectionData(
                                  color: chartColor,
                                  value: overallAccuracy,
                                  title: '${overallAccuracy.toStringAsFixed(0)}%',
                                  radius: 48,
                                  titleStyle: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                PieChartSectionData(
                                  color: Colors.grey,
                                  value: (100.0 - overallAccuracy),
                                  title: overallAccuracy < 100
                                      ? '${(100.0 - overallAccuracy).toStringAsFixed(0)}%'
                                      : '',
                                  radius: 42,
                                  titleStyle: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _weeklyData.isEmpty
                              ? Center(
                                  child: Text(
                                    'No data yet',
                                    style: TextStyle(color: textColor),
                                  ),
                                )
                              : BarChart(
                                  BarChartData(
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(show: false),
                                    gridData: FlGridData(show: false),
                                    barGroups: _weeklyData.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final data = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (data['score'] ?? 0).toDouble(),
                                            color: chartColor,
                                            width: 14,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 🔹 Buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View Saved Words'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chartColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Take Another Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryButtonColor,
                      foregroundColor: chartColor,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryStat(String label, String value, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopWordsList(Color cardColor, Color textColor, Color accentColor) {
    final wordStats = _wordMastery['wordStats'] as Map<String, dynamic>? ?? {};
    
    if (wordStats.isEmpty) {
      return [
        Text(
          'No words tracked yet. Take some quizzes!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: textColor.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    // Convert to list and sort by mastery percentage
    final wordList = wordStats.entries.map((entry) {
      final word = entry.key;
      final stats = entry.value as Map<String, int>;
      final correct = stats['correct'] ?? 0;
      final total = stats['total'] ?? 1;
      final accuracy = (correct / total) * 100;
      
      return {
        'word': word,
        'accuracy': accuracy,
        'correct': correct,
        'total': total,
      };
    }).toList();

    // Sort by accuracy (descending), then by total attempts
    wordList.sort((a, b) {
      final accuracyCompare = (b['accuracy'] as double).compareTo(a['accuracy'] as double);
      if (accuracyCompare != 0) return accuracyCompare;
      return (b['total'] as int).compareTo(a['total'] as int);
    });

    // Take top 5 words
    final topWords = wordList.take(5).toList();

    return topWords.map((wordData) {
      final word = wordData['word'] as String;
      final accuracy = wordData['accuracy'] as double;
      final correct = wordData['correct'] as int;
      final total = wordData['total'] as int;
      
      final isMastered = total >= 2 && accuracy >= 80;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMastered ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isMastered)
                      Icon(Icons.star, color: Colors.amber, size: 16)
                    else
                      Icon(Icons.star_border, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        word.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '${accuracy.toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMastered ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($correct/$total)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
