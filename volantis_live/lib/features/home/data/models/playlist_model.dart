import 'package:volantis_live/core/constants/api_constants.dart';

class PlaylistItemModel {
  final int id;
  final int playlistId;
  final int position;
  final bool isSkipped;
  final String mediaType;
  final int? mediaId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? s3Url;
  final String? streamingUrl;
  final String? mediaSubtype;
  final String? caption;
  final String? fileName;
  final List<int>? categoryIds;
  final DateTime? createdAt;

  PlaylistItemModel({
    required this.id,
    required this.title,
    this.playlistId = 0,
    this.position = 0,
    this.isSkipped = false,
    this.mediaType = 'recording',
    this.mediaId,
    this.description,
    this.thumbnailUrl,
    this.durationSeconds,
    this.s3Url,
    this.streamingUrl,
    this.mediaSubtype,
    this.caption,
    this.fileName,
    this.categoryIds,
    this.createdAt,
  });

  factory PlaylistItemModel.fromJson(Map<String, dynamic> json) {
    return PlaylistItemModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      playlistId: json['playlist_id'] ?? 0,
      position: json['position'] ?? 0,
      isSkipped: json['is_skipped'] ?? false,
      mediaType: json['media_type'] ?? 'recording',
      mediaId: json['media_id'],
      description: json['description'],
      thumbnailUrl: json['thumbnail_url'],
      durationSeconds: json['duration_seconds'],
      s3Url: json['s3_url'],
      streamingUrl: json['streaming_url'],
      mediaSubtype: json['media_subtype'],
      caption: json['caption'],
      fileName: json['file_name'],
      categoryIds: (json['category_ids'] as List<dynamic>?)?.cast<int>(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playlist_id': playlistId,
      'position': position,
      'is_skipped': isSkipped,
      'media_type': mediaType,
      'media_id': mediaId,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      's3_url': s3Url,
      'streaming_url': streamingUrl,
      'media_subtype': mediaSubtype,
      'caption': caption,
      'file_name': fileName,
      'category_ids': categoryIds,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static const _videoExtensions = [
    '.mp4',
    '.m4v',
    '.webm',
    '.mov',
    '.mkv',
    '.m3u8',
  ];

  /// Absolute URL for the playable media, preferring the S3 source.
  String? get mediaUrl {
    if (s3Url != null && s3Url!.isNotEmpty) return s3Url;
    return streamingUrlAbsolute;
  }

  /// Fully-qualified streaming URL (relative values are joined to the API base).
  String? get streamingUrlAbsolute {
    final url = streamingUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http') || url.startsWith('file://')) return url;
    return '${ApiConstants.baseUrl}$url';
  }

  /// A media item is a video when its source file is a video container.
  /// Extension takes precedence over [mediaSubtype] so that `.mp3` files
  /// (even those tagged `video`) are always played back as audio.
  bool get isVideo {
    final url = (s3Url ?? streamingUrl ?? '').toLowerCase();
    return _videoExtensions.any(url.endsWith);
  }

  bool get isAudio => !isVideo;

  bool get hasPlayableMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return 'N/A';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PlaylistModel {
  final int id;
  final String slug;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final int itemCount;
  final int? totalDurationSeconds;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<PlaylistItemModel> items;

  PlaylistModel({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.itemCount,
    this.totalDurationSeconds,
    required this.isPublic,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ??
        json['media'] as List<dynamic>? ??
        [];
    return PlaylistModel(
      id: json['id'] ?? json['playlist_id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['name'] ?? json['title'] ?? '',
      description: json['description'],
      thumbnailUrl: json['cover_image_url'] ?? json['thumbnail_url'],
      itemCount: json['media_count'] ??
          json['total'] ??
          itemsJson.length,
      totalDurationSeconds: json['total_duration_seconds'],
      isPublic: json['is_public'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      items: itemsJson
          .map(
            (item) => PlaylistItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  PlaylistModel copyWith({
    int? id,
    String? slug,
    String? title,
    String? description,
    String? thumbnailUrl,
    int? itemCount,
    int? totalDurationSeconds,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlaylistItemModel>? items,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      itemCount: itemCount ?? this.itemCount,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'item_count': itemCount,
      'total_duration_seconds': totalDurationSeconds,
      'is_public': isPublic,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  String get formattedTotalDuration {
    if (totalDurationSeconds == null || totalDurationSeconds! <= 0) return '';
    final hours = totalDurationSeconds! ~/ 3600;
    final minutes = (totalDurationSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
