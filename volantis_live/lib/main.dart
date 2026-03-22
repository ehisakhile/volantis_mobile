import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'services/offline_service.dart';
import 'services/encryption_service.dart';
import 'features/recordings/data/services/recordings_downloads_service.dart';
import 'services/download_manager.dart';
import 'package:dio/dio.dart';
import 'core/constants/api_constants.dart';

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

  runApp(const VolantisLiveApp());
}
