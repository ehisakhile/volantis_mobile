import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:volantis_live/services/app_update_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/constants/api_constants.dart';
import 'core/deeplink/app_links_handler.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/onboarding/presentation/providers/onboarding_provider.dart';
import 'features/home/presentation/providers/home_provider.dart';
import 'features/home/presentation/providers/guest_home_provider.dart';
import 'features/streams/presentation/providers/streams_provider.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/recordings/data/services/recordings_service.dart';
import 'features/recordings/presentation/providers/recordings_provider.dart';
import 'features/downloads/presentation/providers/downloads_provider.dart';
import 'features/categories/presentation/providers/category_preferences_provider.dart';
import 'features/creator/presentation/providers/creator_provider.dart';
import 'services/download_manager.dart';
import 'features/recordings/data/services/recordings_downloads_service.dart';

/// Main App Widget with GoRouter navigation
class VolantisLiveApp extends StatefulWidget {
  const VolantisLiveApp({super.key});

  @override
  State<VolantisLiveApp> createState() => _VolantisLiveAppState();
}

class _VolantisLiveAppState extends State<VolantisLiveApp> {
  late final AuthProvider _authProvider;
  late final OnboardingProvider _onboardingProvider;
  late final RecordingsService _recordingsService;
  late final RecordingsProvider _recordingsProvider;
  AppRouter? _appRouter;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _onboardingProvider = OnboardingProvider();

    // Create recordings service and provider once
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiConstants.connectionTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiConstants.receiveTimeout,
        ),
        headers: {
          'Content-Type': ApiConstants.contentType,
          'Accept': ApiConstants.jsonContentType,
        },
      ),
    );
    _recordingsService = RecordingsService(dio);
    _recordingsProvider = RecordingsProvider(_recordingsService);

    // Listen to auth state changes to stop playback on logout
    _authProvider.addListener(_onAuthStateChanged);

    // Initialize providers in background
    _initializeProviders();
  }

  void _onAuthStateChanged() {
    // Stop playback when user logs out
    if (_authProvider.state == AuthState.unauthenticated) {
      _recordingsProvider.stopAndClose();
    }
  }

  Future<void> _initializeProviders() async {
    print('App: Starting provider initialization...');

    // Initialize onboarding first
    await _onboardingProvider.init();
    print('App: Onboarding provider initialized');

    // Then initialize auth
    await _authProvider.init();
    print('App: Auth provider initialized');

    await AppUpdateManager().initialize();
    print('App: AppUpdateManager initialized');

    // Create router after providers are initialized
    if (mounted) {
      print('App: Creating router...');
      setState(() {
        _appRouter = AppRouter(
          authProvider: _authProvider,
          onboardingProvider: _onboardingProvider,
        );
        _isInitialized = true;
        AppLinksHandler.setRouter(_appRouter!.router);
      });
      print('App: Router created, _isInitialized = true');

      AppLinksHandler.init();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    _recordingsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _appRouter == null) {
      return MaterialApp(
        title: 'VolantisLive',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _LoadingScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<OnboardingProvider>.value(
          value: _onboardingProvider,
        ),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => GuestHomeProvider()),
        ChangeNotifierProvider(create: (_) => StreamsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider<RecordingsProvider>.value(
          value: _recordingsProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadsProvider(
            RecordingsDownloadsService.instance,
            DownloadManager.instance,
            _recordingsProvider,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CategoryPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => CreatorProvider()),
        ChangeNotifierProvider<AppUpdateManager>.value(
          value: AppUpdateManager(),
        ),
      ],
      child: MaterialApp.router(
        title: 'VolantisLive',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _appRouter!.router,
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1326),
      body: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: const Color(0xFF0EA5E9),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
