Here’s a clean, production-ready **`.md` guide file** tailored to your Flutter app using **`go_router`** and your **VolantisLive URL structure**.

---

# 📄 `applinks_flutter_guide.md`

````md
# Flutter App Links (Deep Linking) Setup Guide
### Project: VolantisLive

This guide walks you through setting up **App Links (Deep Links)** in Flutter using the `app_links` package and integrating it with `go_router`.

---

## 🚀 Overview

We will handle:

1. Cold start links (app closed)
2. Warm/foreground links (app open or background)
3. Routing using `go_router`
4. Supporting VolantisLive URL patterns:

| URL Pattern | Target Screen |
|------------|-------------|
| `/[companySlug]` | Company Page |
| `/[companySlug]/[streamSlug]` | Stream Player |
| `/[companySlug]/recording/[id]` | Recording Viewer |

---

## 📦 Step 1: Install Dependency

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  app_links: ^3.5.0
````

---

## 🧠 Step 2: App Links Handler

Create a dedicated handler:

`lib/core/deeplink/app_links_handler.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

class AppLinksHandler {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep linking
  static Future<void> init(BuildContext context) async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(context, initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(context, uri);
      },
      onError: (error) {
        debugPrint('Error listening to link stream: $error');
      },
    );
  }

  static void _handleDeepLink(BuildContext context, Uri uri) {
    debugPrint('Received deep link: $uri');

    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      context.go('/');
      return;
    }

    final companySlug = segments[0];

    // Case A: https://volantislive.com/{companySlug}
    if (segments.length == 1) {
      context.go('/company/$companySlug');
      return;
    }

    // Case C: /{companySlug}/recording/{id}
    if (segments.length == 3 && segments[1] == 'recording') {
      final recordingId = segments[2];

      context.go(
        '/company/$companySlug/recording/$recordingId',
      );
      return;
    }

    // Case B: /{companySlug}/{streamSlug}
    if (segments.length == 2) {
      final streamSlug = segments[1];

      context.go(
        '/company/$companySlug/stream/$streamSlug',
      );
      return;
    }

    // Fallback
    context.go('/');
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}
```

---

## 🧭 Step 3: Configure `go_router`

Example router setup:

```dart
final GoRouter router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    GoRoute(
      path: '/company/:companySlug',
      builder: (context, state) {
        final slug = state.pathParameters['companySlug']!;
        return CompanyScreen(companySlug: slug);
      },
    ),

    GoRoute(
      path: '/company/:companySlug/stream/:streamSlug',
      builder: (context, state) {
        return StreamScreen(
          companySlug: state.pathParameters['companySlug']!,
          streamSlug: state.pathParameters['streamSlug']!,
        );
      },
    ),

    GoRoute(
      path: '/company/:companySlug/recording/:id',
      builder: (context, state) {
        return RecordingScreen(
          companySlug: state.pathParameters['companySlug']!,
          recordingId: state.pathParameters['id']!,
        );
      },
    ),
  ],
);
```

---

## ⚙️ Step 4: Initialize in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'app_links_handler.dart';
import 'router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppLinksHandler.init(context);
        });

        return child!;
      },
    );
  }
}
```

---

## ❓ Why `addPostFrameCallback`?

This ensures:

* The widget tree is fully built
* `go_router` is ready
* Navigation won't crash

Without it, you may get:

```
Navigator operation requested before build completed
```

---

## 🔗 Step 5: Android Setup (App Links)

### `AndroidManifest.xml`

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />

    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <data
        android:scheme="https"
        android:host="volantislive.com" />
</intent-filter>
```

---

## 🍏 Step 6: iOS Setup (Universal Links)

### Add to `Info.plist`

```xml
<key>AssociatedDomains</key>
<array>
    <string>applinks:volantislive.com</string>
</array>
```

---

## 🌐 Step 7: Website Configuration

### `https://volantislive.com/.well-known/assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.yourapp.package",
      "sha256_cert_fingerprints": ["YOUR_SHA256"]
    }
  }
]
```

---

## 🧪 Testing Deep Links

### Android

```bash
adb shell am start -a android.intent.action.VIEW \
-d "https://volantislive.com/testcompany"
```

### iOS

Open in Safari:

```
https://volantislive.com/testcompany
```

---

## ✅ Why This Architecture Works

* `getInitialLink()` → Handles cold start
* `uriLinkStream` → Handles runtime links
* `go_router` → Clean declarative navigation
* Central handler → Scalable & maintainable
* URL parsing via `pathSegments` → Robust & flexible

---

## 📌 Future Improvements

* Add authentication guards
* Add analytics tracking per deep link
* Handle query params (e.g. referral codes)
* Add fallback UI for invalid links

---

## 🎯 Summary

You now have a **fully scalable deep linking system** that:

* Works across Android & iOS
* Supports complex URL structures
* Integrates cleanly with `go_router`
* Is production-ready for VolantisLive 🚀

```
