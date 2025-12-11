import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to load and manage Bisaya dataset from CSV
class DatasetService {
  static DatasetService? _instance;
  List<Map<String, dynamic>>? _dataset;
  bool _isLoaded = false;

  DatasetService._();

  void _safeDebug(String msg) {
    try {
      final sanitized = msg.replaceAll('\uFFFD', '');
      debugPrint(sanitized);
    } catch (e) {
      debugPrint('[sanitized debug message]');
    }
  }

  /// Get singleton instance
  static DatasetService get instance {
    _instance ??= DatasetService._();
    return _instance!;
  }

  /// Load dataset from CSV file
  /// [forceReload] if true, will reload even if already loaded
  Future<void> loadDataset({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      _safeDebug('✅ Dataset already loaded: ${_dataset?.length ?? 0} entries');
      return;
    }
    
    if (forceReload) {
      _safeDebug('🔄 Force reloading dataset...');
      _isLoaded = false;
      _dataset = null;
    }

    try {
      _safeDebug('🔄 Loading dataset from CSV...');
      // Load CSV from assets (Flutter can only load from assets folder)
      // When 'assets/' is specified in pubspec.yaml, files are accessed as 'assets/filename.csv'
      String csvString = '';
      
      // Try the correct path first
      try {
        // Try loading as UTF-8 first
        csvString = await rootBundle.loadString('assets/bisaya_dataset.csv');
        _safeDebug('✅ Found CSV at: assets/bisaya_dataset.csv');
      } catch (e) {
        _safeDebug('⚠️ Failed to load as UTF-8: $e');
        
        // Try loading as bytes and converting with different encodings
        try {
          final ByteData data = await rootBundle.load('assets/bisaya_dataset.csv');
          final Uint8List bytes = data.buffer.asUint8List();
          
          // Try different encodings
          final encodings = ['utf-8', 'latin-1', 'windows-1252'];
          bool loaded = false;
          
          for (final encodingName in encodings) {
            try {
              if (encodingName == 'utf-8') {
                csvString = utf8.decode(bytes, allowMalformed: true);
              } else if (encodingName == 'latin-1') {
                csvString = latin1.decode(bytes);
              } else if (encodingName == 'windows-1252') {
                // Windows-1252 is a superset of Latin-1, use Latin-1 as fallback
                csvString = latin1.decode(bytes);
              }
              _safeDebug('✅ Loaded CSV using $encodingName encoding');
              loaded = true;
              break;
            } catch (e) {
              _safeDebug('⚠️ Failed to decode with $encodingName: $e');
              continue;
            }
          }
          
          if (!loaded) {
            // Last resort: try UTF-8 with error replacement
            csvString = utf8.decode(bytes, allowMalformed: true);
              _safeDebug('⚠️ Using UTF-8 with malformed characters allowed');
          }
        } catch (e2) {
          _safeDebug('❌ Failed to load as bytes: $e2');
          // Try alternative path
          try {
            csvString = await rootBundle.loadString('bisaya_dataset.csv');
            _safeDebug('✅ Found CSV at: bisaya_dataset.csv');
          } catch (e3) {
            _safeDebug('❌ Failed to load from bisaya_dataset.csv: $e3');
            throw Exception('Could not find or decode bisaya_dataset.csv. Please ensure:\n1. File exists at assets/bisaya_dataset.csv\n2. File encoding is UTF-8 or Latin-1\n3. Run "flutter pub get"\n4. Do a full restart (not hot reload)');
          }
        }
      }
      
      if (csvString.isEmpty) {
        throw Exception('CSV file is empty or could not be loaded');
      }
      
      // Parse CSV manually
      _safeDebug('📄 Parsing CSV (${csvString.length} characters)...');
      final List<List<String>> csvData = _parseCsv(csvString);
      
      if (csvData.isEmpty) {
        throw Exception('Dataset CSV is empty');
      }
      
      _safeDebug('📊 Parsed ${csvData.length} rows from CSV');

      // Get headers (first row)
      final headers = csvData[0].map((e) => e.trim()).toList();
      _safeDebug('📋 Headers found: ${headers.join(", ")}');
      
      // Find column indices
      final bisayaIndex = headers.indexOf('Bisaya');
      final tagalogIndex = headers.indexOf('Tagalog');
      final englishIndex = headers.indexOf('English');
      final posIndex = headers.indexOf('Part of Speech');
      final pronunciationIndex = headers.indexOf('Pronunciation');
      final categoryIndex = headers.indexOf('Category');
      
      // New separate columns for examples
      final beginnerBisayaIndex = headers.indexOf('Beginner Example (Bisaya)');
      final beginnerEnglishIndex = headers.indexOf('Beginner English Translation');
      final beginnerTagalogIndex = headers.indexOf('Beginner Tagalog Translation');
      final intermediateBisayaIndex = headers.indexOf('Intermediate Example (Bisaya)');
      final intermediateEnglishIndex = headers.indexOf('Intermediate English Translation');
      final intermediateTagalogIndex = headers.indexOf('Intermediate Tagalog Translation');
      final advancedBisayaIndex = headers.indexOf('Advanced Example (Bisaya)');
      final advancedEnglishIndex = headers.indexOf('Advanced English Translation');
      final advancedTagalogIndex = headers.indexOf('Advanced Tagalog Translation');
      
      // Fallback to old format if new columns don't exist
      final beginnerExampleIndex = headers.indexOf('Beginner Example');
      final intermediateExampleIndex = headers.indexOf('Intermediate Example');
      final advancedExampleIndex = headers.indexOf('Advanced Example');

      if (bisayaIndex == -1 || englishIndex == -1) {
        throw Exception('Required columns (Bisaya, English) not found in dataset');
      }

      // Parse data rows
      _dataset = [];
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length < headers.length) continue;

        final entry = <String, dynamic>{
          'bisaya': bisayaIndex < row.length ? (row[bisayaIndex] as String? ?? '').trim() : '',
          'english': englishIndex != -1 && englishIndex < row.length 
              ? (row[englishIndex] as String? ?? '').trim() 
              : '',
          'tagalog': tagalogIndex != -1 && tagalogIndex < row.length 
              ? (row[tagalogIndex] as String? ?? '').trim() 
              : '',
          'partOfSpeech': posIndex != -1 && posIndex < row.length 
              ? (row[posIndex] as String? ?? '').trim() 
              : 'Unknown',
          'pronunciation': pronunciationIndex != -1 && pronunciationIndex < row.length 
              ? (row[pronunciationIndex] as String? ?? '').trim() 
              : '',
          'category': categoryIndex != -1 && categoryIndex < row.length 
              ? (row[categoryIndex] as String? ?? '').trim() 
              : 'Uncategorized',
          
          // New format: separate columns for each translation
          'beginnerExample': beginnerBisayaIndex != -1 && beginnerBisayaIndex < row.length 
              ? (row[beginnerBisayaIndex] as String? ?? '').trim() 
              : '',
          'beginnerEnglish': beginnerEnglishIndex != -1 && beginnerEnglishIndex < row.length 
              ? (row[beginnerEnglishIndex] as String? ?? '').trim() 
              : '',
          'beginnerTagalog': beginnerTagalogIndex != -1 && beginnerTagalogIndex < row.length 
              ? (row[beginnerTagalogIndex] as String? ?? '').trim() 
              : '',
          'intermediateExample': intermediateBisayaIndex != -1 && intermediateBisayaIndex < row.length 
              ? (row[intermediateBisayaIndex] as String? ?? '').trim() 
              : '',
          'intermediateEnglish': intermediateEnglishIndex != -1 && intermediateEnglishIndex < row.length 
              ? (row[intermediateEnglishIndex] as String? ?? '').trim() 
              : '',
          'intermediateTagalog': intermediateTagalogIndex != -1 && intermediateTagalogIndex < row.length 
              ? (row[intermediateTagalogIndex] as String? ?? '').trim() 
              : '',
          'advancedExample': advancedBisayaIndex != -1 && advancedBisayaIndex < row.length 
              ? (row[advancedBisayaIndex] as String? ?? '').trim() 
              : '',
          'advancedEnglish': advancedEnglishIndex != -1 && advancedEnglishIndex < row.length 
              ? (row[advancedEnglishIndex] as String? ?? '').trim() 
              : '',
          'advancedTagalog': advancedTagalogIndex != -1 && advancedTagalogIndex < row.length 
              ? (row[advancedTagalogIndex] as String? ?? '').trim() 
              : '',
        };
        
        // Fallback: parse old format if new columns don't exist
        if (beginnerBisayaIndex == -1 && beginnerExampleIndex != -1) {
          final oldExample = beginnerExampleIndex < row.length 
              ? (row[beginnerExampleIndex] as String? ?? '').trim() 
              : '';
          if (oldExample.isNotEmpty) {
            // Parse old format: "Bisaya -> "English" | "Tagalog""
            final parts = oldExample.split('->');
            if (parts.length == 2) {
              entry['beginnerExample'] = parts[0].trim();
              final translations = parts[1].split('|');
              if (translations.isNotEmpty) {
                entry['beginnerEnglish'] = translations[0].replaceAll('"', '').trim();
              }
              if (translations.length >= 2) {
                entry['beginnerTagalog'] = translations[1].replaceAll('"', '').trim();
              }
            }
          }
        }
        
        if (intermediateBisayaIndex == -1 && intermediateExampleIndex != -1) {
          final oldExample = intermediateExampleIndex < row.length 
              ? (row[intermediateExampleIndex] as String? ?? '').trim() 
              : '';
          if (oldExample.isNotEmpty) {
            final parts = oldExample.split('->');
            if (parts.length == 2) {
              entry['intermediateExample'] = parts[0].trim();
              final translations = parts[1].split('|');
              if (translations.isNotEmpty) {
                entry['intermediateEnglish'] = translations[0].replaceAll('"', '').trim();
              }
              if (translations.length >= 2) {
                entry['intermediateTagalog'] = translations[1].replaceAll('"', '').trim();
              }
            }
          }
        }
        
        if (advancedBisayaIndex == -1 && advancedExampleIndex != -1) {
          final oldExample = advancedExampleIndex < row.length 
              ? (row[advancedExampleIndex] as String? ?? '').trim() 
              : '';
          if (oldExample.isNotEmpty) {
            final parts = oldExample.split('->');
            if (parts.length == 2) {
              entry['advancedExample'] = parts[0].trim();
              final translations = parts[1].split('|');
              if (translations.isNotEmpty) {
                entry['advancedEnglish'] = translations[0].replaceAll('"', '').trim();
              }
              if (translations.length >= 2) {
                entry['advancedTagalog'] = translations[1].replaceAll('"', '').trim();
              }
            }
          }
        }

        // Only add if has at least Bisaya word
        final bisaya = entry['bisaya'] as String? ?? '';
        if (bisaya.trim().isNotEmpty) {
          _dataset!.add(entry);
        } else {
          _safeDebug('⚠️ Skipping row ${i + 1}: no Bisaya word');
        }
      }

      _isLoaded = true;
      _safeDebug('✅ Dataset loaded: ${_dataset!.length} valid entries out of ${csvData.length - 1} total rows');
      if (_dataset!.isEmpty) {
        _safeDebug('❌ WARNING: Dataset is empty after parsing! Check CSV format.');
      } else {
        // Show sample entry
        final sample = _dataset!.first;
        _safeDebug('📝 Sample entry: Bisaya="${sample['bisaya']}", English="${sample['english']}"');
      }
    } catch (e) {
      _safeDebug('❌ Error loading dataset: $e');
      throw Exception('Failed to load dataset: $e');
    }
  }

  /// Check if dataset is loaded
  bool get isLoaded => _isLoaded;

  /// Get all entries
  List<Map<String, dynamic>> getAllEntries() {
    _ensureLoaded();
    return List.from(_dataset!);
  }

  /// Get word metadata by Bisaya word
  Map<String, dynamic>? getWordMetadata(String word) {
    _ensureLoaded();
    final originalWord = word.trim();
    final wordLower = originalWord.toLowerCase();

    // First: Try exact match (for compound words and multi-word entries)
    for (final entry in _dataset!) {
      final bisaya = (entry['bisaya'] as String? ?? '').toLowerCase().trim();
      if (bisaya == wordLower) {
        _safeDebug('✅ [Expert] Found exact match: "$originalWord" -> "${entry['bisaya']}"');
        return {
          'input': originalWord,
          'normalized': wordLower,
          'matched': entry['bisaya'],
          'metadata': entry,
          'isStrictMatch': true,
        };
      }
    }

    // Second: Try with affix normalization (for conjugated verbs)
    String normalized = wordLower;
    final prefixes = ['mo', 'mag', 'nag', 'gi', 'ka', 'maka', 'makaka', 'mi', 'kami', 'ta'];
    final suffixes = ['ay', 'a', 'ang', 'nin', 'ing'];
    
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix) && normalized.length > prefix.length + 2) {
        normalized = normalized.substring(prefix.length);
        break;
      }
    }
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix) && normalized.length > suffix.length + 2) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    normalized = normalized.trim();

    // Check if normalized form matches
    if (normalized != wordLower) {
      for (final entry in _dataset!) {
        final bisaya = (entry['bisaya'] as String? ?? '').toLowerCase().trim();
        if (bisaya == normalized) {
          _safeDebug('✅ [Expert] Found match with affix correction: "$originalWord" -> "${entry['bisaya']}"');
          return {
            'input': originalWord,
            'normalized': normalized,
            'matched': entry['bisaya'],
            'metadata': entry,
            'isStrictMatch': true,
          };
        }
      }
    }

    // Third: Try partial match for multi-word phrases (e.g., "maayong buntag")
    for (final entry in _dataset!) {
      final bisaya = (entry['bisaya'] as String? ?? '').toLowerCase().trim();
      if (bisaya.contains(wordLower) || wordLower.contains(bisaya)) {
        if (bisaya.length > 2 && wordLower.length > 2) {
          _safeDebug('✅ [Expert] Found partial match: "$originalWord" -> "${entry['bisaya']}"');
          return {
            'input': originalWord,
            'normalized': wordLower,
            'matched': entry['bisaya'],
            'metadata': entry,
            'isStrictMatch': true,
          };
        }
      }
    }

    _safeDebug('❌ [Expert] No Bisaya match for "$originalWord"');
    return {
      'input': originalWord,
      'normalized': normalized,
      'matched': null,
      'metadata': null,
      'isStrictMatch': false,
    };
  }

  /// Search for words in any language
  List<Map<String, dynamic>> searchWord(String query, {int limit = 10}) {
    _ensureLoaded();
    final queryLower = query.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];

    for (final entry in _dataset!) {
      final bisaya = (entry['bisaya'] as String? ?? '').toLowerCase();
      final english = (entry['english'] as String? ?? '').toLowerCase();
      final tagalog = (entry['tagalog'] as String? ?? '').toLowerCase();

      if (bisaya.contains(queryLower) || 
          english.contains(queryLower) || 
          tagalog.contains(queryLower)) {
        results.add(entry);
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  /// Get random words
  List<String> getRandomWords({int count = 10}) {
    _ensureLoaded();
    if (_dataset!.isEmpty) {
      _safeDebug('⚠️ getRandomWords: Dataset is empty!');
      return [];
    }

    _safeDebug('🔄 Getting $count random words from ${_dataset!.length} entries...');
    final words = <String>[];
    final random = List.from(_dataset!);
    random.shuffle();

    for (int i = 0; i < count && i < random.length; i++) {
      final bisaya = random[i]['bisaya'] as String? ?? '';
      if (bisaya.isNotEmpty) {
        words.add(bisaya);
      }
    }

    _safeDebug('✅ getRandomWords: Returning ${words.length} words: ${words.take(5).join(", ")}${words.length > 5 ? "..." : ""}');
    return words;
  }

  /// Get words by part of speech
  List<Map<String, dynamic>> getWordsByPartOfSpeech(String partOfSpeech) {
    _ensureLoaded();
    final posLower = partOfSpeech.toLowerCase();
    
    return _dataset!.where((entry) {
      final pos = (entry['partOfSpeech'] as String? ?? '').toLowerCase();
      return pos.contains(posLower);
    }).toList();
  }

  /// Get all unique parts of speech
  List<String> getAllPartsOfSpeech() {
    _ensureLoaded();
    final posSet = <String>{};
    
    for (final entry in _dataset!) {
      final pos = entry['partOfSpeech'] as String? ?? 'Unknown';
      if (pos.isNotEmpty) {
        posSet.add(pos);
      }
    }
    
    return posSet.toList()..sort();
  }

  void _ensureLoaded() {
    if (!_isLoaded || _dataset == null) {
      throw Exception('Dataset not loaded. Call loadDataset() first.');
    }
  }

  /// Parse CSV string into list of rows
  List<List<String>> _parseCsv(String csvString) {
    final List<List<String>> rows = [];
    final List<String> currentRow = [];
    String currentField = '';
    bool inQuotes = false;

    for (int i = 0; i < csvString.length; i++) {
      final char = csvString[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentField.trim());
        currentField = '';
      } else if (char == '\n' && !inQuotes) {
        currentRow.add(currentField.trim());
        currentField = '';
        if (currentRow.isNotEmpty && currentRow.any((field) => field.isNotEmpty)) {
          rows.add(List.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentField += char;
      }
    }

    // Add last field and row
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.trim());
      if (currentRow.isNotEmpty && currentRow.any((field) => field.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }
}

