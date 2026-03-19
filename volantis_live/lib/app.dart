import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/onboarding/presentation/providers/onboarding_provider.dart';
import 'features/home/presentation/providers/home_provider.dart';
import 'features/streams/presentation/providers/streams_provider.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'features/splash/presentation/splash_screen.dart';

/// Main App Widget with GoRouter navigation
class VolantisLiveApp extends StatefulWidget {
  const VolantisLiveApp({super.key});

  @override
  State<VolantisLiveApp> createState() => _VolantisLiveAppState();
}

class _VolantisLiveAppState extends State<VolantisLiveApp> {
  late final AuthProvider _authProvider;
  late final OnboardingProvider _onboardingProvider;
  AppRouter? _appRouter;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _onboardingProvider = OnboardingProvider();

    // Initialize providers in background
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    // Initialize onboarding first
    await _onboardingProvider.init();
    // Then initialize auth
    await _authProvider.init();

    // Create router after providers are initialized
    if (mounted) {
      setState(() {
        _appRouter = AppRouter(
          authProvider: _authProvider,
          onboardingProvider: _onboardingProvider,
        );
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<OnboardingProvider>.value(
          value: _onboardingProvider,
        ),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => StreamsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: _isInitialized && _appRouter != null
          ? MaterialApp.router(
              title: 'VolantisLive',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              routerConfig: _appRouter!.router,
            )
          : MaterialApp(
              title: 'VolantisLive',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              // Use SplashScreen while initializing
              home: const SplashScreen(),
            ),
    );
  }
}
