import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static const String _androidAppId = 'com.volantislive.volantislive';
  static const String _iosAppId = '6762115839';

  static const String _androidStoreUrl =
      'https://play.google.com/store/apps/details?id=$_androidAppId';
  static const String _iosStoreUrl = 'https://apps.apple.com/app/id$_iosAppId';

  static ShareService? _instance;

  factory ShareService() {
    _instance ??= ShareService._internal();
    return _instance!;
  }

  ShareService._internal();

  String getAppStoreLink() {
    if (kIsWeb) {
      return _iosStoreUrl;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidStoreUrl;
      case TargetPlatform.iOS:
        return _iosStoreUrl;
      default:
        return _iosStoreUrl;
    }
  }

  String getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      default:
        return 'Unknown';
    }
  }

  Future<void> shareApp({String? subject}) async {
    final link = getAppStoreLink();
    final platform = getPlatformName();
    final defaultSubject =
        'Check out VolantisLive - Ultra-low bandwidth audio streaming';

    try {
      await Share.share(
        '$defaultSubject\n\nDownload for $platform: $link',
        subject: subject ?? defaultSubject,
      );
      developer.log('App share initiated successfully');
    } catch (e) {
      developer.log('Error sharing app: $e');
      rethrow;
    }
  }

  Future<void> shareLink({
    required String link,
    String? subject,
    String? text,
  }) async {
    final shareText = text != null ? '$text\n\n$link' : link;

    try {
      await Share.share(shareText, subject: subject);
      developer.log('Link share initiated successfully: $link');
    } catch (e) {
      developer.log('Error sharing link: $e');
      rethrow;
    }
  }

  Future<void> shareStream({
    required String streamSlug,
    required String streamTitle,
    String? companyName,
    String? baseUrl,
  }) async {
    final streamUrl = _buildStreamUrl(streamSlug, baseUrl);
    final subject = companyName != null
        ? '$companyName is live: $streamTitle'
        : 'Join live stream: $streamTitle';
    final text = companyName != null
        ? '$companyName is streaming live!\n\n"$streamTitle"\n\nJoin now:'
        : 'Check out this live stream!\n\n"$streamTitle"\n\nJoin now:';

    await shareLink(link: streamUrl, subject: subject, text: text);
  }

  String _buildStreamUrl(String streamSlug, String? baseUrl) {
    final base = baseUrl ?? 'https://volantislive.com';
    return '$base/stream/$streamSlug';
  }

  Future<void> shareStreamWithSharePlus({
    required String streamSlug,
    required String streamTitle,
    String? companyName,
    String? baseUrl,
    String? imageUrl,
  }) async {
    final streamUrl = _buildStreamUrl(streamSlug, baseUrl);
    final subject = companyName != null
        ? '$companyName is live: $streamTitle'
        : 'Join live stream: $streamTitle';
    final text = companyName != null
        ? '$companyName is streaming live!\n\n"$streamTitle"\n\nJoin now:'
        : 'Check out this live stream!\n\n"$streamTitle"\n\nJoin now:';

    final shareText = '$text\n$streamUrl';

    try {
      await Share.share(
        shareText,
        subject: subject,
        // ignore: avoid_dynamic_calls
        // uri: Uri.parse(streamUrl),
      );
      developer.log('Stream share initiated successfully: $streamSlug');
    } catch (e) {
      developer.log('Error sharing stream: $e');
      rethrow;
    }
  }
}
