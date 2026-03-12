import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// Service for managing offline content downloads
class OfflineService {
  static OfflineService? _instance;
  Database? _database;
  
  static const String _dbName = 'volantis_offline.db';
  static const String _tableName = 'downloads';

  OfflineService._();

  static OfflineService get instance {
    _instance ??= OfflineService._();
    return _instance!;
  }

  /// Initialize database
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _dbName);
    
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel_id TEXT NOT NULL,
            channel_name TEXT NOT NULL,
            channel_image TEXT,
            stream_url TEXT NOT NULL,
            local_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            downloaded_at INTEGER NOT NULL,
            is_live INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Get database
  Database get db {
    if (_database == null) {
      throw Exception('OfflineService not initialized. Call init() first.');
    }
    return _database!;
  }

  /// Add a download
  Future<int> addDownload({
    required String channelId,
    required String channelName,
    String? channelImage,
    required String streamUrl,
    required String localPath,
    required int fileSize,
    bool isLive = false,
  }) async {
    return db.insert(_tableName, {
      'channel_id': channelId,
      'channel_name': channelName,
      'channel_image': channelImage,
      'stream_url': streamUrl,
      'local_path': localPath,
      'file_size': fileSize,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      'is_live': isLive ? 1 : 0,
    });
  }

  /// Get all downloads
  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    return db.query(_tableName, orderBy: 'downloaded_at DESC');
  }

  /// Get download by channel ID
  Future<Map<String, dynamic>?> getDownloadByChannelId(String channelId) async {
    final results = await db.query(
      _tableName,
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Check if channel is downloaded
  Future<bool> isChannelDownloaded(String channelId) async {
    final download = await getDownloadByChannelId(channelId);
    if (download == null) return false;
    
    // Check if file still exists
    final localPath = download['local_path'] as String;
    final file = File(localPath);
    return file.existsSync();
  }

  /// Delete a download
  Future<int> deleteDownload(int id) async {
    final download = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    
    if (download.isNotEmpty) {
      final localPath = download.first['local_path'] as String;
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    return db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete download by channel ID
  Future<int> deleteDownloadByChannelId(String channelId) async {
    final download = await getDownloadByChannelId(channelId);
    
    if (download != null) {
      final localPath = download['local_path'] as String;
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    return db.delete(_tableName, where: 'channel_id = ?', whereArgs: [channelId]);
  }

  /// Get total storage used
  Future<int> getTotalStorageUsed() async {
    final downloads = await getAllDownloads();
    int total = 0;
    for (final download in downloads) {
      total += (download['file_size'] as int?) ?? 0;
    }
    return total;
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    final downloads = await getAllDownloads();
    for (final download in downloads) {
      final localPath = download['local_path'] as String;
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await db.delete(_tableName);
  }

  /// Get downloads directory
  Future<String> getDownloadsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(path.join(dir.path, 'downloads'));
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    
    return downloadsDir.path;
  }

  /// Dispose
  Future<void> dispose() async {
    await _database?.close();
    _instance = null;
  }
}