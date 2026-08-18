import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/connect/presentation/screens/connect_room_screen.dart';
import '../../features/connect/presentation/providers/meeting_provider.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/company_details_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/categories/presentation/screens/set_preferences_screen.dart';
import '../../features/streams/presentation/screens/stream_player_screen.dart';
import '../../features/home/presentation/screens/playlist_player_screen.dart';
import '../../routes/main_screen.dart';
import '../../routes/creator_main_screen.dart';
import '../../services/push_notification_service.dart';
import '../../services/app_update_manager.dart';

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
  static const String connect = '/connect';
  static const String streams = '/streams';
  static const String profile = '/profile';
  static const String downloads = '/downloads';
  static const String companyDetails = '/company/:slug';
  static const String playlist = '/company/:slug/playlist/:playlistSlug';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _creatorShellNavigatorKey =
    GlobalKey<NavigatorState>();

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
        navigatorKey: _shellNavigatorKey,
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
            path: '/connect',
            name: 'connect',
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
      ShellRoute(
        navigatorKey: _creatorShellNavigatorKey,
        builder: (context, state, child) => _CreatorShell(child: child),
        routes: [
          GoRoute(
            path: '/creator',
            name: 'creator',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/creator/streams',
            name: 'creatorStreams',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/creator/profile',
            name: 'creatorProfile',
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
          return _CompanyDetailsHandler(
            companySlug: companySlug,
            isFromDeepLink: true,
          );
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
        path: '/company/:slug/playlist/:playlistSlug',
        name: 'playlistPlayer',
        builder: (context, state) {
          final companySlug = state.pathParameters['slug'] ?? '';
          final playlistSlug = state.pathParameters['playlistSlug'] ?? '';
          final isrecording =
              state.uri.queryParameters['is_recording'] == 'true'
              ? true
              : false;
          return _PlaylistHandler(
            companySlug: companySlug,
            playlistSlug: playlistSlug,
            isrecording: isrecording,
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
      GoRoute(
        path: '/connect/room/:meetingId',
        name: 'connectRoom',
        builder: (context, state) {
          final args = state.extra as MeetingJoinArgs?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid room arguments')),
            );
          }
          return ConnectRoomScreen(
            url: args.url,
            token: args.token,
            displayName: args.displayName,
            meetingCode: args.meetingCode,
          );
        },
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
      final isCreator = authProvider.isCreator;
      final hasCompletedOnboarding = context
          .read<OnboardingProvider>()
          .hasCompletedOnboarding;
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
        if (!AppUpdateManager().isUpdateCheckComplete) {
          print('AppRouter: Update check not complete, staying on splash');
          return null; // stay on splash
        }

        if (!hasCompletedOnboarding) {
          print('AppRouter: Redirecting to onboarding');
          return AppRoutes.onboarding;
        }

        if (!isLoggedIn) {
          print('AppRouter: Redirecting to login');
          return AppRoutes.login;
        }

        final homeRoute = isCreator ? '/creator' : AppRoutes.home;
        print('AppRouter: Redirecting from splash to $homeRoute');
        return homeRoute;
      }

      if (currentPath == AppRoutes.onboarding && hasCompletedOnboarding) {
        return isCreator ? '/creator' : AppRoutes.home;
      }

      if (currentPath == AppRoutes.login ||
          currentPath == AppRoutes.register ||
          currentPath == AppRoutes.forgotPassword) {
        if (isLoggedIn) {
          return isCreator ? '/creator' : AppRoutes.home;
        }
        return null;
      }

      if (currentPath.startsWith('/home')) {
        print(
          'AppRouter: /home check - currentPath: $currentPath, contains /guest: ${currentPath.contains('/guest')}',
        );
        print('AppRouter: Allowing /home');
        return null;
      }

      if (currentPath.startsWith('/creator')) {
        if (!hasCompletedOnboarding) return AppRoutes.onboarding;
        if (!isLoggedIn) return AppRoutes.login;
        print('AppRouter: Allowing /creator');
        return null;
      }

      if (currentPath.startsWith('/connect')) {
        print('AppRouter: Allowing /connect');
        return null;
      }

      if (currentPath.startsWith('/profile')) {
        print('AppRouter: Allowing /profile');
        return null;
      }

      if (currentPath.startsWith('/streams')) {
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
    if (authProvider.isCreator) {
      final tabs = ['/creator', '/creator/streams', '/creator/profile'];
      router.go(tabs[tabIndex.clamp(0, tabs.length - 1)]);
    } else {
      final tabs = ['home', 'connect'];
      router.go('/${tabs[tabIndex.clamp(0, tabs.length - 1)]}');
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
    if (location.startsWith('/connect')) return 1;
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
        final tabs = ['home', 'connect'];
        context.go('/${tabs[index]}');
      },
    );
  }
}

class _CreatorShell extends StatefulWidget {
  final Widget child;

  const _CreatorShell({required this.child});

  @override
  State<_CreatorShell> createState() => _CreatorShellState();
}

class _CreatorShellState extends State<_CreatorShell> {
  int _getIndexFromLocation(String location) {
    if (location.startsWith('/creator/streams')) return 1;
    if (location.startsWith('/creator/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _getIndexFromLocation(location);

    return CreatorMainScreen(
      currentIndex: currentIndex,
      onTabChanged: (index) {
        final tabs = ['/creator', '/creator/streams', '/creator/profile'];
        context.go(tabs[index]);
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
/// Routes: /company/{slug} (from deep links like volantislive.com/creator_slug)
class _CompanyDetailsHandler extends StatelessWidget {
  final String companySlug;
  final bool isFromDeepLink;

  const _CompanyDetailsHandler({
    required this.companySlug,
    this.isFromDeepLink = true,
  });

  @override
  Widget build(BuildContext context) {
    return CompanyDetailsScreen(
      companySlug: companySlug,
      isFromDeepLink: isFromDeepLink,
    );
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
    return StreamPlayerScreen(companySlug: companySlug);
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

class _PlaylistHandler extends StatelessWidget {
  final String companySlug;
  final String playlistSlug;
  final bool isrecording;

  const _PlaylistHandler({
    required this.companySlug,
    required this.playlistSlug,
    this.isrecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return PlaylistPlayerScreen(
      companySlug: companySlug,
      playlistSlug: playlistSlug,
      is_recording: isrecording,
    );
  }
}
