import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/company_details_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/categories/presentation/screens/set_preferences_screen.dart';
import '../../routes/main_screen.dart';
import '../../services/push_notification_service.dart';

/// Route names
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyOtp = '/verify-otp';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String streams = '/streams';
  static const String profile = '/profile';
  static const String downloads = '/downloads';
  static const String companyDetails = '/company/:slug';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App Router configuration
class AppRouter {
  final AuthProvider authProvider;
  final OnboardingProvider onboardingProvider;

  AppRouter({required this.authProvider, required this.onboardingProvider}) {
    _setupNotificationHandler();
  }

  void _setupNotificationHandler() {
    PushNotificationService.instance.onNotificationTap = (data) {
      handleNotificationNavigation(data.route, data.data);
    };
  }

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) =>
            OnboardingScreen(onComplete: () => context.go(AppRoutes.login)),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        name: 'verifyOtp',
        builder: (context, state) => const VerifyOtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/home/guest',
            name: 'homeGuest',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/creator',
            name: 'creator',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/streams',
            name: 'streams',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
      GoRoute(
        path: '/stream/:id',
        name: 'streamDetail',
        builder: (context, state) {
          final streamSlug = state.pathParameters['id'] ?? '';
          return _StreamToCompanyHandler(streamSlug: streamSlug);
        },
      ),
      GoRoute(
        path: '/channel/:id',
        name: 'channelDetail',
        builder: (context, state) {
          final channelId = state.pathParameters['id'] ?? '';
          return _ChannelDeepLinkHandler(channelId: channelId);
        },
      ),
      GoRoute(
        path: '/company/:slug',
        name: 'companyDetails',
        builder: (context, state) {
          final companySlug = state.pathParameters['slug'] ?? '';
          return _CompanyDetailsHandler(companySlug: companySlug);
        },
      ),
      GoRoute(
        path: '/company/:slug/stream/:streamSlug',
        name: 'streamPlayer',
        builder: (context, state) {
          final companySlug = state.pathParameters['slug'] ?? '';
          final streamSlug = state.pathParameters['streamSlug'] ?? '';
          return _StreamPlayerHandler(
            companySlug: companySlug,
            streamSlug: streamSlug,
          );
        },
      ),
      GoRoute(
        path: '/company/:slug/recording/:id',
        name: 'recordingViewer',
        builder: (context, state) {
          final companySlug = state.pathParameters['slug'] ?? '';
          final recordingId = state.pathParameters['id'] ?? '';
          return _RecordingHandler(
            companySlug: companySlug,
            recordingId: recordingId,
          );
        },
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/set-preferences',
        name: 'setPreferences',
        builder: (context, state) => const SetPreferencesScreen(),
      ),
    ],
    redirect: (context, state) {
      // Check if auth provider has completed initialization
      // If auth state is still initial or loading, wait for it to complete
      final authState = authProvider.state;
      print('AppRouter: Redirect called - authState: $authState');

      if (authState == AuthState.initial || authState == AuthState.loading) {
        print(
          'AppRouter: Auth still initializing, returning null (no redirect)',
        );
        return null; // Wait for auth initialization to complete
      }

      final isLoggedIn = authProvider.isAuthenticated;
      final hasCompletedOnboarding = onboardingProvider.hasCompletedOnboarding;
      final isLoading = authProvider.isLoading || onboardingProvider.isLoading;

      print(
        'AppRouter: isLoggedIn: $isLoggedIn, hasCompletedOnboarding: $hasCompletedOnboarding, isLoading: $isLoading',
      );

      if (isLoading) {
        print('AppRouter: Still loading, returning null');
        return null;
      }

      final currentPath = state.matchedLocation;
      print('AppRouter: currentPath: $currentPath');

      if (currentPath == '/' || currentPath == AppRoutes.splash) {
        if (!hasCompletedOnboarding) {
          print('AppRouter: Redirecting to onboarding');
          return AppRoutes.onboarding;
        }
        if (!isLoggedIn) {
          print('AppRouter: Not logged in, redirecting to login');
          return AppRoutes.login;
        }
        final isCreator = authProvider.isCreator;
        final destination = isCreator ? '/creator' : AppRoutes.home;
        print(
          'AppRouter: Logged in and onboarding complete, redirecting to $destination',
        );
        return destination;
      }

      if (currentPath == AppRoutes.onboarding && hasCompletedOnboarding) {
        final isCreator = authProvider.isCreator;
        return isLoggedIn
            ? (isCreator ? '/creator' : AppRoutes.home)
            : AppRoutes.login;
      }

      if (currentPath == AppRoutes.login ||
          currentPath == AppRoutes.register ||
          currentPath == AppRoutes.forgotPassword) {
        if (!hasCompletedOnboarding) return AppRoutes.onboarding;
        if (isLoggedIn) {
          return authProvider.isCreator ? '/creator' : AppRoutes.home;
        }
        return null;
      }

      if (currentPath.startsWith('/home')) {
        print(
          'AppRouter: /home check - currentPath: $currentPath, contains /guest: ${currentPath.contains('/guest')}',
        );
        if (!hasCompletedOnboarding) return AppRoutes.onboarding;
        if (!isLoggedIn && !currentPath.contains('/guest')) {
          print(
            'AppRouter: Redirecting to login - not logged in and not guest',
          );
          return AppRoutes.login;
        }
        print('AppRouter: Allowing /home (logged in or guest mode)');
        return null;
      }

      if (currentPath.startsWith('/streams') ||
          currentPath.startsWith('/profile')) {
        if (!hasCompletedOnboarding) return AppRoutes.onboarding;
        if (!isLoggedIn) return AppRoutes.login;
        return null;
      }

      if (currentPath.startsWith('/stream/')) {
        if (!hasCompletedOnboarding) return AppRoutes.onboarding;
        return null;
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );

  void navigateToMain({int tabIndex = 0}) {
    final isCreator = authProvider.isCreator;
    if (isCreator) {
      final creatorTabs = ['creator', 'home', 'profile'];
      router.go('/${creatorTabs[tabIndex]}');
    } else {
      final tabs = ['home', 'streams', 'profile'];
      router.go('/${tabs[tabIndex]}');
    }
  }

  void navigateToStream(String streamId) => router.push('/stream/$streamId');
  void navigateToChannel(String channelId) =>
      router.push('/channel/$channelId');

  void handleNotificationNavigation(String? route, Map<String, dynamic>? data) {
    if (route == null) return;
    switch (route) {
      case 'stream':
        if (data?['id'] != null) navigateToStream(data!['id'].toString());
        break;
      case 'channel':
        if (data?['id'] != null) navigateToChannel(data!['id'].toString());
        break;
      default:
        navigateToMain();
    }
  }
}

class _MainShell extends StatefulWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _getIndexFromLocation(String location) {
    if (location.startsWith('/streams')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _getIndexFromLocation(location);

    return MainScreen(
      currentIndex: currentIndex,
      onTabChanged: (index) {
        final tabs = ['home', 'streams', 'profile'];
        context.go('/${tabs[index]}');
      },
    );
  }
}

/// Handler for stream - redirects to discover since we need company slug
class _StreamToCompanyHandler extends StatelessWidget {
  final String streamSlug;

  const _StreamToCompanyHandler({required this.streamSlug});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/home');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Deep link handler for channel
class _ChannelDeepLinkHandler extends StatelessWidget {
  final String channelId;

  const _ChannelDeepLinkHandler({required this.channelId});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/home');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Deep link handler for company details
class _CompanyDetailsHandler extends StatelessWidget {
  final String companySlug;

  const _CompanyDetailsHandler({required this.companySlug});

  @override
  Widget build(BuildContext context) {
    return CompanyDetailsScreen(companySlug: companySlug);
  }
}

class _StreamPlayerHandler extends StatelessWidget {
  final String companySlug;
  final String streamSlug;

  const _StreamPlayerHandler({
    required this.companySlug,
    required this.streamSlug,
  });

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.push('/stream/$streamSlug?companySlug=$companySlug');
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _RecordingHandler extends StatelessWidget {
  final String companySlug;
  final String recordingId;

  const _RecordingHandler({
    required this.companySlug,
    required this.recordingId,
  });

  @override
  Widget build(BuildContext context) {
    return _CompanyDetailsHandler(companySlug: companySlug);
  }
}
