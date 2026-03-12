import 'package:equatable/equatable.dart';

/// Channel model for streaming channels
class Channel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? genre;
  final String streamUrl;
  final bool isLive;
  final int? listenerCount;
  final DateTime? scheduledTime;
  final bool isSubscribed;
  final bool isDownloaded;

  const Channel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.genre,
    required this.streamUrl,
    this.isLive = false,
    this.listenerCount,
    this.scheduledTime,
    this.isSubscribed = false,
    this.isDownloaded = false,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      genre: json['genre'],
      streamUrl: json['stream_url'] ?? '',
      isLive: json['is_live'] ?? false,
      listenerCount: json['listener_count'],
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'])
          : null,
      isSubscribed: json['is_subscribed'] ?? false,
      isDownloaded: json['is_downloaded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'genre': genre,
      'stream_url': streamUrl,
      'is_live': isLive,
      'listener_count': listenerCount,
      'scheduled_time': scheduledTime?.toIso8601String(),
      'is_subscribed': isSubscribed,
      'is_downloaded': isDownloaded,
    };
  }

  Channel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? genre,
    String? streamUrl,
    bool? isLive,
    int? listenerCount,
    DateTime? scheduledTime,
    bool? isSubscribed,
    bool? isDownloaded,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      genre: genre ?? this.genre,
      streamUrl: streamUrl ?? this.streamUrl,
      isLive: isLive ?? this.isLive,
      listenerCount: listenerCount ?? this.listenerCount,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        genre,
        streamUrl,
        isLive,
        listenerCount,
        scheduledTime,
        isSubscribed,
        isDownloaded,
      ];
}

/// Stream model for live streams
class StreamInfo extends Equatable {
  final String id;
  final String channelId;
  final String channelName;
  final String? channelImage;
  final String streamUrl;
  final bool isLive;
  final int? listenerCount;
  final String? quality; // low, medium, high

  const StreamInfo({
    required this.id,
    required this.channelId,
    required this.channelName,
    this.channelImage,
    required this.streamUrl,
    this.isLive = false,
    this.listenerCount,
    this.quality,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      id: json['id'] ?? '',
      channelId: json['channel_id'] ?? '',
      channelName: json['channel_name'] ?? '',
      channelImage: json['channel_image'],
      streamUrl: json['stream_url'] ?? '',
      isLive: json['is_live'] ?? false,
      listenerCount: json['listener_count'],
      quality: json['quality'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        channelId,
        channelName,
        channelImage,
        streamUrl,
        isLive,
        listenerCount,
        quality,
      ];
}