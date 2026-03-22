/// Download status enum for tracking download progress
enum DownloadStatus {
  notDownloaded,
  queued,
  downloading,
  paused,
  downloaded,
  failed,
  expired,
}

/// Extension to get display text for download status
extension DownloadStatusExtension on DownloadStatus {
  String get displayName {
    switch (this) {
      case DownloadStatus.notDownloaded:
        return 'Not Downloaded';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.downloaded:
        return 'Downloaded';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.expired:
        return 'Expired';
    }
  }

  bool get isDownloading =>
      this == DownloadStatus.downloading || this == DownloadStatus.queued;
  bool get canDownload =>
      this == DownloadStatus.notDownloaded ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.expired;
  bool get canPause => this == DownloadStatus.downloading;
  bool get canResume => this == DownloadStatus.paused;
  bool get canDelete =>
      this == DownloadStatus.downloaded || this == DownloadStatus.paused;
}

/// Recording download model for tracking downloaded recordings
class RecordingDownload {
  final int id;
  final int recordingId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String localPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final DateTime? expiresAt;
  final int lastPosition;
  final DownloadStatus status;
  final double downloadProgress;
  final String? companyName;
  final String? companySlug;
  final int? durationSeconds;

  const RecordingDownload({
    required this.id,
    required this.recordingId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.expiresAt,
    this.lastPosition = 0,
    this.status = DownloadStatus.downloaded,
    this.downloadProgress = 0.0,
    this.companyName,
    this.companySlug,
    this.durationSeconds,
  });

  factory RecordingDownload.fromJson(Map<String, dynamic> json) {
    return RecordingDownload(
      id: json['id'] as int,
      recordingId: json['recording_id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      localPath: json['local_path'] as String,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        json['downloaded_at'] as int,
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expires_at'] as int)
          : null,
      lastPosition: json['last_position'] as int? ?? 0,
      status: DownloadStatus.values[json['status'] as int? ?? 4],
      downloadProgress: (json['download_progress'] as num?)?.toDouble() ?? 0.0,
      companyName: json['company_name'] as String?,
      companySlug: json['company_slug'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recording_id': recordingId,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'local_path': localPath,
      'file_size_bytes': fileSizeBytes,
      'downloaded_at': downloadedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'last_position': lastPosition,
      'status': status.index,
      'download_progress': downloadProgress,
      'company_name': companyName,
      'company_slug': companySlug,
      'duration_seconds': durationSeconds,
    };
  }

  /// Check if download has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Format duration to readable string (e.g., "1:23:45")
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (durationSeconds == null || durationSeconds == 0) return 0.0;
    return lastPosition / durationSeconds!;
  }

  /// Copy with new values
  RecordingDownload copyWith({
    int? id,
    int? recordingId,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? localPath,
    int? fileSizeBytes,
    DateTime? downloadedAt,
    DateTime? expiresAt,
    int? lastPosition,
    DownloadStatus? status,
    double? downloadProgress,
    String? companyName,
    String? companySlug,
    int? durationSeconds,
  }) {
    return RecordingDownload(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastPosition: lastPosition ?? this.lastPosition,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      companyName: companyName ?? this.companyName,
      companySlug: companySlug ?? this.companySlug,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

/// Download preferences model
class DownloadPreferences {
  final String quality; // low, medium, high
  final bool downloadOverWifiOnly;
  final bool autoDownloadNew;
  final int? maxStorageGB;

  const DownloadPreferences({
    this.quality = 'high',
    this.downloadOverWifiOnly = true,
    this.autoDownloadNew = false,
    this.maxStorageGB,
  });

  factory DownloadPreferences.fromJson(Map<String, dynamic> json) {
    return DownloadPreferences(
      quality: json['quality'] as String? ?? 'high',
      downloadOverWifiOnly: json['download_over_wifi_only'] as bool? ?? true,
      autoDownloadNew: json['auto_download_new'] as bool? ?? false,
      maxStorageGB: json['max_storage_gb'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality,
      'download_over_wifi_only': downloadOverWifiOnly,
      'auto_download_new': autoDownloadNew,
      'max_storage_gb': maxStorageGB,
    };
  }

  DownloadPreferences copyWith({
    String? quality,
    bool? downloadOverWifiOnly,
    bool? autoDownloadNew,
    int? maxStorageGB,
  }) {
    return DownloadPreferences(
      quality: quality ?? this.quality,
      downloadOverWifiOnly: downloadOverWifiOnly ?? this.downloadOverWifiOnly,
      autoDownloadNew: autoDownloadNew ?? this.autoDownloadNew,
      maxStorageGB: maxStorageGB ?? this.maxStorageGB,
    );
  }
}
