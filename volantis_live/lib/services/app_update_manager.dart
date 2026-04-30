import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';

enum UpdateDecision { updateNow, later }

class AppUpdateManager {
  static final AppUpdateManager _instance = AppUpdateManager._internal();
  factory AppUpdateManager() => _instance;
  AppUpdateManager._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  static const _keyMinSupportedVersion = 'min_supported_version';
  static const _keyLatestVersion = 'latest_version';
  static const _keyForceUpdateMessage = 'force_update_message';
  static const _keyUpdateMessage = 'update_message';
  static const _keyAppStoreUrl = 'app_store_url';
  static const _keyPlayStoreUrl = 'play_store_url';

  static const _defaults = {
    _keyMinSupportedVersion: '1.0.0',
    _keyLatestVersion: '1.0.5',
    _keyForceUpdateMessage: 'Please update to continue using the app.',
    _keyUpdateMessage:
        'A new version is available. Update for the best experience.',
    _keyAppStoreUrl: 'https://apps.apple.com/us/app/volantislive/id6762115839',
    _keyPlayStoreUrl:
        'https://play.google.com/store/apps/details?id=com.volantislive.volantislive',
  };

  String? _currentVersion;
  bool _isInitialized = false;
  bool updateCheckComplete = false;
  bool get isUpdateCheckComplete => updateCheckComplete;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      await _remoteConfig.setDefaults(_defaults);

      try {
        await _remoteConfig.fetch();
        await _remoteConfig.activate();
      } catch (e) {
        debugPrint('[AppUpdateManager] Fetch error (using defaults): $e');
      }

      _isInitialized = true;
      debugPrint(
        '[AppUpdateManager] Initialized. Current version: $_currentVersion',
      );
    } catch (e) {
      debugPrint('[AppUpdateManager] Init error: $e');
    }
  }

  Future<bool> checkForUpdates(
    BuildContext context, {
    Function? onSkipAuth,
  }) async {
    if (updateCheckComplete) {
      debugPrint('[AppUpdateManager] Update check already complete, skipping');
      return true;
    }

    if (!_isInitialized) await initialize();

    final minVersion = _remoteConfig.getString(_keyMinSupportedVersion);
    final latestVersion = _remoteConfig.getString(_keyLatestVersion);
    final forceMessage = _remoteConfig.getString(_keyForceUpdateMessage);
    final updateMessage = _remoteConfig.getString(_keyUpdateMessage);

    debugPrint(
      '[AppUpdateManager] Remote Config - minVersion: $minVersion, latestVersion: $latestVersion',
    );
    debugPrint(
      '[AppUpdateManager] Remote Config - currentVersion: $_currentVersion',
    );

    final isBelowMin = _isVersionLower(_currentVersion!, minVersion);
    final isBelowLatest = _isVersionLower(_currentVersion!, latestVersion);
    debugPrint(
      '[AppUpdateManager] isBelowMin: $isBelowMin, isBelowLatest: $isBelowLatest',
    );

    if (isBelowMin) {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          await _showForceUpdateDialog(context, forceMessage);
        }
      }
      return false;
    }

    if (_isVersionLower(_currentVersion!, latestVersion)) {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          final decision = await _showOptionalUpdatePage(
            context,
            message: updateMessage,
            latestVersion: latestVersion,
          );
          if (decision == UpdateDecision.updateNow) {
            updateCheckComplete = true;
            await _openStore();
          } else if (decision == UpdateDecision.later) {
            updateCheckComplete = true;
            return false;
          }
        }
      }
    }

    updateCheckComplete = true;
    return true;
  }

  bool _isVersionLower(String current, String target) {
    try {
      final cleanCurrent = current.split('+').first.split('-').first;
      final cleanTarget = target.split('+').first.split('-').first;

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final targetParts = cleanTarget.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final t = i < targetParts.length ? targetParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
      return false;
    } catch (e) {
      debugPrint('[AppUpdateManager] Version compare error: $e');
      return false;
    }
  }

  Future<void> _showForceUpdateDialog(
    BuildContext context,
    String message,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.system_update,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Update Required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      updateCheckComplete = true;
                      _openStore();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<UpdateDecision> _showOptionalUpdatePage(
    BuildContext context, {
    required String message,
    required String latestVersion,
  }) async {
    final decision = await Navigator.of(context).push<UpdateDecision>(
      MaterialPageRoute(
        builder:
            (_) => _UpdateAvailablePage(
              message: message,
              currentVersion: _currentVersion ?? 'Unknown',
              latestVersion: latestVersion,
            ),
      ),
    );
    return decision ?? UpdateDecision.later;
  }

  Future<void> _openStore() async {
    final String url;
    if (Platform.isIOS) {
      url = _remoteConfig.getString(_keyAppStoreUrl);
    } else {
      url = _remoteConfig.getString(_keyPlayStoreUrl);
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? get currentVersion => _currentVersion;
}

class _UpdateAvailablePage extends StatelessWidget {
  final String message;
  final String currentVersion;
  final String latestVersion;
  final Function(UpdateDecision)? onDecision;

  const _UpdateAvailablePage({
    required this.message,
    required this.currentVersion,
    required this.latestVersion,
    this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.system_update,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentVersion,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      latestVersion,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    onDecision?.call(UpdateDecision.updateNow);
                    Navigator.of(context).pop(UpdateDecision.updateNow);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Update Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: () {
                    onDecision?.call(UpdateDecision.later);
                    Navigator.of(context).pop(UpdateDecision.later);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}