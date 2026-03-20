/// Recording model for Volantis Live recordings/podcasts
class Recording {
  final int id;
  final int companyId;
  final int? livestreamId;
  final String title;
  final String? description;
  final String s3Url;
  final String streamingUrl;
  final int? durationSeconds;
  final int? fileSizeBytes;
  final bool isProcessed;
  final String? thumbnailUrl;
  final DateTime createdAt;
  // Only from single-fetch endpoint:
  final int? replayCount;
  final String? watchStatus; // null | "watching" | "completed"

  const Recording({
    required this.id,
    required this.companyId,
    this.livestreamId,
    required this.title,
    this.description,
    required this.s3Url,
    required this.streamingUrl,
    this.durationSeconds,
    this.fileSizeBytes,
    this.isProcessed = true,
    this.thumbnailUrl,
    required this.createdAt,
    this.replayCount,
    this.watchStatus,
  });

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'] as int,
    companyId: json['company_id'] as int,
    livestreamId: json['livestream_id'] as int?,
    title: json['title'] as String? ?? 'Untitled',
    description: json['description'] as String?,
    s3Url: json['s3_url'] as String? ?? '',
    streamingUrl: json['streaming_url'] as String? ?? '',
    durationSeconds: json['duration_seconds'] as int?,
    fileSizeBytes: json['file_size_bytes'] as int?,
    isProcessed: json['is_processed'] as bool? ?? false,
    thumbnailUrl: json['thumbnail_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    replayCount: json['replay_count'] as int?,
    watchStatus: json['watch_status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'livestream_id': livestreamId,
    'title': title,
    'description': description,
    's3_url': s3Url,
    'streaming_url': streamingUrl,
    'duration_seconds': durationSeconds,
    'file_size_bytes': fileSizeBytes,
    'is_processed': isProcessed,
    'thumbnail_url': thumbnailUrl,
    'created_at': createdAt.toIso8601String(),
    'replay_count': replayCount,
    'watch_status': watchStatus,
  };

  /// Get the full streaming URL
  String getFullStreamingUrl(String baseUrl) {
    if (streamingUrl.startsWith('http')) {
      return streamingUrl;
    }
    return '$baseUrl$streamingUrl';
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

  /// Check if recording has a thumbnail
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  /// Check if recording is processed and ready for playback
  bool get isReady => isProcessed && streamingUrl.isNotEmpty;
}

/// Watch history item for tracking user progress
class WatchHistoryItem {
  final int recordingId;
  final String recordingTitle;
  final String? recordingThumbnail;
  final int? recordingDuration;
  final String status; // "watching" | "completed"
  final int lastPosition;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const WatchHistoryItem({
    required this.recordingId,
    required this.recordingTitle,
    this.recordingThumbnail,
    this.recordingDuration,
    required this.status,
    required this.lastPosition,
    this.completedAt,
    required this.updatedAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) =>
      WatchHistoryItem(
        recordingId: json['recording_id'] as int,
        recordingTitle: json['recording_title'] as String? ?? 'Untitled',
        recordingThumbnail: json['recording_thumbnail'] as String?,
        recordingDuration: json['recording_duration'] as int?,
        status: json['status'] as String? ?? 'watching',
        lastPosition: json['last_position'] as int? ?? 0,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (recordingDuration == null || recordingDuration == 0) return 0.0;
    return lastPosition / recordingDuration!;
  }

  /// Check if this item is completed
  bool get isCompleted => status == 'completed';

  /// Format last position to readable string
  String get formattedLastPosition {
    final hours = lastPosition ~/ 3600;
    final minutes = (lastPosition % 3600) ~/ 60;
    final seconds = lastPosition % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
