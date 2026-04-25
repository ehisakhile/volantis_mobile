import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../services/connectivity_service.dart';

/// Auth state
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  otpPending, // Waiting for email verification
  offlineAuthenticated, // Authenticated but offline - limited features
}

/// Auth provider for managing authentication state
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  final ConnectivityService _connectivityService = ConnectivityService();

  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  String? _pendingUserId; // For OTP verification after signup
  String? _pendingEmail; // For password reset flow
  bool _isOffline = false; // Track if user is offline

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _state == AuthState.authenticated ||
      _state == AuthState.offlineAuthenticated;
  bool get isLoading => _state == AuthState.loading;
  String? get pendingUserId => _pendingUserId;
  String? get pendingEmail => _pendingEmail;
  bool get isOffline => _isOffline;

  bool get isCreator {
    if (_user == null) return false;
    final role = _user?.role?.toLowerCase() ?? '';
    final hasCompany = _user?.companyId != null;
    return role == 'creator' || role == 'host' || hasCompany;
  }

  /// Initialize auth state
  Future<void> init() async {
    _state = AuthState.loading;
    notifyListeners();
    print('AuthProvider: init() started, state = loading');

    try {
      final isLoggedIn = await _repository.isLoggedIn();
      print('AuthProvider: isLoggedIn result: $isLoggedIn');

      if (isLoggedIn) {
        print('AuthProvider: User is logged in, checking connectivity...');
        // Check connectivity
        final isConnected = await _connectivityService.isConnected();
        _isOffline = !isConnected;
        print(
          'AuthProvider: isConnected: $isConnected, isOffline: $_isOffline',
        );

        if (isConnected) {
          // Online - try to fetch profile
          try {
            _user = await _repository.getProfile();
            _state = AuthState.authenticated;
            print(
              'AuthProvider: Online auth successful, state = authenticated',
            );
          } catch (e) {
            // Network error but token exists - allow offline access
            _state = AuthState.offlineAuthenticated;
            _errorMessage = 'Working offline - some features may be limited';
            print(
              'AuthProvider: Network error but token exists, state = offlineAuthenticated',
            );
          }
        } else {
          // Offline but token exists - allow access to offline features
          _state = AuthState.offlineAuthenticated;
          _errorMessage = 'You are offline. Accessing downloaded content only.';
          print(
            'AuthProvider: Offline with token, state = offlineAuthenticated',
          );
        }
      } else {
        _state = AuthState.unauthenticated;
        print('AuthProvider: Not logged in, state = unauthenticated');
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
      _errorMessage = e.toString();
      print('AuthProvider: Exception during init: $e, state = unauthenticated');
    }

    notifyListeners();
    print('AuthProvider: init() completed, final state = $_state');
  }

  /// Try to refresh profile when coming back online
  Future<void> refreshProfile() async {
    if (_isOffline) {
      final isConnected = await _connectivityService.isConnected();
      if (isConnected) {
        try {
          _user = await _repository.getProfile();
          _state = AuthState.authenticated;
          _isOffline = false;
          _errorMessage = null;
          notifyListeners();
        } catch (e) {
          // Keep offline state if profile fetch fails
        }
      }
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.login(email, password);
      // After successful login, fetch the user profile
      _user = await _repository.getProfile();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Signup new user
  Future<bool> signup(String email, String username, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.signup(email, username, password);
      _pendingUserId = response.userId.toString();
      _state = AuthState.otpPending;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Verify email with OTP
  Future<bool> verifyEmail(String otp) async {
    if (_pendingUserId == null) {
      _errorMessage = 'No pending user ID';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.verifyEmail(_pendingUserId!, otp);
      _pendingUserId = null;
      // After successful verification, redirect to login
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestPasswordReset(email);
      _pendingEmail = email;
      _state = AuthState.otpPending;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Verify password reset OTP and set new password
  /// Returns true and auto-logs in the user on success
  Future<bool> verifyPasswordReset(String otp, String newPassword) async {
    if (_pendingEmail == null) {
      _errorMessage = 'No pending email for password reset';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // This returns LoginResponse with access token for auto-login
      await _repository.verifyPasswordReset(_pendingEmail!, otp, newPassword);

      // Fetch user profile to complete the login
      _user = await _repository.getProfile();
      _pendingEmail = null;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile(String username) async {
    if (!isAuthenticated) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateProfile(username);

      // Update the local user object with new username
      if (_user != null) {
        _user = User(
          id: _user!.id,
          email: _user!.email,
          username: username,
          role: _user!.role,
          isActive: _user!.isActive,
          createdAt: _user!.createdAt,
        );
      }

      _state = _isOffline
          ? AuthState.offlineAuthenticated
          : AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = _isOffline
          ? AuthState.offlineAuthenticated
          : AuthState.authenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    if (!isAuthenticated) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteAccount();

      // Clear all auth data
      _user = null;
      _pendingUserId = null;
      _pendingEmail = null;
      _isOffline = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = _isOffline
          ? AuthState.offlineAuthenticated
          : AuthState.authenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _repository.logout();
    } catch (e) {
      // Ignore logout errors
    } finally {
      _user = null;
      _pendingUserId = null;
      _pendingEmail = null;
      _isOffline = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }
}
