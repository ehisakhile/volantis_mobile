import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for storing onboarding state
class OnboardingKeys {
  OnboardingKeys._();

  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String onboardingVersion = 'onboarding_version';
}

/// Onboarding state enum
enum OnboardingStatus { initial, loading, completed, notCompleted, error }

/// Onboarding provider for managing onboarding state
/// Tracks whether new users have completed the onboarding flow
class OnboardingProvider extends ChangeNotifier {
  OnboardingStatus _status = OnboardingStatus.initial;
  bool _hasCompletedOnboarding = false;
  String? _errorMessage;

  // Current onboarding version - increment when onboarding changes
  static const int currentOnboardingVersion = 1;

  // Getters
  OnboardingStatus get status => _status;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isLoading => _status == OnboardingStatus.loading;
  String? get errorMessage => _errorMessage;

  /// Initialize and check onboarding status
  Future<void> init() async {
    _status = OnboardingStatus.loading;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if onboarding has been completed
      final hasCompleted =
          prefs.getBool(OnboardingKeys.hasCompletedOnboarding) ?? false;

      // Check if onboarding version changed (meaning users need to see new onboarding)
      final savedVersion = prefs.getInt(OnboardingKeys.onboardingVersion) ?? 0;

      // If version changed, reset onboarding for all users
      if (savedVersion < currentOnboardingVersion) {
        _hasCompletedOnboarding = false;
        await prefs.setInt(
          OnboardingKeys.onboardingVersion,
          currentOnboardingVersion,
        );
      } else {
        _hasCompletedOnboarding = hasCompleted;
      }

      _status = _hasCompletedOnboarding
          ? OnboardingStatus.completed
          : OnboardingStatus.notCompleted;
    } catch (e) {
      _status = OnboardingStatus.error;
      _errorMessage = e.toString();
      // Default to not completed on error
      _hasCompletedOnboarding = false;
    }

    notifyListeners();
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingKeys.hasCompletedOnboarding, true);
      await prefs.setInt(
        OnboardingKeys.onboardingVersion,
        currentOnboardingVersion,
      );

      _hasCompletedOnboarding = true;
      _status = OnboardingStatus.completed;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Reset onboarding (for testing or re-onboarding)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingKeys.hasCompletedOnboarding, false);

      _hasCompletedOnboarding = false;
      _status = OnboardingStatus.notCompleted;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Clear any error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
