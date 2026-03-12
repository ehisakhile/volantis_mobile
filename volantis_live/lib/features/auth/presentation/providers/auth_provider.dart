import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  otpPending, // Waiting for email verification
}

/// Auth provider for managing authentication state
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  String? _pendingUserId; // For OTP verification after signup

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  String? get pendingUserId => _pendingUserId;

  /// Initialize auth state
  Future<void> init() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        _user = await _repository.getProfile();
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.login(email, password);
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