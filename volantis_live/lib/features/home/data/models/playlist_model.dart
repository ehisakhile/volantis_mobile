class PlaylistItemModel {
  final int id;
  final String title;
  final String? description;
  final String mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int order;
  final DateTime? createdAt;

  PlaylistItemModel({
    required this.id,
    required this.title,
    this.description,
    required this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.order,
    this.createdAt,
  });

  factory PlaylistItemModel.fromJson(Map<String, dynamic> json) {
    return PlaylistItemModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      mediaType: json['media_type'] ?? 'audio',
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      durationSeconds: json['duration_seconds'],
      order: json['order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'order': order,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isVideo => mediaType == 'video';
  bool get isAudio => mediaType == 'audio';

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
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return PlaylistModel(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['name'] ?? '',
      description: json['description'],
      thumbnailUrl: json['cover_image_url'] ?? json['thumbnail_url'],
      itemCount: json['media_count'] ?? itemsJson.length,
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
