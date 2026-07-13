import 'package:dio/dio.dart';
import '../models/meeting_model.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';

/// Repository for meeting/video conferencing API calls
class MeetingRepository {
  final ApiService _apiService = ApiService.instance;

  /// Create an instant meeting
  Future<Meeting> createInstantMeeting({String? title}) async {
    try {
      print('MeetingRepository: Creating instant meeting');
      final response = await _apiService.post(
        ApiConstants.createInstantMeeting,
        data: FormData.fromMap({
          'title': title ?? 'Quick Meeting',
          'stream_type': 'video',
        }),
      );
      print('MeetingRepository: Create meeting response: ${response.data}');
      return Meeting.fromJson(response.data);
    } on DioException catch (e) {
      print('MeetingRepository: Create meeting error - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Get meeting details by ID (public endpoint, no auth required but safe to send)
  Future<Meeting> getMeeting(String meetingId) async {
    try {
      print('MeetingRepository: Fetching meeting $meetingId');
      final response = await _apiService.get(ApiConstants.getMeetingEndpoint(meetingId));
      print('MeetingRepository: Get meeting response: ${response.data}');
      return Meeting.fromJson(response.data);
    } on DioException catch (e) {
      print('MeetingRepository: Get meeting error - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Join meeting as authenticated user (gets LiveKit token)
  Future<Meeting> joinMeeting(String meetingId) async {
    try {
      print('MeetingRepository: Joining meeting $meetingId');
      final response = await _apiService.post(
        ApiConstants.getMeetingJoinEndpoint(meetingId),
        data: FormData.fromMap({'role': 'participant'}),
      );
      print('MeetingRepository: Join meeting response: ${response.data}');
      return Meeting.fromJson(response.data);
    } on DioException catch (e) {
      print('MeetingRepository: Join meeting error - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Join meeting as guest (unauthenticated, requires display name)
  Future<GuestTokenResponse> guestJoin(String meetingId, String displayName) async {
    try {
      print('MeetingRepository: Guest joining meeting $meetingId as $displayName');
      final response = await _apiService.post(
        ApiConstants.getMeetingGuestTokenEndpoint(meetingId),
        data: {'display_name': displayName},
        options: Options(contentType: Headers.jsonContentType),
      );
      print('MeetingRepository: Guest join response: ${response.data}');
      return GuestTokenResponse.fromJson(response.data);
    } on DioException catch (e) {
      print('MeetingRepository: Guest join error - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Leave a meeting
  Future<void> leaveMeeting(String meetingId) async {
    try {
      print('MeetingRepository: Leaving meeting $meetingId');
      await _apiService.post(ApiConstants.getMeetingLeaveEndpoint(meetingId));
      print('MeetingRepository: Successfully left meeting');
    } on DioException catch (e) {
      print('MeetingRepository: Leave meeting error - ${e.message}');
      throw _handleError(e);
    }
  }

  /// Handle errors from API
  Exception _handleError(DioException e) {
    String message;
    print('MeetingRepository: Handling error - type: ${e.type}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        print('MeetingRepository: Bad response - statusCode: $statusCode, data: $responseData');

        if (statusCode == 401) {
          message = 'Not authorized. Please log in.';
        } else if (statusCode == 404) {
          message = 'Meeting not found.';
        } else if (statusCode == 422) {
          if (responseData is Map) {
            message = responseData['detail'] ?? responseData['error'] ?? 'Invalid request.';
          } else {
            message = 'Invalid request.';
          }
        } else if (statusCode == 500) {
          message = 'Server error. Please try again later.';
        } else if (statusCode == 400) {
          message = responseData['detail'] ?? 'Bad request. Please check your input.';
        } else {
          message = 'Something went wrong. Please try again.';
        }
        break;
      default:
        message = e.message ?? 'An unexpected error occurred.';
    }
    return Exception(message);
  }
}
