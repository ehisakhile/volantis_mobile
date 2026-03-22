import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final int id;
  final String livestreamSlug;
  final String username;
  final String content;
  final bool isDeleted;
  final bool isEdited;
  final bool isCreator;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChatMessageModel({
    required this.id,
    required this.livestreamSlug,
    required this.username,
    required this.content,
    this.isDeleted = false,
    this.isEdited = false,
    this.isCreator = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? 0,
      livestreamSlug: json['livestream_slug'] ?? '',
      username: json['username'] ?? '',
      content: json['content'] ?? '',
      isDeleted: json['is_deleted'] ?? false,
      isEdited: json['is_edited'] ?? false,
      isCreator: json['is_creator'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'livestream_slug': livestreamSlug,
      'username': username,
      'content': content,
      'is_deleted': isDeleted,
      'is_edited': isEdited,
      'is_creator': isCreator,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ChatMessageModel copyWith({
    int? id,
    String? livestreamSlug,
    String? username,
    String? content,
    bool? isDeleted,
    bool? isEdited,
    bool? isCreator,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      livestreamSlug: livestreamSlug ?? this.livestreamSlug,
      username: username ?? this.username,
      content: content ?? this.content,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      isCreator: isCreator ?? this.isCreator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        livestreamSlug,
        username,
        content,
        isDeleted,
        isEdited,
        isCreator,
        createdAt,
        updatedAt,
      ];
}
