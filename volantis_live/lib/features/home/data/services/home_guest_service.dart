import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../models/company_model.dart';
import '../models/guest_home_models.dart';

class HomeGuestService {
  final ApiService _apiService = ApiService.instance;

  Future<(List<CompanyModel>?, String?)> getCompanies({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final endpoint = ApiConstants.getCompaniesEndpoint(
        limit: limit,
        offset: offset,
      );
      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final companiesResponse = CompaniesResponse.fromJson(response.data);
        return (companiesResponse.companies, null);
      }
      return (null, 'Failed to load companies');
    } on DioException catch (e) {
      return (null, e.message ?? 'Network error');
    } catch (e) {
      return (null, 'An unexpected error occurred');
    }
  }

  Future<(List<ActiveLivestream>?, String?)> getActiveLivestreams({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final endpoint = '/livestreams/active?limit=$limit&offset=$offset';
      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final livestreamsResponse = ActiveLivestreamsResponse.fromJson(
          response.data,
        );
        return (livestreamsResponse.streams, null);
      }
      return (null, 'Failed to load livestreams');
    } on DioException catch (e) {
      return (null, e.message ?? 'Network error');
    } catch (e) {
      return (null, 'An unexpected error occurred');
    }
  }
}
