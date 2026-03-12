import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';

/// API Service for making HTTP requests
class ApiService {
  late final Dio _dio;
  static ApiService? _instance;
  
  // In-memory fallback for when secure storage is unavailable
  static String? _memoryToken;
  static String? _memoryRefreshToken;
  static String? _memoryUserId;
  
  // Secure storage - initialized lazily
  static FlutterSecureStorage? get _secureStorage {
    try {
      return const FlutterSecureStorage();
    } catch (e) {
      return null;
    }
  }

  // Storage keys
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': ApiConstants.contentType,
          'Accept': ApiConstants.jsonContentType,
        },
      ),
    );

    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) {
        // ignore: avoid_print
        print('API: $object');
      },
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await getToken();
          if (token != null) {
            options.headers[ApiConstants.authorization] =
                '${ApiConstants.bearer} $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle token refresh on 401
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the request
              final options = error.requestOptions;
              final token = await getToken();
              options.headers[ApiConstants.authorization] =
                  '${ApiConstants.bearer} $token';
              try {
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  // Token management with secure storage (with in-memory fallback)
  static Future<void> saveToken(String token) async {
    _memoryToken = token;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        await storage.write(key: _tokenKey, value: token);
      }
    } catch (e) {
      // Fallback to in-memory storage
    }
  }

  static Future<String?> getToken() async {
    if (_memoryToken != null) return _memoryToken;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        return await storage.read(key: _tokenKey);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveRefreshToken(String token) async {
    _memoryRefreshToken = token;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        await storage.write(key: _refreshTokenKey, value: token);
      }
    } catch (e) {
      // Fallback to in-memory storage
    }
  }

  static Future<String?> getRefreshToken() async {
    if (_memoryRefreshToken != null) return _memoryRefreshToken;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        return await storage.read(key: _refreshTokenKey);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveUserId(String userId) async {
    _memoryUserId = userId;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        await storage.write(key: _userIdKey, value: userId);
      }
    } catch (e) {
      // Fallback to in-memory storage
    }
  }

  static Future<String?> getUserId() async {
    if (_memoryUserId != null) return _memoryUserId;
    try {
      final storage = _secureStorage;
      if (storage != null) {
        return await storage.read(key: _userIdKey);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> _refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Content-Type': ApiConstants.contentType},
        ),
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'];
        await saveToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearTokens() async {
    // Clear memory
    _memoryToken = null;
    _memoryRefreshToken = null;
    _memoryUserId = null;
    
    try {
      final storage = _secureStorage;
      if (storage != null) {
        await storage.delete(key: _tokenKey);
        await storage.delete(key: _refreshTokenKey);
        await storage.delete(key: _userIdKey);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // HTTP Methods
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> uploadFile(
    String path, {
    required FormData formData,
    Options? options,
    Function(int, int)? onSendProgress,
  }) async {
    return _dio.post(
      path,
      data: formData,
      options: options,
      onSendProgress: onSendProgress,
    );
  }
}