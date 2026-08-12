# Flutter Mobile App Implementation Guide
## Volantis Connect — Meeting App Reference

> Revision notes: package versions and API calls below were checked against current pub.dev listings (July 2026). Corrections from the original draft are called out inline as **⚠ Corrected**.

---

## 1. Project Overview

Replicate the existing Next.js web app as a Flutter mobile app with identical design and functionality. The web app is a LiveKit-based video conferencing platform called **Volantis Connect**.

### Tech Stack

| Concern | Package | Notes |
|---|---|---|
| Framework | Flutter 3.x (stable channel) | |
| State management |  use existing
| Networking | `dio` **^5.9.x** | Preferred over `http` for interceptors (auth refresh, logging, retry, multipart uploads). |
| Video/audio | `livekit_client` **^2.8.1** | Official Flutter SDK. |
| Local storage (non-sensitive) | `shared_preferences` | Guest name history, verification email cache. |
| Secure storage (tokens) | `flutter_secure_storage` | ⚠ Added — see §4.4, storing access/refresh tokens in plain `SharedPreferences` is a security downgrade from an httpOnly cookie on web. |
| Navigation | `go_router` **^14.x** | Type-safe, declarative routing; official Flutter-team package. |
| Icons | `lucide_icons` | Closest match to the web app's `lucide-react` icons. |
| Fonts | `google_fonts` | Geist / Bricolage Grotesque. |
| Permissions | `permission_handler` | Camera/mic pre-join consent gate. |
| URL launching | `url_launcher` | Share links (Twitter/X, LinkedIn, email). |
| Code generation (optional) | `freezed` + `json_serializable` | Recommended for the model layer in §2.3 instead of hand-written `fromJson`. |

### Config

- **API base URL:** `https://api-dev.volantislive.com` — inject via `--dart-define=API_BASE_URL=...` rather than a hardcoded const (see §8.1).
- **Auth token storage key:** `vol_access_token` — ⚠ store via `flutter_secure_storage`, not `SharedPreferences` (see §4.4).
- **Brand name:** Volantis Connect (logo bundled as `assets/logo.png`).

---

## 2. API Layer

All endpoints live under the base URL above. Every authenticated request must include:

```
Authorization: Bearer <vol_access_token>
```

### 2.1 Auth Endpoints

**Login**
```
POST /auth/login
Content-Type: application/x-www-form-urlencoded
Body: email=<string>&password=<string>
```
Response:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

**Signup (individual user)**
```
POST /auth/signup/user
Content-Type: application/x-www-form-urlencoded
Body: email=<string>&password=<string>&username=<string>
```
Response: same shape as login.

**Admin/Company signup**
```
POST /auth/signup
Content-Type: multipart/form-data
Fields: company_name (required), email (required), password (required),
        company_slug (optional), company_description (optional),
        user_username (optional), logo (file, optional)
```
Response:
```json
{
  "message": "...",
  "email": "...",
  "user_id": 123,
  "company_slug": "...",
  "requires_verification": true,
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 3600,
  "user": { "id": 1, "email": "...", "username": "...", "role": "...", "is_verified": false }
}
```

**Get current user**
```
GET /auth/me
Headers: Authorization: Bearer <token>
```

**Logout**
```
POST /auth/logout
Headers: Authorization: Bearer <token>
```

**Verify email**
```
POST /auth/verify-email
Content-Type: application/x-www-form-urlencoded
Body: user_id=<number>&otp=<6-digit string>
```

**Resend verification**
```
POST /auth/resend-verification?email=<string>
Headers: Authorization: Bearer <token>
```

**Password reset**
```
POST /auth/password-reset
Content-Type: application/json
Body: { "email": "..." }
```
```
POST /auth/password-reset/verify
Content-Type: application/json
Body: { "email": "...", "otp": "...", "new_password": "..." }
```

**Check verification status**
```
GET /auth/verification-status
Headers: Authorization: Bearer <token>
Response: { "is_verified": true }
```

### 2.2 Meeting Endpoints

**Create instant meeting**
```
POST /meetings/instant
Headers: Authorization: Bearer <token>
Content-Type: multipart/form-data
Fields: title (optional, default "Quick Meeting"), description (optional),
        stream_type (optional, default "video"), max_participants (optional)
```
Returns a full `Meeting` object. Key fields:
- `nice_id` — the slug used in URLs (e.g. `/abc123xyz`)
- `livekit.token`, `livekit.livekit_url`, `livekit.room` — present once the meeting is active

**Create scheduled meeting**
```
POST /meetings/schedule
Headers: Authorization: Bearer <token>
Content-Type: multipart/form-data
Fields: title, description, stream_type,
        scheduled_start_time (ISO 8601), scheduled_end_time (optional),
        max_participants (optional)
```

**Get meeting by ID (public)**
```
GET /meetings/{meetingId}
Headers: Accept: application/json
```
Returns the `Meeting` object; `livekit` fields are only populated once the meeting is ready.

**Join meeting (authenticated)**
```
POST /meetings/{meetingId}/join
Headers: Authorization: Bearer <token>
Content-Type: application/x-www-form-urlencoded
Body: role=participant (optional)
```
Returns the updated `Meeting` with refreshed LiveKit credentials.

**Guest token (unauthenticated join)**
```
POST /meetings/{meetingId}/guest-token
Content-Type: application/json
Body: { "display_name": "Guest Name" }
```
Response:
```json
{
  "token": "eyJ...",
  "livekit_url": "wss://livekit.example.com",
  "identity": "guest_GuestName_a1b2c3d4",
  "display_name": "Guest Name",
  "room": "meeting_abc123xyz",
  "meeting_title": "Quick Sync",
  "participant_count": 3
}
```

**List my meetings**
```
GET /meetings?status=active&meeting_type=instant&limit=10&offset=0
Headers: Authorization: Bearer <token>
```
Response:
```json
{ "meetings": [ /* Meeting[] */ ], "total": 1, "page": 1, "page_size": 10 }
```

**Leave meeting**
```
POST /meetings/{meetingId}/leave
Headers: Authorization: Bearer <token>
```

**Start scheduled meeting**
```
POST /meetings/{meetingId}/start
Headers: Authorization: Bearer <token>
```

### 2.3 Dart Models

⚠ Recommendation: generate these with `freezed` + `json_serializable` instead of hand-rolled classes — it removes boilerplate `fromJson`/`toJson`/`copyWith`/equality code and eliminates an entire class of null-safety bugs on optional fields like `livekit`.

```dart
@freezed
class Meeting with _$Meeting {
  const factory Meeting({
    required int id,
    @JsonKey(name: 'nice_id') required String niceId,
    @JsonKey(name: 'company_id') required int companyId,
    @JsonKey(name: 'created_by_id') required int createdById,
    required String title,
    String? description,
    @JsonKey(name: 'meeting_type') required String meetingType, // 'instant' | 'scheduled'
    required String status, // 'pending' | 'active' | 'ended' | 'cancelled'
    @JsonKey(name: 'scheduled_start_time') String? scheduledStartTime,
    @JsonKey(name: 'scheduled_end_time') String? scheduledEndTime,
    @JsonKey(name: 'actual_start_time') String? actualStartTime,
    @JsonKey(name: 'actual_end_time') String? actualEndTime,
    @JsonKey(name: 'stream_type') required String streamType,
    @JsonKey(name: 'max_participants') required int maxParticipants,
    @JsonKey(name: 'participant_count') required int participantCount,
    @JsonKey(name: 'peak_participants') required int peakParticipants,
    @JsonKey(name: 'total_views') required int totalViews,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
    @JsonKey(name: 'company_name') required String companyName,
    @JsonKey(name: 'company_slug') required String companySlug,
    @JsonKey(name: 'created_by_email') required String createdByEmail,
    Playback? playback,
    @Default([]) List<Participant> participants,
    LiveKitToken? livekit, // null until the meeting is started
  }) = _Meeting;

  factory Meeting.fromJson(Map<String, dynamic> json) => _$MeetingFromJson(json);
}

@freezed
class Participant with _$Participant {
  const factory Participant({
    required int id,
    @JsonKey(name: 'user_id') required int userId,
    required String role,   // 'host' | 'participant' | 'guest'
    required String status, // 'joined' | 'left' | 'invited'
    @JsonKey(name: 'is_speaking') bool? isSpeaking,
    @JsonKey(name: 'is_muted') bool? isMuted,
    @JsonKey(name: 'joined_at') required String joinedAt,
    @JsonKey(name: 'left_at') String? leftAt,
    @JsonKey(name: 'user_email') required String userEmail,
    @JsonKey(name: 'user_username') required String userUsername,
    @JsonKey(name: 'guest_name') String? guestName,
    @JsonKey(name: 'livekit_identity') required String livekitIdentity,
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) => _$ParticipantFromJson(json);
}

@freezed
class Playback with _$Playback {
  const factory Playback({
    required String status,
    @JsonKey(name: 'video_uid') String? videoUid,
    @JsonKey(name: 'hls_url') String? hlsUrl,
    @JsonKey(name: 'dash_url') String? dashUrl,
    @JsonKey(name: 'preview_url') String? previewUrl,
    @JsonKey(name: 'webrtc_playback_url') String? webrtcPlaybackUrl,
  }) = _Playback;

  factory Playback.fromJson(Map<String, dynamic> json) => _$PlaybackFromJson(json);
}

@freezed
class LiveKitToken with _$LiveKitToken {
  const factory LiveKitToken({
    required String token,
    @JsonKey(name: 'livekit_url') required String livekitUrl,
    required String room,
  }) = _LiveKitToken;

  factory LiveKitToken.fromJson(Map<String, dynamic> json) => _$LiveKitTokenFromJson(json);
}

@freezed
class VolTokenResponse with _$VolTokenResponse {
  const factory VolTokenResponse({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    @JsonKey(name: 'token_type') required String tokenType,
    @JsonKey(name: 'expires_in') required int expiresIn,
  }) = _VolTokenResponse;

  factory VolTokenResponse.fromJson(Map<String, dynamic> json) => _$VolTokenResponseFromJson(json);
}

@freezed
class VolUserResponse with _$VolUserResponse {
  const factory VolUserResponse({
    required int id,
    @JsonKey(name: 'company_id') int? companyId,
    @JsonKey(name: 'company_name') String? companyName,
    @JsonKey(name: 'company_slug') String? companySlug,
    required String email,
    required String username,
    required String role,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _VolUserResponse;

  factory VolUserResponse.fromJson(Map<String, dynamic> json) => _$VolUserResponseFromJson(json);
}
```

### 2.4 Networking Layer & Error Handling

⚠ Added — the original draft had no shared HTTP client, token-refresh, or error-mapping strategy. Without this, every screen ends up duplicating auth-header logic and 401 handling.

```dart
class ApiClient {
  ApiClient(this._dio, this._tokenStorage);

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  static ApiClient create(String baseUrl, SecureTokenStorage tokenStorage) {
    final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)));
    final client = ApiClient(dio, tokenStorage);

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.accessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await client._tryRefresh();
          if (refreshed) {
            final retryReq = await dio.fetch(error.requestOptions);
            return handler.resolve(retryReq);
          }
          await tokenStorage.clear(); // force re-login
        }
        handler.next(error);
      },
    ));
    return client;
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _tokenStorage.refreshToken();
    if (refreshToken == null) return false;
    try {
      // call your refresh endpoint here if the API exposes one;
      // the spec above does not document one explicitly — confirm with backend team.
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

Map HTTP failures to a small sealed error type (`NetworkError`, `ValidationError(fieldErrors)`, `AuthError`, `ServerError`) so screens can render field-level form errors instead of a single generic string — the design spec in §5.4–5.6 shows per-field error states that a flat `String? error` can't represent well.

---

## 3. Theme & Design System

Translate every CSS custom property from `app/theme.css` into a Flutter `ThemeData`.

### 3.1 Color Palette — Light Mode

| Token | Hex | Flutter Usage |
|---|---|---|
| `--color-bg` | `#fafaf9` | `scaffoldBackgroundColor`, `colorScheme.surface` |
| `--color-bg-subtle` | `#f4f3f0` | Card backgrounds, slight elevation |
| `--color-bg-elevated` | `#ffffff` | Modal backgrounds, dropdowns |
| `--color-bg-card` | `#ffffff` | Card surfaces |
| `--color-bg-input` | `#f4f3f0` | Input fill |
| `--color-bg-hover` | `rgba(0,0,0,0.03)` | Hover overlay (`InkWell` splash) |
| `--color-bg-active` | `rgba(0,0,0,0.05)` | Active/pressed overlay |
| `--color-text` | `#111110` | Primary text (`onSurface`) |
| `--color-text-secondary` | `#6b6966` | Secondary text |
| `--color-text-tertiary` | `#9b9894` | Placeholder/hint text |
| `--color-text-inverse` | `#ffffff` | Text on colored buttons |
| `--color-border` | `#e4e3df` | Default dividers |
| `--color-border-hover` | `#d1d0cc` | Hover borders |
| `--color-border-active` | `#b8b7b3` | Active borders |
| `--color-accent` | `#0066cc` | Primary brand / CTA |
| `--color-accent-hover` | `#0052a3` | Accent pressed |
| `--color-accent-subtle` | `rgba(0,102,204,0.08)` | Accent tint background |
| `--color-accent-muted` | `rgba(0,102,204,0.12)` | Accent pressed bg |
| `--color-success` | `#16a34a` | Live indicator, success states |
| `--color-success-subtle` | `rgba(22,163,74,0.1)` | Success tint bg |
| `--color-warning` | `#ca8a04` | Warning badges |
| `--color-warning-subtle` | `rgba(202,138,4,0.1)` | — |
| `--color-error` | `#dc2626` | Error text, leave button |
| `--color-error-subtle` | `rgba(220,38,38,0.1)` | Error tint bg |
| `--color-overlay` | `rgba(0,0,0,0.4)` | Modal overlay/backdrop |
| `--color-shadow` | `rgba(0,0,0,0.06)` | Standard shadow |
| `--color-shadow-elevated` | `rgba(0,0,0,0.1)` | Elevated shadow |

### 3.2 Color Palette — Dark Mode

| Token | Hex |
|---|---|
| `--color-bg` | `#0c0c0b` |
| `--color-bg-subtle` | `#141413` |
| `--color-bg-elevated` | `#1a1a18` |
| `--color-bg-card` | `#181817` |
| `--color-bg-input` | `#141413` |
| `--color-text` | `#f0efed` |
| `--color-text-secondary` | `#a8a5a0` |
| `--color-text-tertiary` | `#6b6966` |
| `--color-accent` | `#4a9eff` |
| `--color-accent-hover` | `#6fb3ff` |
| `--color-border` | `#2a2a27` |
| `--color-border-hover` | `#3a3a36` |

**Flutter implementation:** wrap the app in `MaterialApp` with `ThemeData(useMaterial3: true)`. Define a `ColorScheme.fromSeed(seedColor: Color(0xFF0066CC))`, then override the specific tokens above rather than trusting Material 3's derived tonal palette (the brand palette is not a standard M3 tonal ramp). Provide a matching `darkTheme` and support system switching via `themeMode: ThemeMode.system`.

```dart
final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0066CC),
    brightness: Brightness.light,
  ).copyWith(
    surface: const Color(0xFFFAFAF9),
    onSurface: const Color(0xFF111110),
    error: const Color(0xFFDC2626),
  ),
  scaffoldBackgroundColor: const Color(0xFFFAFAF9),
  fontFamily: GoogleFonts.inter().fontFamily,
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A9EFF),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF0C0C0B),
    onSurface: const Color(0xFFF0EFED),
  ),
  scaffoldBackgroundColor: const Color(0xFF0C0C0B),
  fontFamily: GoogleFonts.inter().fontFamily,
);
```

Custom (non-Material) tokens such as `bgCard`, `bgSubtle`, `accentSubtle`, `shadow`, etc. don't map onto `ColorScheme` 1:1 — define them as a `ThemeExtension<VolantisColors>` so they theme-switch automatically instead of being scattered `Color(0x...)` constants across widgets:

```dart
class VolantisColors extends ThemeExtension<VolantisColors> {
  const VolantisColors({
    required this.bgSubtle,
    required this.bgCard,
    required this.bgInput,
    required this.accentSubtle,
    required this.successSubtle,
    required this.errorSubtle,
    required this.textTertiary,
    required this.shadow,
  });

  final Color bgSubtle, bgCard, bgInput, accentSubtle, successSubtle, errorSubtle, textTertiary, shadow;

  @override
  VolantisColors copyWith({/* ... */}) => this; // implement per-field

  @override
  VolantisColors lerp(ThemeExtension<VolantisColors>? other, double t) => this; // simple cut-over is fine for two discrete themes
}

// usage: Theme.of(context).extension<VolantisColors>()!.bgSubtle
```

### 3.3 Typography

Font families:
- Sans: `'Geist'`, `'Inter'`, `system-ui`, `-apple-system`, `sans-serif`
- Display: `'Bricolage Grotesque'`, `'Geist'`, `system-ui`, `sans-serif`

⚠ Note: `google_fonts` does not host "Geist" — it's a Vercel-distributed font, not a Google Fonts family. Bundle Geist as a local asset font (`assets/fonts/Geist-*.ttf`) declared in `pubspec.yaml`, and use `google_fonts` only for **Bricolage Grotesque**, which is on Google Fonts.

```yaml
flutter:
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf
          weight: 400
        - asset: assets/fonts/Geist-Medium.ttf
          weight: 500
        - asset: assets/fonts/Geist-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Geist-Bold.ttf
          weight: 700
```

```dart
TextStyle display = GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w600);
TextStyle body = const TextStyle(fontFamily: 'Geist', fontSize: 16, fontWeight: FontWeight.w400);
```

| Style name | Web value | Flutter (sp) | Usage |
|---|---|---|---|
| `displayLarge` | `clamp(1.5rem, 3.5vw, 2.25rem)` | 20–36 (responsive) | Section headings |
| `displayMedium` | `1.5rem` | 24 | Page titles |
| `titleLarge` | `1.0625rem` | 17 | Card titles |
| `titleMedium` | `1rem` | 16 | Subtitles |
| `bodyLarge` | `0.9375rem` | 15 | Body text |
| `bodyMedium` | `0.875rem` | 14 | Secondary text |
| `bodySmall` | `0.8125rem` | 13 | Captions |
| `labelSmall` | `0.75rem` | 12 | Uppercase tags, hints |

Font weights: 400 regular, 500 emphasis, 600 semi-bold, 700 bold.
Letter spacing: `-0.02em` for display headings, `0.08em` for uppercase tags.

For the responsive `displayLarge` clamp, don't hardcode a single sp value — scale off `MediaQuery.sizeOf(context).width` with a clamp helper so tablet/desktop-width windows (Flutter also targets desktop/web per the LiveKit SDK table in §6) get the larger end of the range:

```dart
double clampFontSize(double width) => (20 + (width / 1000) * 16).clamp(20.0, 36.0);
```

### 3.4 Spacing (8pt grid)

```dart
class Sizes {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  static const space10 = 40.0;
  static const space12 = 48.0;
}
```

### 3.5 Border Radius

```dart
class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const full = 100.0; // or StadiumBorder()
}
```

### 3.6 Shadows

```dart
final shadow = [BoxShadow(color: const Color(0x0D000000), blurRadius: 24, offset: const Offset(0, 4))];
final shadowElevated = [BoxShadow(color: const Color(0x1A000000), blurRadius: 40, offset: const Offset(0, 12))];
final shadowModal = [BoxShadow(color: const Color(0x1A000000), blurRadius: 48, offset: const Offset(0, 16))];
```

### 3.7 Transitions

```dart
const fast = Duration(milliseconds: 150);
const base = Duration(milliseconds: 200);
const slow = Duration(milliseconds: 300);
```

### 3.8 Background Animation (Aurora)

The web app uses two independently drifting blurred gradient blobs. On mobile:

- 2–4 positioned `Container`s with `BoxDecoration(gradient: RadialGradient(...))`.
- One `AnimationController` per blob (~26s and ~34s durations), driving position/scale `Tween`s, repeating with `reverse: true`.
- Skip `BackdropFilter`/`ImageFilter.blur` on the animated layer itself — it's re-evaluated every frame and is a common Flutter jank source. Instead pre-blur the gradient via a large, soft `RadialGradient` stop spread, or bake a blurred PNG asset and animate its `Transform` instead of a live blur.
- Wrap in `Opacity(opacity: 0.55)`; use `ColorFiltered` with a saturation matrix if the web version desaturates/saturates on scroll.
- Alternative: a single `CustomPainter` redrawing both gradients per frame via `AnimatedBuilder`, which avoids the overhead of multiple `Positioned` widgets rebuilding independently.

**Performance note:** test the aurora background on a mid-tier Android device before shipping — animated gradients + `Opacity` compositing is the single most common cause of dropped frames in effects like this. If jank shows up, drop to a single static gradient with a very slow (60s+) `AnimatedContainer` cross-fade instead of continuous motion.

---

## 4. App Architecture & Routing

### 4.1 Screens

| Route | Widget | Description |
|---|---|---|
| `/` | `LandingScreen` | Home with Create + Join panels |
| `/login` | `LoginScreen` | Email/password login |
| `/signup` | `SignupScreen` | User signup |
| `/verify-email` | `VerifyEmailScreen` | OTP entry |
| `/meeting/:meetingId` | `MeetingScreen` | Fetch meeting → preview → guest name → LiveKit room |
| `/pricing` | `PricingScreen` | Static pricing tiers |
| `/developers` | `DevelopersScreen` | API docs marketing |

### 4.2 Route Definitions (go_router)

⚠ Cng. Use `refreshListenable` bound to the auth state so the router actually re-evaluates redirects when auth changes, and prefer `GoRouter.of(context)` construction inside a provider rather than a top-level `final`.

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(
        path: '/meeting/:meetingId',
        builder: (context, state) => MeetingScreen(meetingId: state.pathParameters['meetingId']!),
      ),
      GoRoute(path: '/pricing', builder: (context, state) => const PricingScreen()),
      GoRoute(path: '/developers', builder: (context, state) => const DevelopersScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      final isMeetingRoute = state.matchedLocation.startsWith('/meeting/');

      // Meeting routes are intentionally public (guests can join).
      if (isMeetingRoute) return null;
      if (!auth.isAuthenticated && !loggingIn) return null; // most routes are public; only gate specific ones
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
  );
});
```

`GoRouterRefreshStream` is a small `ChangeNotifier` adapter class (a few lines, documented in the go_router README) that turns any `Stream` into a `Listenable` for `refreshListenable`.

### 4.3 Auth State Management

```dart
class AuthState {
  final VolUserResponse? user;
  final bool isAuthenticated;
  final bool isEmailVerified;
  final bool isLoading;
  final String? error;

  Future<void> login(LoginRequest req);
  Future<void> signupUser(SignupRequest req);
  Future<void> logout();
  Future<void> fetchUser();
  Future<bool> checkEmailVerification();
}
```


### 4.4 Persistent Storage

⚠ Corrected — split storage by sensitivity. Tokens should not sit in `SharedPreferences`, which is unencrypted plist/XML on both platforms.

| Key | Storage | Type |
|---|---|---|
| `vol_access_token` | `flutter_secure_storage` | String |
| `vol_refresh_token` | `flutter_secure_storage` | String |
| `vol_token_expires` | `flutter_secure_storage` | String (epoch seconds) |
| `vol_user` | `shared_preferences` | JSON string (non-sensitive profile cache) |
| `verification_email` | `shared_preferences` | String |
| `verification_user_id` | `shared_preferences` | String |
| `vol_guest_names` | `shared_preferences` | JSON string array (max 5) |

Proactively refresh the access token a short buffer (e.g. 60s) before `vol_token_expires`, rather than waiting for a 401 — this avoids a visible failed request mid-meeting-join.

---

## 5. Screen Specifications

### 5.1 Landing Screen

```dart
Scaffold(
  body: Stack(
    children: [
      const AuroraBackground(),
      Column(
        children: [
          const Header(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Sizes.space6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Connect to a meeting', style: displayLarge),
                      const SizedBox(height: Sizes.space6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 640;
                          final panels = [
                            const CreateMeetingPanel(),
                            const JoinMeetingPanel(),
                          ];
                          return stacked
                              ? Column(children: [panels[0], const SizedBox(height: Sizes.space6), panels[1]])
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: panels[0]),
                                    const SizedBox(width: Sizes.space6),
                                    Expanded(child: panels[1]),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Footer(),
        ],
      ),
    ],
  ),
)
```

**Animations:** `TweenAnimationBuilder<Offset>` from `Offset(0, 16)` to `Offset.zero` combined with an opacity tween over 500ms (`Curves.ease`); stagger the second panel by an 80ms `Future.delayed` before it starts animating.

### 5.2 Header

- Height ~56px, padding `EdgeInsets.symmetric(horizontal: Sizes.space6, vertical: Sizes.space3)`.
- Implement as a `PreferredSize` widget passed to `Scaffold.appBar`, `backgroundColor: Colors.transparent`, `elevation: 0`.
- Blur: `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))` — gate this behind a "reduce motion/effects" or low-end-device check; it's one of the more expensive widgets in the tree if it repaints often (e.g. behind a scrolling list).
- Bottom border: `Divider(color: border.withOpacity(0.6), height: 1)`.

**Brand:** logo (`Image.asset('assets/logo.png', height: 32)`) + `RichText`("Volantis" in primary + "Connect" in accent), Bricolage Grotesque 17px/600.

**Nav links:** pill container (`bgSubtle`, `BorderRadius.circular(100)`, 0.5-opacity border); active link gets `bgElevated` + subtle shadow; 14px/500 text, secondary → primary color on active.

**Auth section:**
- Logged in: `CircleAvatar` (32px, bg `textPrimary`, initials) + username + sign-out.
- Logged out: pill "Sign In" button (`bg textPrimary`, white text).

**Mobile (< 768px):** wrap nav links onto a second centered row below brand/auth, rather than horizontally scrolling or truncating.

### 5.3 Footer

Centered text, 13px, `textTertiary`: "A product of Volantis Live", linking out via `url_launcher` to `https://volantislive.com`.

### 5.4 Login Screen

```dart
Scaffold(
  body: AnimatedBackground(
    intensity: AnimatedBackgroundIntensity.medium,
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? Sizes.space4 : Sizes.space8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(Sizes.space8),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: border),
              boxShadow: shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: displayMedium),
                const SizedBox(height: Sizes.space1),
                Text('Sign in to your account', style: bodyMediumSecondary),
                const SizedBox(height: Sizes.space6),
                if (error != null) ErrorBanner(message: error),
                Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      EmailField(controller: emailCtrl),
                      const SizedBox(height: Sizes.space4),
                      PasswordField(controller: passwordCtrl),
                      const SizedBox(height: Sizes.space3),
                      RememberMeAndForgotRow(),
                      const SizedBox(height: Sizes.space6),
                      SubmitButton(isLoading: isLoading, label: 'Sign in', onPressed: submit),
                    ],
                  ),
                ),
                const SizedBox(height: Sizes.space6),
                Center(child: SignupLinkText()),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
)
```

- Labels: 14px/500.
- Inputs: filled `bgInput`, 1px `border`, radius 12px; focus → `accent` border + `BoxShadow(blurRadius: 12, color: accentSubtle)`.
- Prefix icon (mail) at 16px inset, `textTertiary`.
- Submit: full width, 48px height, `bg textPrimary` (hover/pressed → `accent`), radius 12px, weight 600.
- Loading: 18×18 `CircularProgressIndicator(strokeWidth: 2)` + "Signing in…" label, and **disable the button** while loading to prevent duplicate submits.

### 5.5 Signup Screen

Same card shell as Login. Differences:
- Username, Email, Password, Confirm Password — Password/Confirm side-by-side on width ≥ 640px via a `Row`.
- Terms checkbox: "I agree to the Terms of Service and Privacy Policy" (14px, secondary, accent-colored inline links).
- Submit label: "Create account".
- Success modal (see below) after a successful response.

**Success modal:**

```dart
showGeneralDialog(
  context: context,
  barrierColor: colorOverlay,
  barrierDismissible: false,
  transitionDuration: slow,
  pageBuilder: (context, animation, secondaryAnimation) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.all(Sizes.space4),
      padding: const EdgeInsets.all(Sizes.space8),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border),
        boxShadow: shadowModal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: successSubtle, shape: BoxShape.circle),
            child: const Icon(LucideIcons.checkCircle, color: success, size: 32),
          ),
          const SizedBox(height: Sizes.space5),
          Text('Account created!', style: displayMedium),
          const SizedBox(height: Sizes.space2),
          Text('We sent a verification code to your email.', style: bodyMediumSecondary),
          const SizedBox(height: Sizes.space6),
          TextButton.icon(
            onPressed: () => context.go('/verify-email'),
            icon: const Icon(LucideIcons.arrowRight, size: 16),
            label: const Text('Verify Email'),
          ),
        ],
      ),
    ),
  ),
);
```

### 5.6 Verify Email Screen

- Icon: mail glyph in a 64px `accentSubtle` circle.
- Title: "Verify your email"; subtitle mentions the stored email (from `verification_email`).
- OTP field: 24px font, monospace (Geist Mono if bundled, else system mono), `letterSpacing: 0.3em`, centered, `maxLength: 6`, `keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digits, LengthLimitingTextInputFormatter(6)]`.
- Hint: "Enter the 6-digit code from your email".
- Primary submit + outlined "Resend OTP" (debounce/disable for ~30s after tap to match typical OTP resend cooldowns; confirm exact cooldown with backend).
- "Remember your password? Sign in" link.

**Success state:** `CheckCircle` icon (36px, in a 64px `success`-tinted circle), "Email Verified!", and a "Go to Sign In" button.

### 5.7 Meeting Preview Modal (Guest & Authenticated)

Entry flow: user navigates to `/meeting/{meetingId}`.

**Phase state machine:**
`loading → preview → (guest | connected) → error`

- `loading` — fetch `GET /meetings/{meetingId}`, show a centered spinner.
- `preview` — show `MeetingPreviewModal`.
- `guest` — unauthenticated user taps "Join as Guest" → show `GuestNameModal`.
- `connected` — LiveKit room renders (§6).
- `error` — show `MeetingErrorModal` (e.g. meeting not found, ended, or full).

⚠ Added — model this explicitly as a sealed/union type rather than a loose `enum` + nullable fields, so the UI layer can't render an impossible combination (e.g. `connected` with no `LiveKitToken`):

```dart
sealed class MeetingJoinState {}
class MeetingLoading extends MeetingJoinState {}
class MeetingPreview extends MeetingJoinState { final Meeting meeting; MeetingPreview(this.meeting); }
class MeetingGuestPrompt extends MeetingJoinState { final Meeting meeting; MeetingGuestPrompt(this.meeting); }
class MeetingConnected extends MeetingJoinState { final Room room; MeetingConnected(this.room); }
class MeetingError extends MeetingJoinState { final String message; MeetingError(this.message); }
```

**MeetingPreviewModal:**
- Top row: video-camera icon (56px, `accentSubtle` bg) + status badge.
  - Live → `successSubtle` bg, `success` text, uppercase, weight 700, pill radius 100.
  - Scheduled → `accentSubtle` bg, `accent` text.
  - Ended → `bgSubtle` bg, `textTertiary` text.
- Title: meeting title, `displayMedium`.
- Details block: gradient (`bgSubtle` → transparent), border, radius 16px, padding 20px — host, date/time, participant count.
- Actions: authenticated → "Join Meeting" (primary, full width) + "Cancel"; unauthenticated → "Join as Guest" (primary) + "Cancel" + "Or sign in to join as host" link.
- Animation: overlay fade 200ms; modal slides up over 300ms with an overshoot curve (`Curves.easeOutBack`).

**GuestNameModal:**
- User icon in a 56px `bgSubtle` circle. Title "Join as Guest"; subtitle references the meeting title.
- Saved-name chips (from `vol_guest_names`, max 5) — pill buttons, active state = accent border + tint.
- Name input: max 50 chars, allowed characters `[a-zA-Z0-9 ]` enforced via a custom `TextInputFormatter`; validation requires ≥ 5 chars.
- "Save my name for next time" checkbox.
- Actions: Cancel (flex 1) + Join Meeting (flex 2, accent), disabled until valid.
- Inline error text (13px, error color) + error-colored input border on invalid input.

### 5.8 Create Meeting Panel

State progression: **not authenticated** (a "New meeting" link routing to `/login`) → **dropdown** ("New meeting" pill + menu: "Start Instant Meeting" / "Schedule for Later") → **schedule form** (date/time pickers + Schedule button) → **success** (copy-link box, share buttons, "Join Now"/"Start Meeting", "Create Another").

- Dropdown: positioned below the trigger button, min-width 260px, `bgElevated`, border, radius 12px, elevated shadow; 200ms slide-down + fade entry.
- Share buttons via `url_launcher`:
  - Twitter/X: `https://twitter.com/intent/tweet?text=...&url=...`
  - LinkedIn: `https://www.linkedin.com/sharing/share-offsite/?url=...`
  - Email: `mailto:?subject=...&body=...`
- Link box: read-only `TextField` + copy button; on tap, copy via `Clipboard.setData` and show "Copied" for 2s (`AnimatedSwitcher` or a timed `setState` flag).

### 5.9 Join Meeting Panel

Pill input (`bgInput` fill, border, radius 100) containing an `Expanded TextField` + accent "Join" button. Focus state → accent border + 3px accent-tinted shadow; error state → red border/shadow. Disable "Join" until the input parses to a valid meeting reference.

**Validation** (ported from the web app's URL/code parser):

```dart
String? extractMeetingId(String input) {
  final trimmed = input.trim();
  final urlMatch = RegExp(r'[?&]meeting=([^&]+)').firstMatch(trimmed);
  if (urlMatch != null) return urlMatch.group(1);

  final joinMatch = RegExp(r'/join/([^/?]+)').firstMatch(trimmed);
  if (joinMatch != null) return joinMatch.group(1);

  final volantisMatch = RegExp(r'volantislive\.com/([^/?]+)').firstMatch(trimmed);
  if (volantisMatch != null && volantisMatch.group(1) != 'join') return volantisMatch.group(1);

  final codeMatch = RegExp(r'^[A-Za-z0-9]{10,20}$').firstMatch(trimmed);
  if (codeMatch != null) return trimmed;

  return null;
}
```

### 5.10 My Meetings List

- Card container: `bgCard`, border, radius 20px, padding 24px.
- Header: title + Upcoming/Past toggle tabs (`bgSubtle` track, 8px radius, 2px padding; active tab gets `bgElevated` + shadow).
- Loading: centered spinner. Empty state: icon + text, generous padding.
- Meeting card: `bgSubtle` + border, radius 12px, padding 16px; status badge + type label; title 15px/600; meta row 12px `textTertiary` with icons; actions = Join (primary, flex 1) + Copy Link (secondary).
- Live indicator: 5px `success`-colored dot, 2s ease-in-out pulse via a repeating `AnimationController` (scale/opacity, not a CSS-style keyframe).
- Join button is disabled when `status == 'ended'`.

Use pagination (`limit`/`offset` from §2.2) with a `ListView.builder` + scroll-triggered "load more", rather than fetching the full history at once.

### 5.11 Pricing Screen

Three tiers — Free (outlined), Pro (featured: accent border/gradient), Enterprise (outlined). Each card: optional badge, name, price + unit, feature checklist, full-width CTA. `Row` of cards ≥ 768px width; stacked `Column`/`Wrap` below that.

### 5.12 Developers Screen

- Dev feature grid: 1 column mobile, 3 columns desktop (`GridView` with a `SliverGridDelegateWithMaxCrossAxisExtent`, which adapts column count automatically rather than a hardcoded breakpoint).
- Code block: dark background, monospace font, rounded corners, macOS-style header dots.
- CTA row: primary + secondary buttons.

---

## 6. LiveKit Room Screen

The web app renders a full-screen LiveKit room. In Flutter:

```
MeetingScreen (state machine: loading → preview → guest → connected)
 └── connected: LiveKitRoomScreen
       ├── LiveKit Room widget (VideoTrackRenderer per participant)
       ├── Custom ControlBar
       ├── Custom Chat (bottom sheet on mobile, side panel on desktop)
       ├── Custom Participants sidebar
       └── Recording indicator (optional)
```

### 6.1 LiveKit Connection Flow

1. User taps "Join" (authenticated) or "Join Meeting" (guest).
2. Call the API:
   - Authenticated: `POST /meetings/{niceId}/join`
   - Guest: `POST /meetings/{niceId}/guest-token` with `display_name`
3. Extract `livekit.token`, `livekit.livekit_url`, `livekit.room`.
4. Connect the LiveKit room. ⚠ Corrected — `livekit_client` 2.x uses an explicit `Room()` constructor plus `room.connect(url, token, roomOptions: ...)`; there is no `LiveKitClient.connect(...)` static helper in current versions (that API was removed in the v1→v2 migration). Optionally call `prepareConnection` first to shave connection latency:

```dart
final room = Room(
  roomOptions: const RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    publishDefaults: VideoPublishOptions(
      simulcast: true,
      videoCodec: 'vp8', // or 'h264' / 'av1'
    ),
  ),
);

// Optional: warms up the connection before the token/url are both ready.
await room.prepareConnection(livekitUrl, token);
await room.connect(livekitUrl, token);

await room.localParticipant?.setMicrophoneEnabled(true);
try {
  await room.localParticipant?.setCameraEnabled(true);
} catch (e) {
  // Camera can fail on simulators/permission-denied — handle gracefully, don't block joining audio-only.
}
```

5. Push `LiveKitRoomScreen(room: room)`. On leave: `await room.disconnect();` then `POST /meetings/{meetingId}/leave`. Always dispose the room in the screen's `dispose()` too, in case the user backgrounds/kills the app mid-call.

**Platform setup reminders** (often missed):
- iOS `Info.plist`: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`; enable Background Modes → Audio for calls that continue backgrounded.
- Android: a foreground service is required to keep audio/screen-share alive in the background (the LiveKit example uses the `flutter_background` package for this).
- Screen share on Android requires `Helper.requestCapturePermission()` from `flutter_webrtc` before starting capture; iOS screen share requires a Broadcast Extension target.

### 6.2 LiveKit Room UI Requirements

The web app heavily restyles LiveKit's default web components (`.lk-room-container`, `.lk-control-bar`, `.lk-chat`, etc.) — there's no equivalent themeable component set in `livekit_client` for Flutter, so **all room UI is custom-built** on top of `Room`/`Participant`/`VideoTrackRenderer` primitives.

**Control bar:** row of pill/circular buttons — mic, camera, screen share, chat, participants, leave. Minimum 44×44 touch targets. Active state = accent-muted bg + accent icon; Leave = solid error red + white icon. Floating dock: ~85%-opacity elevated background + 16px blur + pill border + elevated shadow, safe-area-padded at the bottom on mobile.

**Video grid:**
- Desktop/wide (>640px logical width): wrap/flex layout, tiles clamped between ~260–440px with 1:1 aspect ratio, centered — without this constraint the grid stretches unpleasantly on wide windows (this SDK also targets macOS/Windows/Linux, so "desktop" is a real target here, not just a browser breakpoint).
- Mobile: space-filling grid (standard `GridView` sizing).
- 16px corner radius per tile; camera-off placeholder = gradient avatar (elevated → subtle); semi-transparent name badge (12px text), light/dark chosen per-tile based on the tile's dominant brightness if feasible, otherwise a fixed dark scrim.

**Chat:**
- Desktop: fixed right panel, 300–380px, frosted-glass background with a slow (~14s) hue-cycling gradient sheen behind the content. Approximate the web's `color-mix(...)` translucency with `color.withOpacity(0.62)` over a `BackdropFilter(blur: 22)`, and drive the gradient hue cycle with an `AnimationController` over a `SweepGradient`/`LinearGradient` color `Tween`.
- Mobile: `showModalBottomSheet` with `isScrollControlled: true`, `maxHeight: 70%` of screen, top corners radius 20, safe-area bottom padding.
- Input: pill radius 100, accent circular send button.

**Participants panel:** fixed 280–360px side panel; 200ms slide transition (`translateX` on wide layouts, `translateY` on mobile). Rows: 38px avatar (initials + gradient), name, mute/camera-off status icons in red when off.

**Permission gate (pre-join consent):** request camera/mic permission via `permission_handler` **before** calling `room.connect(...)`. Show an explainer screen (camera/mic icons + rationale + "Continue") rather than triggering the OS system prompt cold — this matches both platforms' best-practice guidance and avoids a jarring first-launch prompt. If permission is denied, offer an "audio only" / "continue without camera" path rather than a dead end.

---

## 7. Component Style Reference

### 7.1 Buttons

| Type | Spec | Flutter widget |
|---|---|---|
| Primary | `bg accent`, white text, radius 12px, weight 600 | `ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))` |
| Primary Pill | `bg accent`, white text, radius 100px | same, `shape: StadiumBorder()` |
| Secondary | `bg subtle`, border, radius 12px; accent border on press/hover | `OutlinedButton.styleFrom(...)` |
| Ghost/Text | no bg, accent text | `TextButton` |
| Danger | `bg error`, white text, radius 12px | `ElevatedButton.styleFrom(backgroundColor: error, foregroundColor: Colors.white)` |

Button label: 15px/600, centered, `-0.01em` letter spacing. Disabled: ~0.65 opacity, sufficient contrast maintained (don't rely on opacity alone — verify against WCAG AA, see §9).

### 7.2 Inputs

```dart
TextFormField(
  decoration: InputDecoration(
    filled: true,
    fillColor: bgInput,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    prefixIcon: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(LucideIcons.mail, size: 18)),
  ),
)
```

Password field: `suffixIcon: IconButton(icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye), onPressed: toggle)`.

### 7.3 Cards

```dart
Container(
  decoration: BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: border),
    boxShadow: [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 4))],
  ),
  child: const Padding(padding: EdgeInsets.all(24), child: /* ... */),
)
```

Glass variant (`CreateMeetingPanel`): use `BackdropFilter` sparingly — only on cards that sit above the animated aurora background, never stacked more than one deep, since nested `BackdropFilter`s multiply GPU cost.

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: bgCard.withOpacity(0.72),
        border: Border.all(color: border.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: shadow, blurRadius: 40, offset: const Offset(0, 12))],
      ),
    ),
  ),
)
```

### 7.4 Modals / Bottom Sheets

```dart
showDialog(
  context: context,
  barrierColor: colorOverlay,
  builder: (context) => Dialog(
    backgroundColor: bgElevated,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: border)),
    child: const Padding(padding: EdgeInsets.all(24), child: /* ... */),
  ),
);

showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: bgElevated.withOpacity(0.95),
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  builder: (context) => const DraggableScrollableSheet(/* ... */),
);
```

### 7.5 Animation Reference

| Animation | Web CSS | Flutter equivalent |
|---|---|---|
| `cardRise` | opacity 0→1 + `translateY` 16px→0, 500ms ease | `Tween<Offset>(begin: Offset(0, 16/height), end: Offset.zero)` inside a `SlideTransition` + `FadeTransition`, `Curves.ease` |
| `slideDown` | opacity + `translateY` -8px→0, 200ms | Same pattern, negative offset, `Curves.easeOut` |
| Pulse (live dot) | `scale`/`opacity` 2s infinite | Repeating `AnimationController` with `reverse: true`, `Curves.easeInOut` |
| Modal entry | scale + fade, spring-like | `Curves.easeOutBack` on a `ScaleTransition`, 300ms |

---

## 8. Configuration, Build & Environment

⚠ Added — the original draft had no section on environment separation, build flavors, or CI, which any real deployment needs.

### 8.1 Environment Config

Don't hardcode `https://api-dev.volantislive.com`. Inject per-build via `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://api-dev.volantislive.com
flutter build apk --dart-define=API_BASE_URL=https://api.volantislive.com --release
```

```dart
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-dev.volantislive.com',
  );
}
```

For multiple environments (dev/staging/prod) consider Flutter build **flavors** so each gets its own app ID/icon, avoiding accidental prod installs during testing.

### 8.2 Suggested Project Structure

```
lib/
  main.dart
  app.dart                 # MaterialApp.router + theme wiring
  core/
    env.dart
    theme/                 # colors, typography, spacing, radius, shadows
    network/                # ApiClient, interceptors, error mapping
    storage/                # SecureTokenStorage, PreferencesStorage
    router/                 # go_router config, redirect logic
  features/
    auth/
      data/                 # AuthRepository, DTOs
      application/          # AuthNotifier 
      presentation/         # LoginScreen, SignupScreen, VerifyEmailScreen
    meetings/
      data/
      application/
      presentation/
        landing/
        preview/
        my_meetings/
    livekit_room/
      application/          # RoomController wrapping livekit_client Room
      presentation/          # ControlBar, VideoGrid, ChatPanel, ParticipantsPanel
    pricing/
    developers/
  widgets/                  # shared buttons, cards, inputs, modals
  assets/
    fonts/
    logo.png
```

### 8.3 pubspec.yaml (dependency summary)

```yaml
dependencies:
  flutter:
    sdk: flutter
 
  go_router: ^14.8.0
  dio: ^5.9.2
  livekit_client: ^2.8.1
  shared_preferences: ^2.3.3
  flutter_secure_storage: ^9.2.2
  google_fonts: ^6.2.1
  lucide_icons: ^0.257.0
  permission_handler: ^11.3.1
  url_launcher: ^6.3.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  intl: ^0.19.0

dev_dependencies:
  build_runner: ^2.5.0
  freezed: ^2.5.7
  json_serializable: ^6.9.0
```

Pin exact versions from `pub.dev` at implementation time — the above reflects the current stable line as of this writing and will drift.

---

## 9. Testing, Accessibility & Quality

⚠ Added — not covered in the original draft.

- **Widget/unit tests:** cover the meeting-code parser (§5.9), OTP formatter, guest-name validator, and the auth redirect logic in isolation — these are the highest-risk pure-logic pieces.
- **Golden tests:** snapshot the card/button/input components against both light and dark themes to catch palette regressions.
- **Integration test:** at minimum, a scripted guest-join flow (`integration_test` package) against a staging meeting, since the LiveKit connection path is the app's core value and hardest to manually regression-test.
- **Accessibility:** ensure all interactive targets meet 44×44 minimum size (already called out for the control bar — apply the same rule to nav links, chips, and icon buttons); verify text/background contrast on the `accent`/`success`/`error` tints, especially in dark mode; add `Semantics` labels to icon-only buttons (mic/camera/leave) since screen-reader users can't infer their state from color alone.
- **Reduced motion:** respect `MediaQuery.disableAnimationsOf(context)` for the aurora background and pulse animation.

---

## 10. Open Questions for the Backend Team

Carried over/added during this pass — resolve before implementation to avoid rework:

1. Is there a dedicated `/auth/refresh` endpoint? The spec above never documents one, but §2.4's interceptor assumes one exists.
2. What is the OTP resend cooldown (§5.6) — is it enforced server-side, and should the client mirror that duration exactly?
3. Are `livekit.token` values single-use / room-scoped, or can a stale token from `GET /meetings/{id}` be reused across multiple `connect()` attempts without re-calling `/join`?
4. What's the guest display-name collision behavior (two guests both named "Alex")? Affects whether the client needs to surface the returned `identity` anywhere in the UI.