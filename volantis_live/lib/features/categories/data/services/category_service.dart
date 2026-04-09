import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../models/category_model.dart';

class CategoryService {
  final ApiService _apiService;

  CategoryService(this._apiService);

  Future<CategoriesResponse> getCategories({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getCategoriesEndpoint(page: page, limit: limit),
      );
      return CategoriesResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CategoryModel>> getUserPreferences() async {
    try {
      final response = await _apiService.get(ApiConstants.categoryPreferences);
      if (response.data is List) {
        return (response.data as List)
            .map((json) => CategoryModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setUserPreferences(List<int> categoryIds) async {
    print('Setting preferences with category IDs: $categoryIds');
    try {
      final r = await _apiService.put(
        ApiConstants.categoryPreferences,
        data: {'category_ids': categoryIds},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('Set preferences response: ${r.statusCode} - ${r.data}');
    } catch (e) {
      print('Error setting preferences: $e');
      rethrow;
    }
  }
}