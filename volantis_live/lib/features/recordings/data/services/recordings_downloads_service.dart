import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/encryption_service.dart';
import '../models/recording_download.dart';

/// Service for managing recording downloads with client-side encryption
class RecordingsDownloadsService {
  static RecordingsDownloadsService? _instance;
  Database? _database;
  final Dio _dio;
  final EncryptionService _encryptionService;
  final FlutterSecureStorage _secureStorage;

  static const String _dbName = 'volantis_recordings_downloads.db';
  static const String _tableName = 'recording_downloads';
  static const String _preferencesKey = 'recording_download_preferences';

  RecordingsDownloadsService._(this._dio, this._encryptionService)
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  static RecordingsDownloadsService get instance {
    _instance ??= throw Exception(
      'RecordingsDownloadsService not initialized. Call init() first.',
    );
    return _instance!;
  }

  /// Initialize the service with dependencies
  static Future<RecordingsDownloadsService> init(Dio dio) async {
    final encryptionService = EncryptionService.instance;
    await encryptionService.init();

    _instance = RecordingsDownloadsService._(dio, encryptionService);
    await _instance!._initDatabase();
    return _instance!;
  }

  /// Initialize database
  Future<void> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _dbName);

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recording_id INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            description TEXT,
            thumbnail_url TEXT,
            local_path TEXT NOT NULL,
            file_size_bytes INTEGER NOT NULL,
            downloaded_at INTEGER NOT NULL,
            expires_at INTEGER,
            last_position INTEGER DEFAULT 0,
            status INTEGER DEFAULT 4,
            download_progress REAL DEFAULT 0.0,
            company_name TEXT,
            company_slug TEXT,
            duration_seconds INTEGER
          )
        ''');

        // Create index for faster lookups
        await db.execute(
          'CREATE INDEX idx_recording_id ON $_tableName (recording_id)',
        );
      },
    );
  }

  /// Get database
  Database get db {
    if (_database == null) {
      throw Exception('RecordingsDownloadsService not initialized');
    }
    return _database!;
  }

  /// Get downloads directory
  Future<String> _getDownloadsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(path.join(dir.path, 'recordings_downloads'));

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    return downloadsDir.path;
  }

  /// Start downloading a recording
  Future<RecordingDownload> startDownload({
    required int recordingId,
    required String title,
    String? description,
    String? thumbnailUrl,
    required String downloadUrl,
    int? fileSizeBytes,
    String? companyName,
    String? companySlug,
    int? durationSeconds,
    Function(double)? onProgress,
  }) async {
    // Check if already downloaded
    final existing = await getDownload(recordingId);
    if (existing != null) {
      return existing;
    }

    final downloadsDir = await _getDownloadsDirectory();
    final fileName =
        'recording_${recordingId}_${DateTime.now().millisecondsSinceEpoch}.enc';
    final localPath = path.join(downloadsDir, fileName);

    // Create temporary file path for downloading
    final tempPath = path.join(downloadsDir, 'temp_$fileName');

    try {
      // Update status to downloading
      await _insertDownload(
        recordingId: recordingId,
        title: title,
        description: description,
        thumbnailUrl: thumbnailUrl,
        localPath: tempPath,
        fileSizeBytes: fileSizeBytes ?? 0,
        status: DownloadStatus.downloading,
        companyName: companyName,
        companySlug: companySlug,
        durationSeconds: durationSeconds,
      );

      // Download the file
      await _dio.download(
        downloadUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress?.call(progress);
            _updateProgress(recordingId, progress);
          }
        },
      );

      // Encrypt the downloaded file
      await _encryptionService.encryptFile(tempPath, localPath);

      // Delete temp file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Get final file size
      final encryptedFile = File(localPath);
      final finalSize = await encryptedFile.length();

      // Update status to downloaded
      await _updateDownloadStatus(
        recordingId,
        DownloadStatus.downloaded,
        localPath: localPath,
        fileSizeBytes: finalSize,
      );

      return (await getDownload(recordingId))!;
    } catch (e) {
      // Update status to failed
      await _updateDownloadStatus(recordingId, DownloadStatus.failed);
      rethrow;
    }
  }

  /// Insert a new download record
  Future<int> _insertDownload({
    required int recordingId,
    required String title,
    String? description,
    String? thumbnailUrl,
    required String localPath,
    required int fileSizeBytes,
    required DownloadStatus status,
    String? companyName,
    String? companySlug,
    int? durationSeconds,
  }) async {
    return db.insert(_tableName, {
      'recording_id': recordingId,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'local_path': localPath,
      'file_size_bytes': fileSizeBytes,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      'status': status.index,
      'download_progress': 0.0,
      'company_name': companyName,
      'company_slug': companySlug,
      'duration_seconds': durationSeconds,
    });
  }

  /// Update download progress
  Future<void> _updateProgress(int recordingId, double progress) async {
    await db.update(
      _tableName,
      {'download_progress': progress},
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
  }

  /// Update download status
  Future<void> _updateDownloadStatus(
    int recordingId,
    DownloadStatus status, {
    String? localPath,
    int? fileSizeBytes,
  }) async {
    final updateData = <String, dynamic>{'status': status.index};

    if (localPath != null) {
      updateData['local_path'] = localPath;
    }

    if (fileSizeBytes != null) {
      updateData['file_size_bytes'] = fileSizeBytes;
    }

    await db.update(
      _tableName,
      updateData,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
  }

  /// Get a single download by recording ID
  Future<RecordingDownload?> getDownload(int recordingId) async {
    final results = await db.query(
      _tableName,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );

    if (results.isEmpty) return null;
    return RecordingDownload.fromJson(results.first);
  }

  /// Get all downloads
  Future<List<RecordingDownload>> getAllDownloads({
    DownloadStatus? status,
  }) async {
    List<Map<String, dynamic>> results;

    if (status != null) {
      results = await db.query(
        _tableName,
        where: 'status = ?',
        whereArgs: [status.index],
        orderBy: 'downloaded_at DESC',
      );
    } else {
      results = await db.query(_tableName, orderBy: 'downloaded_at DESC');
    }

    return results.map((r) => RecordingDownload.fromJson(r)).toList();
  }

  /// Get downloaded recordings only
  Future<List<RecordingDownload>> getDownloadedRecordings() async {
    return getAllDownloads(status: DownloadStatus.downloaded);
  }

  /// Check if recording is downloaded
  Future<bool> isRecordingDownloaded(int recordingId) async {
    final download = await getDownload(recordingId);
    if (download == null) return false;

    // Check if status is downloaded and file exists
    if (download.status != DownloadStatus.downloaded) return false;

    final file = File(download.localPath);
    return file.existsSync();
  }

  /// Get download status for a recording
  Future<DownloadStatus> getDownloadStatus(int recordingId) async {
    final download = await getDownload(recordingId);
    return download?.status ?? DownloadStatus.notDownloaded;
  }

  /// Get decrypted file path for playback
  Future<String> getDecryptedFilePath(int recordingId) async {
    final download = await getDownload(recordingId);
    if (download == null) {
      throw Exception('Recording not downloaded');
    }

    if (download.status != DownloadStatus.downloaded) {
      throw Exception('Recording download not complete');
    }

    // Check if file exists
    final file = File(download.localPath);
    if (!file.existsSync()) {
      throw Exception('Downloaded file not found');
    }

    // Decrypt to temp file for playback
    final fileName = 'playback_${recordingId}.mp3';
    return _encryptionService.decryptToTempFile(download.localPath, fileName);
  }

  /// Update playback position
  Future<void> updatePosition(int recordingId, int positionSeconds) async {
    await db.update(
      _tableName,
      {'last_position': positionSeconds},
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
  }

  /// Delete a download
  Future<void> deleteDownload(int recordingId) async {
    final download = await getDownload(recordingId);

    if (download != null) {
      // Delete the encrypted file
      final file = File(download.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete(
      _tableName,
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
  }

  /// Delete all downloads
  Future<void> deleteAllDownloads() async {
    final downloads = await getAllDownloads();

    for (final download in downloads) {
      final file = File(download.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete(_tableName);
  }

  /// Get total storage used by downloads
  Future<int> getTotalStorageUsed() async {
    final downloads = await getDownloadedRecordings();
    int total = 0;
    for (final download in downloads) {
      final file = File(download.localPath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// Get download count
  Future<int> getDownloadCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE status = ?',
      [DownloadStatus.downloaded.index],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Save download preferences
  Future<void> savePreferences(DownloadPreferences preferences) async {
    await _secureStorage.write(
      key: _preferencesKey,
      value: preferences.toJson().toString(),
    );
  }

  /// Load download preferences
  Future<DownloadPreferences> loadPreferences() async {
    final data = await _secureStorage.read(key: _preferencesKey);
    if (data == null) return const DownloadPreferences();

    // Parse the stored string back to JSON
    try {
      final map = _parsePreferences(data);
      return DownloadPreferences.fromJson(map);
    } catch (_) {
      return const DownloadPreferences();
    }
  }

  Map<String, dynamic> _parsePreferences(String data) {
    // Simple parsing for the stored string
    final result = <String, dynamic>{};
    final regex = RegExp(r"(\w+):\s*([^,})]+)");
    for (final match in regex.allMatches(data)) {
      final key = match.group(1)!;
      var value = match.group(2)!.trim();

      if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else if (int.tryParse(value) != null) {
        result[key] = int.parse(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  /// Dispose
  Future<void> dispose() async {
    await _database?.close();
    _instance = null;
  }
}
