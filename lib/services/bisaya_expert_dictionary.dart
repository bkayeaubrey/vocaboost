/// Bisaya Vocabulary Expert Dictionary
/// Auto-generated via OpenAI API for deep, authentic Bisaya meanings
/// Source: CSV dataset + API expert validation
library;

import 'package:flutter/foundation.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/ai_service.dart';

class BisayaExpertDictionary {
  static final BisayaExpertDictionary _instance =
      BisayaExpertDictionary._internal();

  factory BisayaExpertDictionary() {
    return _instance;
  }

  BisayaExpertDictionary._internal();

  final Map<String, Map<String, dynamic>> _expertDictionary = {};
  final DatasetService _datasetService = DatasetService.instance;
  final AIService _aiService = AIService();
  bool _isLoaded = false;

  /// Initialize expert dictionary from CSV dataset
  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      debugPrint('[Expert Dictionary] Initializing from CSV dataset...');
      
      // Load all entries from CSV
      await _datasetService.loadDataset();
      final allEntries = _datasetService.getAllEntries();
      
      debugPrint('[Expert Dictionary] Found ${allEntries.length} words in dataset');
      
      // Convert CSV entries to expert format
      for (final entry in allEntries) {
        final bisaya = (entry['bisaya'] as String? ?? '').trim().toLowerCase();
        if (bisaya.isEmpty) continue;
        
        _expertDictionary[bisaya] = {
          'word': entry['bisaya'] as String? ?? bisaya,
          'shortMeaning': '${entry['english'] ?? ''} (${entry['tagalog'] ?? ''})',
          'englishMeaning': entry['english'] as String? ?? '',
          'tagalogMeaning': entry['tagalog'] as String? ?? '',
          'partOfSpeech': entry['partOfSpeech'] as String? ?? 'Word',
          'category': entry['category'] as String? ?? 'Vocabulary',
          'sampleSentenceBisaya': entry['beginnerExample'] as String? ?? '',
          'englishTranslation': entry['beginnerEnglish'] as String? ?? '',
          'tagalogTranslation': entry['beginnerTagalog'] as String? ?? '',
          'relatedWordsBisaya': [],
          'relatedWordsEnglish': [],
          'relatedWordsTagalog': [],
        };
      }
      
      _isLoaded = true;
      debugPrint('[Expert Dictionary] Loaded ${_expertDictionary.length} words');
    } catch (e) {
      debugPrint('[Expert Dictionary] Error initializing: $e');
    }
  }

  /// Look up a word in the expert dictionary
  Map<String, dynamic>? getWord(String word) {
    final wordLower = word.toLowerCase().trim();
    return _expertDictionary[wordLower];
  }

  /// Enhance word entry with API analysis for deep Bisaya meanings
  Future<Map<String, dynamic>?> getWordWithAPIEnhancement(String word) async {
    // First check local dictionary (CSV)
    var entry = getWord(word);
    
    if (entry != null) {
      // Word is in CSV - enhance with API for deeper meanings
      try {
        final enhancement = await _aiService.generateDictionaryEntry(
          word: entry['word'] as String? ?? word,
        );
        
        if (enhancement != null && enhancement.isNotEmpty) {
          // Merge API data with CSV data (API provides richer analysis)
          return {
            ...entry,
            'englishMeaning': enhancement['englishMeaning'] ?? entry['englishMeaning'],
            'tagalogMeaning': enhancement['tagalogMeaning'] ?? entry['tagalogMeaning'],
            'usageNote': enhancement['usageNote'],
            'synonyms': enhancement['synonyms'],
            'sampleSentenceBisaya': enhancement['sampleSentenceBisaya'] ?? entry['sampleSentenceBisaya'],
          };
        }
      } catch (e) {
        debugPrint('[Expert Dictionary] API enhancement error: $e');
        // Fall back to CSV data if API fails
        return entry;
      }
      return entry;
    }
    
    // Word not in CSV - try API for deep/poetic Bisaya words
    try {
      debugPrint('[Expert Dictionary] Word not in CSV, checking API for: "$word"');
      final apiResult = await _aiService.generateDictionaryEntry(word: word);
      
      if (apiResult != null && apiResult.isNotEmpty) {
        // Validate that API recognized it as valid Bisaya
        final validValue = apiResult['valid'];
        bool isValid = true;
        if (validValue is String) {
          isValid = validValue.toLowerCase() != 'false';
        }
        
        if (isValid) {
          debugPrint('[Expert Dictionary] API validated deep Bisaya word: "$word"');
          return apiResult;
        }
      }
    } catch (e) {
      debugPrint('[Expert Dictionary] API lookup error: $e');
    }
    
    return null;
  }

  /// Search for words by keyword in meanings
  List<Map<String, dynamic>> searchByMeaning(String query) {
    final queryLower = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    _expertDictionary.forEach((key, entry) {
      final english = (entry['englishMeaning'] as String? ?? '').toLowerCase();
      final tagalog = (entry['tagalogMeaning'] as String? ?? '').toLowerCase();

      if (english.contains(queryLower) || tagalog.contains(queryLower)) {
        results.add(entry);
      }
    });

    return results;
  }

  /// Get all expert dictionary words
  List<Map<String, dynamic>> getAllWords() {
    return _expertDictionary.values.toList();
  }

  /// Check if word exists in expert dictionary
  bool isValidWord(String word) {
    return _expertDictionary.containsKey(word.toLowerCase().trim());
  }

  /// Add a new word to expert dictionary
  void addWord(String word, Map<String, dynamic> entry) {
    _expertDictionary[word.toLowerCase().trim()] = entry;
  }

  /// Get dictionary size
  int getSize() {
    return _expertDictionary.length;
  }

  /// Check if initialized
  bool get isLoaded => _isLoaded;
}
