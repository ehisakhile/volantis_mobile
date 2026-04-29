# In-App Review Implementation — Live Streaming Listeners App

A guide to integrating native in-app rating prompts (Google Play & App Store) into your Flutter app using `in_app_review` and `shared_preferences`.

---

## 1. Dependencies

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  in_app_review: ^2.0.9
  shared_preferences: ^2.3.2
```

Then run:

```bash
flutter pub get
```

---

## 2. Platform Setup

### Android
No additional setup required. The Google Play In-App Review API works out of the box.

> **Note:** The review dialog only appears on devices with the Play Store installed. During development, use a device signed into a Google Play account.

### iOS
No additional setup required. StoreKit handles the prompt natively.

> **Note:** Apple limits how often the prompt appears (max 3 times per 365 days), regardless of how often you call it. Always test on a **real device** — simulators will not show the prompt.

---

## 3. Review Manager Service

Create `lib/services/review_manager.dart`:

```dart
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewManager {
  static const String _keyLastReviewDate = 'last_review_prompt_date';
  static const String _keySessionCount = 'session_count';
  static const String _keyHasReviewed = 'has_reviewed';

  // Minimum days between prompts
  static const int _daysBetweenPrompts = 30;

  // Minimum sessions before first prompt
  static const int _minSessionsBeforePrompt = 5;

  final InAppReview _inAppReview = InAppReview.instance;

  /// Call this on app start or when a meaningful user action occurs
  Future<void> incrementSessionAndMaybePrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't prompt if user has already reviewed
    final hasReviewed = prefs.getBool(_keyHasReviewed) ?? false;
    if (hasReviewed) return;

    // Increment session count
    final sessions = (prefs.getInt(_keySessionCount) ?? 0) + 1;
    await prefs.setInt(_keySessionCount, sessions);

    // Not enough sessions yet
    if (sessions < _minSessionsBeforePrompt) return;

    // Check last prompt date
    final lastPromptMs = prefs.getInt(_keyLastReviewDate);
    if (lastPromptMs != null) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      final daysSince = DateTime.now().difference(lastPrompt).inDays;
      if (daysSince < _daysBetweenPrompts) return;
    }

    await _requestReview(prefs);
  }

  /// Trigger a review prompt manually (e.g. after a positive interaction)
  Future<void> promptReviewAfterPositiveAction() async {
    final prefs = await SharedPreferences.getInstance();

    final hasReviewed = prefs.getBool(_keyHasReviewed) ?? false;
    if (hasReviewed) return;

    await _requestReview(prefs);
  }

  Future<void> _requestReview(SharedPreferences prefs) async {
    final isAvailable = await _inAppReview.isAvailable();
    if (!isAvailable) return;

    await _inAppReview.requestReview();

    // Save the date this prompt was shown
    await prefs.setInt(
      _keyLastReviewDate,
      DateTime.now().millisecondsSinceEpoch,
    );

    // Mark as reviewed so we don't prompt again too soon
    // Note: we can't detect if the user actually submitted a review,
    // so this flag prevents re-prompting until you reset it.
    await prefs.setBool(_keyHasReviewed, true);
  }

  /// Open the store listing directly (fallback or for settings screen)
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(
      appStoreId: 'YOUR_APP_STORE_ID', // iOS only — replace with your app's Apple ID
    );
  }

  /// Reset review state (e.g. after a major app update)
  Future<void> resetReviewState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasReviewed);
    await prefs.remove(_keyLastReviewDate);
    // Optionally reset session count too:
    // await prefs.remove(_keySessionCount);
  }
}
```

---

## 4. Usage Examples

### 4a. Trigger on session start (e.g. `main.dart` or home screen)

```dart
import 'services/review_manager.dart';

final reviewManager = ReviewManager();

@override
void initState() {
  super.initState();
  // Trigger after a short delay so the UI is settled
  Future.delayed(const Duration(seconds: 3), () {
    reviewManager.incrementSessionAndMaybePrompt();
  });
}
```

### 4b. Trigger after a positive listener interaction

Ideal moment: after a user saves a station, shares a stream, or completes a listening milestone.

```dart
// After user adds a station to favourites
Future<void> onStationFavourited() async {
  await favouritesRepository.save(station);
  // Good moment — user is happy
  await reviewManager.promptReviewAfterPositiveAction();
}
```

### 4c. "Rate Us" button in Settings screen

```dart
ElevatedButton(
  onPressed: () => reviewManager.openStoreListing(),
  child: const Text('Rate the App ⭐'),
)
```

---

## 5. Review Prompt Logic Flow

```
App Launch / Positive Action
        │
        ▼
Has user already reviewed?  ──YES──▶  Stop
        │ NO
        ▼
Session count ≥ 5?  ──NO──▶  Stop (increment count only)
        │ YES
        ▼
Days since last prompt ≥ 30?  ──NO──▶  Stop
        │ YES
        ▼
Is in_app_review available?  ──NO──▶  Stop
        │ YES
        ▼
  Show native review dialog
  Save prompt timestamp
  Set hasReviewed = true
```

---

## 6. SharedPreferences Keys Reference

| Key | Type | Description |
|---|---|---|
| `last_review_prompt_date` | `int` | Timestamp (ms) of the last prompt shown |
| `session_count` | `int` | Number of times the app has been opened |
| `has_reviewed` | `bool` | Whether the user has been shown the prompt |

---

## 7. Important Limitations

- **You cannot detect** whether the user actually submitted a rating. The native APIs deliberately hide this.
- **iOS caps** the prompt at 3 times per year per app regardless of your code.
- **Google Play** may suppress the dialog at its discretion (e.g. if the user has already rated).
- Always test on a **real device** with a valid store account.
- Never prompt immediately on first launch — wait for a meaningful moment.

---

## 8. Resetting State After a Major Update

If you ship a significant new version and want to re-engage users who were already prompted:

```dart
// Call this after detecting a version upgrade, e.g. using package_info_plus
await reviewManager.resetReviewState();
```

---

## 9. Checklist Before Release

- [ ] Replaced `'YOUR_APP_STORE_ID'` with your real Apple App ID
- [ ] Tested on a physical Android device (Play Store signed in)
- [ ] Tested on a physical iOS device (not simulator)
- [ ] Confirmed `_minSessionsBeforePrompt` and `_daysBetweenPrompts` suit your audience
- [ ] Verified prompt is triggered at a genuinely positive UX moment
- [ ] Added "Rate Us" option in Settings as a manual fallback