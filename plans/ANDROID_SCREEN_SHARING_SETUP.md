# Android Screen Sharing Setup Guide

## Overview

This guide explains the Android screen sharing setup for the Connect feature. The implementation uses `flutter_background` package to manage a foreground service for screen capture, and `flutter_webrtc` for capture permission requests.

## Prerequisites

The following dependencies are already added to `pubspec.yaml`:
- `flutter_background: ^1.3.1`
- `flutter_webrtc: ^1.4.0`
- `livekit_client: ^2.8.1`

## AndroidManifest.xml Configuration

The `android/app/src/main/AndroidManifest.xml` already includes the required permissions and service declarations:

### Required Permissions

```xml
<!-- Screen capture permission for system audio -->
<uses-permission android:name="android.permission.MEDIA_PROJECTION"/>

<!-- Foreground Service Permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

### Foreground Service Declaration

```xml
<service
    android:name="de.julianassmann.flutter_background.IsolateHolderService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="mediaProjection" />
```

## Implementation Details

### Flow Chart

```
1. User taps "Share Screen" button in control bar
   ↓
2. toggleScreenShare() is called in RoomController
   ↓
3. _startScreenShare() checks if running on Android
   ↓
4. PlatformUtils.requestCapturePermission() - requests media projection permission
   ↓
5. PlatformUtils.setupAndroidScreenShare() - initializes FlutterBackground service
   ↓
6. localParticipant.setScreenShareEnabled(true) - starts LiveKit screen sharing
   ↓
7. Other participants see the screen share track
```

### Key Files

#### 1. **platform_utils.dart**
Location: `lib/features/connect/presentation/utils/platform_utils.dart`

Utility class that handles:
- Platform detection (Android, iOS, desktop, web)
- Android permission requests via `flutter_webrtc.Helper`
- FlutterBackground foreground service setup
- Service cleanup after screen sharing stops

Key methods:
- `isAndroid()` - Check if running on Android
- `requestCapturePermission()` - Request media projection permission
- `setupAndroidScreenShare()` - Setup foreground service
- `disableAndroidScreenShare()` - Cleanup after screen sharing

#### 2. **room_controller.dart**
Location: `lib/features/connect/presentation/room/room_controller.dart`

Enhanced screen sharing methods:
- `_startScreenShare()` - Calls platform setup, then `setScreenShareEnabled(true)`
- `_stopScreenShare()` - Stops sharing and calls platform cleanup
- `toggleScreenShare()` - Public entry point

#### 3. **control_bar.dart**
Location: `lib/features/connect/presentation/widgets/control_bar.dart`

UI component with screen share button that calls:
- `_controller.toggleScreenShare()` when tapped

## Runtime Behavior

### On Android:

1. **Permission Request**
   - First tap of screen share button triggers native permission dialog
   - User must grant "Allow Volantis Live to capture the screen?"
   - Permission is required per-session (not persistent)

2. **Foreground Service**
   - FlutterBackground creates a persistent foreground notification
   - Notification shows: "Screen Sharing - VolantisLive is sharing the screen."
   - Notification is required by Android to keep the service running
   - User can swipe away the notification (but screen sharing continues)

3. **Screen Capture**
   - Once permission is granted and service is running, `setScreenShareEnabled(true)` starts capture
   - Audio is captured if available
   - Screen is streamed to all connected participants

4. **Stopping Screen Share**
   - User taps screen share button again
   - `setScreenShareEnabled(false)` stops capture
   - FlutterBackground service cleanup is called
   - (Note: OS handles full service cleanup when app is backgrounded/closed)

### Error Handling

If the user denies the capture permission or setup fails:
- `_onMediaError` callback is invoked with the error
- Error message is displayed as a snackbar/toast to the user
- Screen sharing button remains enabled for retry

## Notification Icon

The foreground notification uses the icon `livekit_ic_launcher` from `android/app/src/main/res/mipmap/`.

If you want to customize the notification:
1. Replace or copy your app's launcher icon to `android/app/src/main/res/mipmap/livekit_ic_launcher.png`
2. Or update the `notificationIcon` in `PlatformUtils.setupAndroidScreenShare()` to reference your custom icon

## Troubleshooting

### Issue: "Permission denied" on screen share tap

**Cause**: User denied media projection permission

**Solution**: 
- User can re-grant permission by tapping share screen again
- Or go to Settings > Apps > Permissions > Screen Recording and enable for Volantis Live

### Issue: Screen sharing starts but stops immediately

**Cause**: App crashes or service is killed

**Solution**:
- Check Android logs: `flutter logs | grep -i screen`
- Ensure device has sufficient memory
- Check for permission revocation in system settings

### Issue: Foreground notification persists after screen share stops

**Cause**: Normal behavior - OS cleanup may take a few seconds

**Solution**: No action needed. Notification will disappear when the app is backgrounded or fully closed.

### Issue: Screen sharing doesn't work on specific device

**Cause**: Device may not support screen capture (older Android versions)

**Solution**:
- Screen sharing requires Android 5.0+ (API level 21+)
- On older devices, the feature will fail with an error

## Testing Locally

```dart
// In connect_room_screen.dart, you can manually test by calling:
await _controller.toggleScreenShare(); // Start screen share
await Future.delayed(Duration(seconds: 5));
await _controller.toggleScreenShare(); // Stop screen share
```

## iOS Setup (Out of Scope - Native Work Required)

**Note**: iOS screen sharing requires a Broadcast Extension to be created in Xcode, which is outside the scope of Dart/Flutter code. Refer to:
- [flutter-webrtc iOS Screen Sharing Guide](https://github.com/flutter-webrtc/flutter-webrtc/wiki/iOS-Screen-Sharing#broadcast-extension-quick-setup)

Once the broadcast extension is set up in Xcode, screen sharing will work on iOS with the same Dart code.

## References

- [flutter_background package](https://pub.dev/packages/flutter_background)
- [flutter_webrtc screen sharing](https://github.com/flutter-webrtc/flutter-webrtc/wiki/Screen-Sharing)
- [LiveKit Client Flutter SDK](https://github.com/livekit/client-sdk-flutter)
- [Android Media Projection](https://developer.android.com/develop/background-work/services/fg-service-types#media-projection)
