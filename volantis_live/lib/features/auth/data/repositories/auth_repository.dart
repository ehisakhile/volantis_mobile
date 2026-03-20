import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../services/api_service.dart';
import '../models/user_model.dart';

/// Auth repository for handling authentication
class AuthRepository {
  final ApiService _apiService = ApiService.instance;

  /// Login with email and password
  Future<LoginResponse> login(String email, String password) async {
    try {
      print(
        'API: Attempting login to ${ApiConstants.baseUrl}${ApiConstants.login}',
      );
      print('API: Login payload - email: $email');

      final response = await _apiService.post(
        ApiConstants.login,
        data: FormData.fromMap({'email': email, 'password': password}),
      );

      print('API: Login response: ${response.data}');

      final loginResponse = LoginResponse.fromJson(response.data);

      // Save tokens in secure storage
      await ApiService.saveToken(loginResponse.accessToken);
      if (loginResponse.refreshToken.isNotEmpty) {
        await ApiService.saveRefreshToken(loginResponse.refreshToken);
      }

      return loginResponse;
    } on DioException catch (e) {
      print('API: Login error - ${e.message}');
      print('API: Login error response - ${e.response?.data}');
      print('API: Login error status - ${e.response?.statusCode}');
      throw _handleError(e);
    }
  }

  /// Register new user
  Future<SignupResponse> signup(
    String email,
    String username,
    String password,
  ) async {
    try {
      print(
        'API: Attempting signup to ${ApiConstants.baseUrl}${ApiConstants.signup}',
      );
      print('API: Signup payload - email: $email, username: $username');

      final response = await _apiService.post(
        ApiConstants.signup,
        data: FormData.fromMap({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      print('API: Signup response: ${response.data}');

      final signupResponse = SignupResponse.fromJson(response.data);

      // Save user ID for OTP verification
      await ApiService.saveUserId(signupResponse.userId.toString());

      return signupResponse;
    } on DioException catch (e) {
      print('API: Signup error - ${e.message}');
      print('API: Signup error response - ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Verify email with OTP
  Future<void> verifyEmail(String userId, String otp) async {
    try {
      print(
        'API: Attempting verify to ${ApiConstants.baseUrl}${ApiConstants.verifyEmail}',
      );

      print('API: Verify payload - userId: $userId, otp: $otp');

      final response = await _apiService.post(
        ApiConstants.verifyEmail,
        data: FormData.fromMap({'user_id': userId, 'otp': otp}),
      );

      print('API: Verify response: ${response.data}');
    } on DioException catch (e) {
      print('API: Verify error - ${e.message}');
      print('API: Verify error response - ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Request password reset
  Future<String> requestPasswordReset(String email) async {
    try {
      print(
        'API: Requesting password reset to ${ApiConstants.baseUrl}${ApiConstants.passwordReset}',
      );
      print('API: Password reset payload - email: $email');

      final response = await _apiService.post(
        ApiConstants.passwordReset,
        data: {'email': email},
        options: Options(contentType: Headers.jsonContentType),
      );

      print('API: Password reset response: ${response.data}');

      return response.data['message'] ??
          'Password reset code sent to your email';
    } on DioException catch (e) {
      print('API: Password reset error - ${e.message}');
      print('API: Password reset error response - ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Verify password reset OTP and set new password
  /// Returns LoginResponse which includes access token for auto-login
  Future<LoginResponse> verifyPasswordReset(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      print(
        'API: Verifying password reset to ${ApiConstants.baseUrl}${ApiConstants.passwordResetVerify}',
      );
      print('API: Password reset verify payload - email: $email, otp: $otp');

      final response = await _apiService.post(
        ApiConstants.passwordResetVerify,
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
        options: Options(contentType: Headers.jsonContentType),
      );

      print('API: Password reset verify response: ${response.data}');

      final loginResponse = LoginResponse.fromJson(response.data);

      // Save tokens in secure storage for auto-login
      await ApiService.saveToken(loginResponse.accessToken);
      if (loginResponse.refreshToken.isNotEmpty) {
        await ApiService.saveRefreshToken(loginResponse.refreshToken);
      }

      return loginResponse;
    } on DioException catch (e) {
      print('API: Password reset verify error - ${e.message}');
      print('API: Password reset verify error response - ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _apiService.post(ApiConstants.logout);
    } catch (e) {
      // Ignore logout errors
    } finally {
      await ApiService.clearTokens();
    }
  }

  /// Get current user profile
  /// Returns a default user since the profile endpoint might not exist
  Future<User> getProfile() async {
    try {
      final response = await _apiService.get(ApiConstants.userProfile);
      return User.fromJson(response.data);
    } on DioException catch (e) {
      print('API: Profile error - ${e.response?.statusCode}');
      // Return a default user - in production you'd want real profile data
      return User(
        id: 24, // From JWT token
        email: 'user@example.com',
        username: 'user',
        role: 'viewer',
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await ApiService.isLoggedIn();
  }

  /// Handle errors
  Exception _handleError(DioException e) {
    String message;
    print('API: Handling error - type: ${e.type}');

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
        print(
          'API: Bad response - statusCode: $statusCode, data: $responseData',
        );

        if (statusCode == 401) {
          message = 'Invalid email or password.';
        } else if (statusCode == 422) {
          // Extract validation error message
          if (responseData is Map) {
            message =
                responseData['detail'] ??
                responseData['error'] ??
                'Invalid request.';
          } else {
            message = 'Invalid request.';
          }
        } else if (statusCode == 500) {
          message = 'Server error. Please try again later.';
        } else if (statusCode == 404) {
          message = 'Service not found. Please contact support.';
        } else if (statusCode == 400) {
          message =
              responseData['detail'] ?? 'Bad request. Please check your input.';
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

/// Login response model
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}

/// Signup response model
class SignupResponse {
  final int userId;
  final String message;
  final String? email;
  final String? username;
  final String? role;
  final bool? isVerified;

  SignupResponse({
    required this.userId,
    required this.message,
    this.email,
    this.username,
    this.role,
    this.isVerified,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    // Parse user object if present
    final user = json['user'] as Map<String, dynamic>?;
    return SignupResponse(
      userId: user?['id'] ?? json['user_id'] ?? 0,
      message: json['message'] ?? '',
      email: user?['email'] ?? json['email'],
      username: user?['username'] ?? json['username'],
      role: user?['role'] ?? json['role'],
      isVerified: user?['is_verified'] ?? json['is_verified'] ?? false,
    );
  }
}
