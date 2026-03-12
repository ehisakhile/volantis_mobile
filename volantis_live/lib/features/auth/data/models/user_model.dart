import 'package:equatable/equatable.dart';

/// User model for authentication
class User extends Equatable {
  final int id;
  final int? companyId;
  final String? companyName;
  final String? companySlug;
  final String email;
  final String? username;
  final String? role;
  final bool isActive;
  final DateTime createdAt;

  const User({
    required this.id,
    this.companyId,
    this.companyName,
    this.companySlug,
    required this.email,
    this.username,
    this.role,
    this.isActive = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      companyId: json['company_id'],
      companyName: json['company_name'],
      companySlug: json['company_slug'],
      email: json['email'] ?? '',
      username: json['username'],
      role: json['role'],
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'company_name': companyName,
      'company_slug': companySlug,
      'email': email,
      'username': username,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    int? companyId,
    String? companyName,
    String? companySlug,
    String? email,
    String? username,
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companySlug: companySlug ?? this.companySlug,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        companyName,
        companySlug,
        email,
        username,
        role,
        isActive,
        createdAt,
      ];
}