import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Forwards native auth callback links to Supabase.
///
/// Supabase emits `AuthChangeEvent.passwordRecovery` after the recovery
/// callback is exchanged, which the app router uses to show the reset form.
class AuthDeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize() async {
    // Listen before resolving the initial link so a callback received while
    // the app is starting cannot be missed by the recovery flow.
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Auth deep-link stream error: $error');
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _handleUri(initialUri);
    } catch (error) {
      debugPrint('Initial auth deep-link handling failed: $error');
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != 'io.tryp.driver' || uri.host != 'auth-callback') {
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (error) {
      debugPrint('Supabase auth callback handling failed: $error');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
