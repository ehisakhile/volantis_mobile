class CategoryModel {
  final int id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final int displayOrder;
  final int? createdByCompanyId;
  final int usageCount;
  final int isSystem;
  final int isActive;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.displayOrder,
    this.createdByCompanyId,
    required this.usageCount,
    required this.isSystem,
    required this.isActive,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'category',
      color: json['color'] ?? '#FFFFFF',
      displayOrder: json['display_order'] ?? 0,
      createdByCompanyId: json['created_by_company_id'],
      usageCount: json['usage_count'] ?? 0,
      isSystem: json['is_system'] ?? 0,
      isActive: json['is_active'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'display_order': displayOrder,
      'created_by_company_id': createdByCompanyId,
      'usage_count': usageCount,
      'is_system': isSystem,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class CategoriesResponse {
  final List<CategoryModel> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  CategoriesResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return CategoriesResponse(
      items: itemsList
          .map((json) => CategoryModel.fromJson(json))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}