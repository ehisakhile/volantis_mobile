import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

class AppLinksHandler {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static final _trustedHosts = {'volantislive.com', 'www.volantislive.com'};
  static GoRouter? _router;

  static void setRouter(GoRouter router) {
    _router = router;
  }

  static Future<void> init() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null && _isTrustedLink(initialLink)) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        if (_isTrustedLink(uri)) {
          _handleDeepLink(uri);
        }
      },
      onError: (error) {
        debugPrint('Error listening to link stream: $error');
      },
    );
  }

  static bool _isTrustedLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return _trustedHosts.contains(host);
  }

  static String? _decodeSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    try {
      final decoded = Uri.decodeComponent(slug);
      if (decoded.isEmpty || _isInvalidSlug(decoded)) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static bool _isInvalidSlug(String slug) {
    if (slug.contains('/') || slug.contains('\\')) return true;
    if (slug.contains('..')) return true;
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(slug)) return true;
    return false;
  }

  static void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    if (_router == null) {
      debugPrint('Router not initialized yet');
      return;
    }

    if (!_isTrustedLink(uri)) {
      debugPrint('Untrusted host: ${uri.host}');
      return;
    }

    final segments = uri.pathSegments
        .map((s) => Uri.decodeComponent(s))
        .toList();

    if (segments.isEmpty) {
      _router!.go('/home');
      return;
    }

    final companySlug = _decodeSlug(segments.first);
    if (companySlug == null) {
      debugPrint('Invalid company slug: ${segments.first}');
      _router!.go('/home');
      return;
    }

    if (segments.length == 1) {
      _router!.go('/company/$companySlug');
      return;
    }

    if (segments.length == 3 && segments[1].toLowerCase() == 'recording') {
      final recordingId = _decodeSlug(segments[2]);
      if (recordingId != null) {
        _router!.go('/company/$companySlug/recording/$recordingId');
        return;
      }
    }

    if (segments.length == 2) {
      final streamSlug = _decodeSlug(segments[1]);
      if (streamSlug != null) {
        _router!.go('/company/$companySlug/stream/$streamSlug');
        return;
      }
    }

    if (segments.length > 3) {
      debugPrint('Unknown deep link format: ${uri.path}');
    }

    _router!.go('/home');
  }

  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
