import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' 
    if (dart.library.html) 'package:vocaboost/services/tflite_stub.dart'
    show Interpreter, InterpreterOptions;

/// NLP Model Service for offline Bisaya language processing
/// Loads trained TensorFlow Lite model from assets and provides NLP capabilities
class NLPModelService {
  static NLPModelService? _instance;
  Interpreter? _interpreter;
  Map<String, int>? _wordToIndex;
  Map<int, String>? _indexToWord;
  List<Map<String, dynamic>>? _metadata;
  Map<String, Map<String, double>>? _similarity;
  bool _isLoaded = false;
  bool _similarityLoaded = false;

  NLPModelService._();

  /// Get singleton instance
  static NLPModelService get instance {
    _instance ??= NLPModelService._();
    return _instance!;
  }

  /// Load the trained TensorFlow Lite model from assets
  Future<void> loadModel() async {
    if (_isLoaded) return;

    try {
      // Load TensorFlow Lite model (skip on web - not supported)
      if (!kIsWeb) {
        try {
          final interpreterOptions = InterpreterOptions();
          _interpreter = await Interpreter.fromAsset(
            'assets/models/bisaya_model.tflite',
            options: interpreterOptions,
          );
          
          debugPrint('✅ TensorFlow Lite model loaded');
        } catch (e) {
          debugPrint('⚠️ TensorFlow Lite model not found, continuing with metadata only: $e');
          // Continue without TFLite model - we can still use metadata
        }
      } else {
        debugPrint('⚠️ TensorFlow Lite not supported on web, using metadata only');
      }

      // Load metadata JSON
      try {
        final String metadataString = await rootBundle.loadString('assets/models/bisaya_metadata.json');
        final Map<String, dynamic> metadataData = jsonDecode(metadataString);

        // Load word mappings
        _wordToIndex = Map<String, int>.from(metadataData['word_to_index'] as Map<String, dynamic>);
        final indexToWordData = metadataData['index_to_word'] as Map<String, dynamic>;
        _indexToWord = {};
        indexToWordData.forEach((key, value) {
          _indexToWord![int.parse(key)] = value as String;
        });

        // Load metadata
        _metadata = List<Map<String, dynamic>>.from(metadataData['metadata'] as List);
      } catch (e) {
        debugPrint('❌ Error loading metadata: $e');
        throw Exception('Failed to load metadata. Please ensure bisaya_metadata.json is in assets/models/');
      }

      // Don't load similarity matrix here - lazy load it when needed
      // This significantly reduces initial load time
      _similarity = {};
      _similarityLoaded = false;

      _isLoaded = true;
      debugPrint('✅ NLP Model fully loaded: ${_wordToIndex!.length} words');
    } catch (e) {
      debugPrint('❌ Error loading NLP model: $e');
      throw Exception('Failed to load NLP model: $e');
    }
  }

  /// Check if model is loaded
  bool get isLoaded => _isLoaded;

  /// Get embedding for a word using TensorFlow Lite model
  List<double>? getEmbedding(String word) {
    _ensureLoaded();
    final wordLower = word.toLowerCase();
    
    if (!_wordToIndex!.containsKey(wordLower)) {
      return null;
    }
    
    // If TFLite model is not available, return null
    if (_interpreter == null) {
      return null;
    }
    
    try {
      final wordIndex = _wordToIndex![wordLower]!;
      // Input: single integer index [wordIndex]
      final input = [wordIndex];
      // Output: 100-dimensional embedding vector
      final output = List.filled(100, 0.0);
      
      _interpreter!.run(input, output);
      
      return List<double>.from(output);
    } catch (e) {
      debugPrint('Error getting embedding: $e');
      return null;
    }
  }

  /// Get all words in the model
  List<String> getAllWords() {
    _ensureLoaded();
    return _wordToIndex!.keys.toList();
  }

  /// Get word metadata (translations, pronunciation, POS)
  Map<String, dynamic>? getWordMetadata(String word) {
    _ensureLoaded();
    final wordLower = word.toLowerCase();
    
    if (!_wordToIndex!.containsKey(wordLower)) {
      return null;
    }
    
    final index = _wordToIndex![wordLower]!;
    if (index < _metadata!.length) {
      return _metadata![index];
    }
    
    return null;
  }

  /// Search for a word in any language (English, Bisaya, Tagalog)
  List<Map<String, dynamic>> searchWord(String query, {int limit = 10}) {
    _ensureLoaded();
    final queryLower = query.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < _metadata!.length; i++) {
      final meta = _metadata![i];
      final bisaya = (meta['bisaya'] as String? ?? '').toLowerCase();
      final tagalog = (meta['tagalog'] as String? ?? '').toLowerCase();
      final english = (meta['english'] as String? ?? '').toLowerCase();
      final word = _indexToWord![i] ?? '';

      if (bisaya.contains(queryLower) ||
          tagalog.contains(queryLower) ||
          english.contains(queryLower) ||
          word.contains(queryLower)) {
        results.add({
          'word': word,
          'metadata': meta,
          'index': i,
        });
      }
    }

    // Sort by relevance
    results.sort((a, b) {
      final aWord = a['word'] as String;
      final bWord = b['word'] as String;
      final aExact = aWord == queryLower;
      final bExact = bWord == queryLower;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return 0;
    });

    return results.take(limit).toList();
  }

  /// Get translation between languages
  String? getTranslation(String word, String fromLang, String toLang) {
    _ensureLoaded();
    final wordLower = word.toLowerCase().trim();
    
    Map<String, dynamic>? metadata;
    
    // Search by Bisaya word (primary key)
    if (_wordToIndex!.containsKey(wordLower)) {
      final index = _wordToIndex![wordLower]!;
      if (index < _metadata!.length) {
        metadata = _metadata![index];
      }
    } else {
      // Search in all languages
      for (final meta in _metadata!) {
        final bisaya = (meta['bisaya'] as String? ?? '').toLowerCase();
        final tagalog = (meta['tagalog'] as String? ?? '').toLowerCase();
        final english = (meta['english'] as String? ?? '').toLowerCase();
        
        if ((fromLang == 'Bisaya' && bisaya == wordLower) ||
            (fromLang == 'Tagalog' && tagalog == wordLower) ||
            (fromLang == 'English' && english.contains(wordLower))) {
          metadata = meta;
          break;
        }
      }
    }
    
    if (metadata == null) return null;
    
    switch (toLang) {
      case 'Bisaya':
        return metadata['bisaya'] as String?;
      case 'Tagalog':
        return metadata['tagalog'] as String?;
      case 'English':
        return metadata['english'] as String?;
      default:
        return null;
    }
  }

  /// Lazy load similarity matrix when needed
  Future<void> _loadSimilarityIfNeeded() async {
    if (_similarityLoaded) return;
    
    try {
      final String similarityString = await rootBundle.loadString('assets/models/bisaya_similarity.json');
      final Map<String, dynamic> similarityData = jsonDecode(similarityString);
      _similarity = {};
      similarityData.forEach((key, value) {
        _similarity![key] = Map<String, double>.from(value as Map<String, dynamic>);
      });
      _similarityLoaded = true;
      debugPrint('✅ Similarity matrix loaded');
    } catch (e) {
      debugPrint('⚠️ Similarity matrix not found, will calculate on-the-fly: $e');
      _similarity = {};
      _similarityLoaded = true; // Mark as loaded even if failed to prevent retries
    }
  }

  /// Get similar words (for quiz distractors) using embeddings
  Future<List<String>> getSimilarWords(String word, {int count = 3, double minSimilarity = 0.3}) async {
    _ensureLoaded();
    final wordLower = word.toLowerCase();
    
    // Lazy load similarity matrix if not loaded
    await _loadSimilarityIfNeeded();
    
    // Check pre-computed similarity first
    if (_similarity!.containsKey(wordLower)) {
      final similar = _similarity![wordLower]!;
      final similarWords = similar.entries
          .where((e) => e.value >= minSimilarity)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return similarWords.take(count).map((e) => e.key).toList();
    }
    
    // Calculate on-the-fly using embeddings
    final wordEmbedding = getEmbedding(wordLower);
    if (wordEmbedding == null) return [];
    
    final similarities = <MapEntry<String, double>>[];
    
    for (final otherWord in _wordToIndex!.keys) {
      if (otherWord == wordLower) continue;
      
      final otherEmbedding = getEmbedding(otherWord);
      if (otherEmbedding != null) {
        final similarity = _cosineSimilarity(wordEmbedding, otherEmbedding);
        if (similarity >= minSimilarity) {
          similarities.add(MapEntry(otherWord, similarity));
        }
      }
    }
    
    similarities.sort((a, b) => b.value.compareTo(a.value));
    return similarities.take(count).map((e) => e.key).toList();
  }

  /// Calculate cosine similarity between two words using TFLite model
  Future<double> calculateSimilarity(String word1, String word2) async {
    _ensureLoaded();
    final w1 = word1.toLowerCase();
    final w2 = word2.toLowerCase();
    
    // Lazy load similarity matrix if not loaded
    await _loadSimilarityIfNeeded();
    
    // Check pre-computed similarity first
    if (_similarity!.containsKey(w1) && _similarity![w1]!.containsKey(w2)) {
      return _similarity![w1]![w2]!;
    }
    
    // Calculate using embeddings
    final emb1 = getEmbedding(w1);
    final emb2 = getEmbedding(w2);
    
    if (emb1 == null || emb2 == null) return 0.0;
    
    return _cosineSimilarity(emb1, emb2);
  }

  /// Get random words from dataset
  List<String> getRandomWords({int count = 10, String? partOfSpeech}) {
    _ensureLoaded();
    final words = _wordToIndex!.keys.toList();
    
    // Filter by part of speech if specified
    List<String> filteredWords = words;
    if (partOfSpeech != null) {
      filteredWords = [];
      for (final word in words) {
        final index = _wordToIndex![word]!;
        if (index < _metadata!.length) {
          final meta = _metadata![index];
          final pos = (meta['pos'] as String? ?? '').toLowerCase();
          if (pos == partOfSpeech.toLowerCase()) {
            filteredWords.add(word);
          }
        }
      }
    }
    
    filteredWords.shuffle(Random());
    return filteredWords.take(count).toList();
  }

  /// Get words by part of speech
  List<String> getWordsByPartOfSpeech(String partOfSpeech) {
    _ensureLoaded();
    final result = <String>[];
    
    for (final word in _wordToIndex!.keys) {
      final index = _wordToIndex![word]!;
      if (index < _metadata!.length) {
        final meta = _metadata![index];
        final pos = (meta['pos'] as String? ?? '').toLowerCase();
        if (pos == partOfSpeech.toLowerCase()) {
          result.add(word);
        }
      }
    }
    
    return result;
  }

  /// Find best matching word for voice input (pronunciation matching)
  Future<Map<String, dynamic>?> matchPronunciation(String spokenText, {double minSimilarity = 0.5}) async {
    _ensureLoaded();
    final spokenLower = spokenText.toLowerCase().trim();
    
    // First, try exact match
    if (_wordToIndex!.containsKey(spokenLower)) {
      final index = _wordToIndex![spokenLower]!;
      return {
        'word': spokenLower,
        'metadata': index < _metadata!.length ? _metadata![index] : null,
        'similarity': 1.0,
        'matchType': 'exact',
      };
    }
    
    // Try similarity matching using embeddings
    final spokenEmbedding = getEmbedding(spokenLower);
    if (spokenEmbedding == null) {
      // If word not in vocab, try to find closest match
      double bestSimilarity = 0.0;
      String? bestMatch;
      
      for (final word in _wordToIndex!.keys) {
        final similarity = await calculateSimilarity(spokenLower, word);
        if (similarity > bestSimilarity && similarity >= minSimilarity) {
          bestSimilarity = similarity;
          bestMatch = word;
        }
      }
      
      if (bestMatch != null) {
        final index = _wordToIndex![bestMatch]!;
        return {
          'word': bestMatch,
          'metadata': index < _metadata!.length ? _metadata![index] : null,
          'similarity': bestSimilarity,
          'matchType': 'similarity',
        };
      }
    } else {
      // Calculate similarity with all words
      double bestSimilarity = 0.0;
      String? bestMatch;
      
      for (final word in _wordToIndex!.keys) {
        final wordEmbedding = getEmbedding(word);
        if (wordEmbedding != null) {
          final similarity = _cosineSimilarity(spokenEmbedding, wordEmbedding);
          if (similarity > bestSimilarity && similarity >= minSimilarity) {
            bestSimilarity = similarity;
            bestMatch = word;
          }
        }
      }
      
      if (bestMatch != null) {
        final index = _wordToIndex![bestMatch]!;
        return {
          'word': bestMatch,
          'metadata': index < _metadata!.length ? _metadata![index] : null,
          'similarity': bestSimilarity,
          'matchType': 'embedding',
        };
      }
    }
    
    return null;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) return 0.0;
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Ensure model is loaded
  void _ensureLoaded() {
    if (!_isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
