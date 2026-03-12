import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking and managing user analytics
class AnalyticsService {
  static AnalyticsService? _instance;
  
  // Keys for storing analytics
  static const String _totalListeningTimeKey = 'total_listening_time';
  static const String _listeningStreakKey = 'listening_streak';
  static const String _lastListeningDateKey = 'last_listening_date';
  static const String _channelsListenedKey = 'channels_listened';
  static const String _genresListenedKey = 'genres_listened';
  static const String _recentHistoryKey = 'recent_history';

  AnalyticsService._();

  static AnalyticsService get instance {
    _instance ??= AnalyticsService._();
    return _instance!;
  }

  /// Record listening session
  Future<void> recordListeningSession({
    required String channelId,
    required String channelName,
    required String genre,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update total listening time
    final currentTime = prefs.getInt(_totalListeningTimeKey) ?? 0;
    await prefs.setInt(_totalListeningTimeKey, currentTime + duration.inSeconds);
    
    // Update listening streak
    await _updateStreak(prefs);
    
    // Update channels listened
    await _updateChannelsListened(prefs, channelId, channelName);
    
    // Update genres listened
    await _updateGenresListened(prefs, genre);
    
    // Update recent history
    await _updateRecentHistory(prefs, channelId, channelName, genre);
  }

  Future<void> _updateStreak(SharedPreferences prefs) async {
    final lastDateStr = prefs.getString(_lastListeningDateKey);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    
    if (lastDateStr == null) {
      // First time listening
      await prefs.setInt(_listeningStreakKey, 1);
      await prefs.setString(_lastListeningDateKey, todayStr);
    } else if (lastDateStr == todayStr) {
      // Already listened today, no change
      return;
    } else {
      // Check if yesterday
      final lastDate = DateTime.parse(lastDateStr);
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      
      if (lastDateStr == yesterdayStr) {
        // Continue streak
        final streak = (prefs.getInt(_listeningStreakKey) ?? 0) + 1;
        await prefs.setInt(_listeningStreakKey, streak);
      } else {
        // Reset streak
        await prefs.setInt(_listeningStreakKey, 1);
      }
      await prefs.setString(_lastListeningDateKey, todayStr);
    }
  }

  Future<void> _updateChannelsListened(
    SharedPreferences prefs,
    String channelId,
    String channelName,
  ) async {
    final channelsJson = prefs.getString(_channelsListenedKey);
    Map<String, int> channels = {};
    
    if (channelsJson != null) {
      // Parse JSON-like string (simple implementation)
      final parts = channelsJson.split(';');
      for (final part in parts) {
        if (part.isNotEmpty) {
          final channelParts = part.split(':');
          if (channelParts.length == 2) {
            channels[channelParts[0]] = int.tryParse(channelParts[1]) ?? 0;
          }
        }
      }
    }
    
    channels[channelId] = (channels[channelId] ?? 0) + 1;
    
    // Save back
    final newJson = channels.entries.map((e) => '${e.key}:${e.value}').join(';');
    await prefs.setString(_channelsListenedKey, newJson);
  }

  Future<void> _updateGenresListened(SharedPreferences prefs, String genre) async {
    final genresJson = prefs.getString(_genresListenedKey);
    Map<String, int> genres = {};
    
    if (genresJson != null) {
      final parts = genresJson.split(';');
      for (final part in parts) {
        if (part.isNotEmpty) {
          final genreParts = part.split(':');
          if (genreParts.length == 2) {
            genres[genreParts[0]] = int.tryParse(genreParts[1]) ?? 0;
          }
        }
      }
    }
    
    genres[genre] = (genres[genre] ?? 0) + 1;
    
    final newJson = genres.entries.map((e) => '${e.key}:${e.value}').join(';');
    await prefs.setString(_genresListenedKey, newJson);
  }

  Future<void> _updateRecentHistory(
    SharedPreferences prefs,
    String channelId,
    String channelName,
    String genre,
  ) async {
    final historyJson = prefs.getString(_recentHistoryKey);
    List<Map<String, String>> history = [];
    
    if (historyJson != null && historyJson.isNotEmpty) {
      final parts = historyJson.split('|');
      for (final part in parts) {
        if (part.isNotEmpty) {
          final itemParts = part.split(';');
          if (itemParts.length == 3) {
            history.add({
              'channelId': itemParts[0],
              'channelName': itemParts[1],
              'genre': itemParts[2],
            });
          }
        }
      }
    }
    
    // Add new entry at the beginning
    history.insert(0, {
      'channelId': channelId,
      'channelName': channelName,
      'genre': genre,
    });
    
    // Keep only last 20 entries
    if (history.length > 20) {
      history = history.sublist(0, 20);
    }
    
    // Save back
    final newJson = history.map((e) => '${e['channelId']};${e['channelName']};${e['genre']}').join('|');
    await prefs.setString(_recentHistoryKey, newJson);
  }

  /// Get total listening time in seconds
  Future<int> getTotalListeningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalListeningTimeKey) ?? 0;
  }

  /// Get listening streak in days
  Future<int> getListeningStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_listeningStreakKey) ?? 0;
  }

  /// Get most listened channels
  Future<List<Map<String, dynamic>>> getMostListenedChannels({int limit = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final channelsJson = prefs.getString(_channelsListenedKey);
    
    if (channelsJson == null || channelsJson.isEmpty) {
      return [];
    }
    
    List<MapEntry<String, int>> channels = [];
    final parts = channelsJson.split(';');
    for (final part in parts) {
      if (part.isNotEmpty) {
        final channelParts = part.split(':');
        if (channelParts.length == 2) {
          final count = int.tryParse(channelParts[1]) ?? 0;
          channels.add(MapEntry(channelParts[0], count));
        }
      }
    }
    
    // Sort by count descending
    channels.sort((a, b) => b.value.compareTo(a.value));
    
    return channels.take(limit).map((e) => {'channelId': e.key, 'listenCount': e.value}).toList();
  }

  /// Get favorite genres
  Future<List<Map<String, dynamic>>> getFavoriteGenres({int limit = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final genresJson = prefs.getString(_genresListenedKey);
    
    if (genresJson == null || genresJson.isEmpty) {
      return [];
    }
    
    List<MapEntry<String, int>> genres = [];
    final parts = genresJson.split(';');
    for (final part in parts) {
      if (part.isNotEmpty) {
        final genreParts = part.split(':');
        if (genreParts.length == 2) {
          final count = int.tryParse(genreParts[1]) ?? 0;
          genres.add(MapEntry(genreParts[0], count));
        }
      }
    }
    
    // Sort by count descending
    genres.sort((a, b) => b.value.compareTo(a.value));
    
    return genres.take(limit).map((e) => {'genre': e.key, 'count': e.value}).toList();
  }

  /// Get recent history
  Future<List<Map<String, String>>> getRecentHistory({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_recentHistoryKey);
    
    if (historyJson == null || historyJson.isEmpty) {
      return [];
    }
    
    List<Map<String, String>> history = [];
    final parts = historyJson.split('|');
    for (final part in parts) {
      if (part.isNotEmpty) {
        final itemParts = part.split(';');
        if (itemParts.length == 3) {
          history.add({
            'channelId': itemParts[0],
            'channelName': itemParts[1],
            'genre': itemParts[2],
          });
        }
      }
    }
    
    return history.take(limit).toList();
  }

  /// Format duration to human-readable string
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m';
    } else if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    } else {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      return '${days}d ${hours}h';
    }
  }

  /// Clear all analytics
  Future<void> clearAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalListeningTimeKey);
    await prefs.remove(_listeningStreakKey);
    await prefs.remove(_lastListeningDateKey);
    await prefs.remove(_channelsListenedKey);
    await prefs.remove(_genresListenedKey);
    await prefs.remove(_recentHistoryKey);
  }
}