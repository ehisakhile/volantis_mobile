import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

/// Platform utilities for LiveKit screen sharing and platform checks
class PlatformUtils {
  /// Check if running on Android
  static bool isAndroid() => !kIsWeb && Platform.isAndroid;

  /// Check if running on iOS
  static bool isIOS() => !kIsWeb && Platform.isIOS;

  /// Check if running on desktop (Windows, macOS, Linux)
  static bool isDesktop() =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if running on mobile (Android or iOS)
  static bool isMobile() => isAndroid() || isIOS();

  /// Check if running on web
  static bool isWeb() => kIsWeb;

  /// Setup Android foreground service for screen sharing
  /// Returns true if setup was successful, false otherwise
  static Future<bool> setupAndroidScreenShare() async {
    if (!isAndroid()) return true;

    try {
      bool hasPermissions = await FlutterBackground.hasPermissions;

      // Initialize FlutterBackground if not already done
      if (!hasPermissions) {
        const androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: 'Screen Sharing',
          notificationText: 'VolantisLive is sharing the screen.',
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'livekit_ic_launcher',
            defType: 'mipmap',
          ),
        );

        hasPermissions =
            await FlutterBackground.initialize(androidConfig: androidConfig);
      }

      // Enable background execution if permissions are granted
      if (hasPermissions && !FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
      }

      return hasPermissions;
    } catch (e) {
      print('Error setting up Android screen share: $e');
      return false;
    }
  }

  /// Request screen capture permission on Android
  /// Returns true if permission was granted, false otherwise
  static Future<bool> requestCapturePermission() async {
    if (!isAndroid()) return true;

    try {
      bool hasPermission = await Helper.requestCapturePermission();
      return hasPermission;
    } catch (e) {
      print('Error requesting capture permission: $e');
      return false;
    }
  }

  /// Cleanup Android background service after screen sharing
  static Future<void> disableAndroidScreenShare() async {
    if (!isAndroid()) return;

    try {
      // Note: We don't disable background execution immediately as it might
      // interfere with audio if the user continues in the call.
      // The OS will handle cleanup when the app is backgrounded or closed.
    } catch (e) {
      print('Error disabling Android screen share: $e');
    }
  }
}
