import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewManager {
  static const String _keyLastReviewDate = 'last_review_prompt_date';
  static const String _keySessionCount = 'session_count';
  static const String _keyHasReviewed = 'has_reviewed';
  static const String _keyStreamCount = 'stream_count';

  static const int _daysBetweenPrompts = 30;
  static const int _minSessionsBeforePrompt = 5;

  static ReviewManager? _instance;
  final InAppReview _inAppReview = InAppReview.instance;

  factory ReviewManager() {
    _instance ??= ReviewManager._internal();
    return _instance!;
  }

  ReviewManager._internal();

  Future<void> incrementSessionAndMaybePrompt() async {
    final prefs = await SharedPreferences.getInstance();

    final hasReviewed = prefs.getBool(_keyHasReviewed) ?? false;
    if (hasReviewed) return;

    final sessions = (prefs.getInt(_keySessionCount) ?? 0) + 1;
    await prefs.setInt(_keySessionCount, sessions);

    if (sessions < _minSessionsBeforePrompt) return;

    final lastPromptMs = prefs.getInt(_keyLastReviewDate);
    if (lastPromptMs != null) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      final daysSince = DateTime.now().difference(lastPrompt).inDays;
      if (daysSince < _daysBetweenPrompts) return;
    }

    await _requestReview(prefs);
  }

  Future<void> onLivestreamEnded() async {
    final prefs = await SharedPreferences.getInstance();

    final hasReviewed = prefs.getBool(_keyHasReviewed) ?? false;
    debugPrint('Livestream ended, hasReviewed: $hasReviewed');
    if (hasReviewed) return;

    final streamCount = (prefs.getInt(_keyStreamCount) ?? 0) + 1;
    debugPrint('Livestream ended, incrementing stream count to $streamCount');
    await prefs.setInt(_keyStreamCount, streamCount);

    if (streamCount == 1) {
      await _requestReview(prefs);
      debugPrint('First livestream ended, prompting for review');
    }
  }

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

    await prefs.setInt(
      _keyLastReviewDate,
      DateTime.now().millisecondsSinceEpoch,
    );

    await prefs.setBool(_keyHasReviewed, true);
  }

  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(appStoreId: '6762115839');
  }

  Future<void> resetReviewState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasReviewed);
    await prefs.remove(_keyLastReviewDate);
  }
}
