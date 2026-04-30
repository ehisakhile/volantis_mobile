import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/offline_service.dart';
import 'services/encryption_service.dart';
import 'services/connectivity_service.dart';
import 'features/recordings/data/services/recordings_downloads_service.dart';
import 'services/download_manager.dart';
import 'services/update_service.dart';
import 'services/review_manager.dart';
import 'services/app_update_manager.dart';
import 'package:dio/dio.dart';
import 'core/constants/api_constants.dart';

const String _iOSApiKey = 'AIzaSyA_hsxRK1s5lmbT67NuSKnwFdLy6mdcDxg';
const String _iOSProjectId = 'volantis-live';
const String _iOSGcmSenderId = '581818664023';
const String _iOSGoogleAppId = '1:581818664023:ios:cacdc9dd77f20c270b4f12';
const String _iOSStorageBucket = 'volantis-live.firebasestorage.app';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize just_audio_background for background playback (recordings)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Volantis Audio',
    androidNotificationOngoing: true,
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize offline service
  await OfflineService.instance.init();

  // Initialize encryption service
  await EncryptionService.instance.init();

  // Initialize connectivity service for offline support
  await ConnectivityService().init();

  // Initialize recordings downloads service
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(
        milliseconds: ApiConstants.connectionTimeout,
      ),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.jsonContentType,
      },
    ),
  );
  await RecordingsDownloadsService.init(dio);

  // Initialize download manager
  await DownloadManager.init(dio);

  // Check for Shorebird updates on app start
  try {
    await UpdateService().checkAndUpdate();
  } catch (error) {
    print('Shorebird update check failed: $error');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: _iOSApiKey,
        projectId: _iOSProjectId,
        messagingSenderId: _iOSGcmSenderId,
        appId: _iOSGoogleAppId,
        storageBucket: _iOSStorageBucket,
      ),
    );
  } catch (error) {
    print('Firebase initialization failed: $error');
  }

  // Initialize app update manager (fetch remote config only)
  try {
    await AppUpdateManager().initialize();
  } catch (error) {
    print('AppUpdateManager initialization failed: $error');
    AppUpdateManager().updateCheckComplete = true;
  }

  // Initialize in-app review manager
  ReviewManager().incrementSessionAndMaybePrompt();

  runApp(const VolantisLiveApp());
}
