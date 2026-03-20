/// Model representing a company from the companies list API response
class CompanyModel {
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;
  final String? email;
  final bool? isActive;
  final DateTime? createdAt;

  CompanyModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    this.email,
    this.isActive,
    this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      logoUrl: json['logo_url'],
      description: json['description'],
      email: json['email'],
      isActive: json['is_active'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'description': description,
      'email': email,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Check if company has a logo
  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
}

/// Response model for companies list API
class CompaniesResponse {
  final List<CompanyModel> companies;
  final int total;

  CompaniesResponse({required this.companies, required this.total});

  factory CompaniesResponse.fromJson(Map<String, dynamic> json) {
    final companiesList = json['companies'] as List<dynamic>? ?? [];
    return CompaniesResponse(
      companies: companiesList
          .map((json) => CompanyModel.fromJson(json))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}
