import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocaboost/services/dataset_service.dart';
import 'package:vocaboost/services/learning_path_service.dart';

/// Service for managing offline content
/// Downloads and caches lessons for offline learning
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _downloadedContentKey = 'offline_downloaded_content';
  static const String _downloadedPathsKey = 'offline_downloaded_paths';
  static const String _lastSyncKey = 'offline_last_sync';
  static const String _offlineModeKey = 'offline_mode_enabled';

  final DatasetService _datasetService = DatasetService.instance;
  final LearningPathService _pathService = LearningPathService();

  /// Check if offline mode is enabled
  Future<bool> isOfflineModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineModeKey) ?? false;
  }

  /// Enable or disable offline mode
  Future<void> setOfflineModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, enabled);
  }

  /// Get list of downloaded content
  Future<Map<String, dynamic>> getDownloadedContent() async {
    final prefs = await SharedPreferences.getInstance();
    final contentJson = prefs.getString(_downloadedContentKey);
    
    if (contentJson == null) {
      return {
        'words': <String>[],
        'paths': <String>[],
        'totalWords': 0,
        'downloadedAt': null,
      };
    }
    
    try {
      return jsonDecode(contentJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error parsing downloaded content: $e');
      return {
        'words': <String>[],
        'paths': <String>[],
        'totalWords': 0,
        'downloadedAt': null,
      };
    }
  }

  /// Download all vocabulary for offline use
  Future<Map<String, dynamic>> downloadAllVocabulary() async {
    try {
      await _datasetService.loadDataset();
      final allEntries = _datasetService.getAllEntries();
      
      // Store words in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      final wordsData = allEntries.map((entry) => {
        'bisaya': entry['bisaya'] ?? '',
        'english': entry['english'] ?? '',
        'tagalog': entry['tagalog'] ?? '',
        'pronunciation': entry['pronunciation'] ?? '',
        'category': entry['category'] ?? '',
        'partOfSpeech': entry['partOfSpeech'] ?? '',
      }).toList();
      
      await prefs.setString('offline_vocabulary', jsonEncode(wordsData));
      
      // Update downloaded content metadata
      final content = await getDownloadedContent();
      content['words'] = wordsData.map((w) => w['bisaya'] as String).toList();
      content['totalWords'] = wordsData.length;
      content['downloadedAt'] = DateTime.now().toIso8601String();
      
      await prefs.setString(_downloadedContentKey, jsonEncode(content));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      return {
        'success': true,
        'message': 'Downloaded ${wordsData.length} words',
        'count': wordsData.length,
      };
    } catch (e) {
      debugPrint('Error downloading vocabulary: $e');
      return {
        'success': false,
        'message': 'Failed to download vocabulary: $e',
      };
    }
  }

  /// Download a specific learning path for offline use
  Future<Map<String, dynamic>> downloadLearningPath(String pathId) async {
    try {
      final path = _pathService.getPathById(pathId);
      if (path == null) {
        return {'success': false, 'message': 'Path not found'};
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get all words from path lessons
      final lessons = path['lessons'] as List<dynamic>;
      List<String> allWords = [];
      
      for (final lesson in lessons) {
        final words = List<String>.from(lesson['words'] ?? []);
        allWords.addAll(words);
      }
      
      // Get word details from dataset
      await _datasetService.loadDataset();
      final wordDetails = <Map<String, dynamic>>[];
      
      for (final word in allWords) {
        final metadata = _datasetService.getWordMetadata(word);
        if (metadata != null && metadata['metadata'] != null) {
          final entry = metadata['metadata'] as Map<String, dynamic>;
          wordDetails.add({
            'bisaya': entry['bisaya'] ?? word,
            'english': entry['english'] ?? '',
            'tagalog': entry['tagalog'] ?? '',
            'pronunciation': entry['pronunciation'] ?? '',
          });
        } else {
          wordDetails.add({
            'bisaya': word,
            'english': '',
            'tagalog': '',
            'pronunciation': '',
          });
        }
      }
      
      // Store path data
      final pathData = {
        'id': pathId,
        'name': path['name'],
        'icon': path['icon'],
        'lessons': lessons,
        'words': wordDetails,
        'downloadedAt': DateTime.now().toIso8601String(),
      };
      
      // Get existing downloaded paths
      final pathsJson = prefs.getString(_downloadedPathsKey);
      Map<String, dynamic> downloadedPaths = {};
      if (pathsJson != null) {
        downloadedPaths = jsonDecode(pathsJson) as Map<String, dynamic>;
      }
      
      downloadedPaths[pathId] = pathData;
      await prefs.setString(_downloadedPathsKey, jsonEncode(downloadedPaths));
      
      // Update content metadata
      final content = await getDownloadedContent();
      final paths = List<String>.from(content['paths'] ?? []);
      if (!paths.contains(pathId)) {
        paths.add(pathId);
      }
      content['paths'] = paths;
      await prefs.setString(_downloadedContentKey, jsonEncode(content));
      
      return {
        'success': true,
        'message': 'Downloaded "${path['name']}" (${wordDetails.length} words)',
        'pathId': pathId,
        'wordCount': wordDetails.length,
      };
    } catch (e) {
      debugPrint('Error downloading learning path: $e');
      return {
        'success': false,
        'message': 'Failed to download path: $e',
      };
    }
  }

  /// Get downloaded learning path
  Future<Map<String, dynamic>?> getDownloadedPath(String pathId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pathsJson = prefs.getString(_downloadedPathsKey);
      
      if (pathsJson == null) return null;
      
      final downloadedPaths = jsonDecode(pathsJson) as Map<String, dynamic>;
      return downloadedPaths[pathId] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting downloaded path: $e');
      return null;
    }
  }

  /// Get all downloaded paths
  Future<List<Map<String, dynamic>>> getAllDownloadedPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pathsJson = prefs.getString(_downloadedPathsKey);
      
      if (pathsJson == null) return [];
      
      final downloadedPaths = jsonDecode(pathsJson) as Map<String, dynamic>;
      return downloadedPaths.values.map((v) => v as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting all downloaded paths: $e');
      return [];
    }
  }

  /// Get offline vocabulary
  Future<List<Map<String, dynamic>>> getOfflineVocabulary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vocabJson = prefs.getString('offline_vocabulary');
      
      if (vocabJson == null) return [];
      
      final vocabList = jsonDecode(vocabJson) as List<dynamic>;
      return vocabList.map((v) => v as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting offline vocabulary: $e');
      return [];
    }
  }

  /// Delete downloaded path
  Future<bool> deleteDownloadedPath(String pathId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pathsJson = prefs.getString(_downloadedPathsKey);
      
      if (pathsJson == null) return false;
      
      final downloadedPaths = jsonDecode(pathsJson) as Map<String, dynamic>;
      downloadedPaths.remove(pathId);
      
      await prefs.setString(_downloadedPathsKey, jsonEncode(downloadedPaths));
      
      // Update content metadata
      final content = await getDownloadedContent();
      final paths = List<String>.from(content['paths'] ?? []);
      paths.remove(pathId);
      content['paths'] = paths;
      await prefs.setString(_downloadedContentKey, jsonEncode(content));
      
      return true;
    } catch (e) {
      debugPrint('Error deleting downloaded path: $e');
      return false;
    }
  }

  /// Delete all offline content
  Future<bool> deleteAllOfflineContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_downloadedContentKey);
      await prefs.remove(_downloadedPathsKey);
      await prefs.remove('offline_vocabulary');
      await prefs.remove(_lastSyncKey);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting offline content: $e');
      return false;
    }
  }

  /// Get storage usage in bytes (approximate)
  Future<int> getStorageUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int totalSize = 0;
      
      final vocabJson = prefs.getString('offline_vocabulary');
      if (vocabJson != null) {
        totalSize += vocabJson.length;
      }
      
      final pathsJson = prefs.getString(_downloadedPathsKey);
      if (pathsJson != null) {
        totalSize += pathsJson.length;
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Format storage size for display
  String formatStorageSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    
    if (lastSyncStr == null) return null;
    
    try {
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if content is downloaded
  Future<bool> isPathDownloaded(String pathId) async {
    final content = await getDownloadedContent();
    final paths = List<String>.from(content['paths'] ?? []);
    return paths.contains(pathId);
  }

  /// Check if vocabulary is downloaded
  Future<bool> isVocabularyDownloaded() async {
    final content = await getDownloadedContent();
    return (content['totalWords'] as int? ?? 0) > 0;
  }
}
