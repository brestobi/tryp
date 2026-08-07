import 'package:flutter/foundation.dart';

/// Simple in-app welcome notification helper for test builds.
/// This produces a message that can be surfaced in a SnackBar or toast after sign-in.
class WelcomeNotificationService {
  static const String welcomeTitle = 'Welcome to TRYP';
  static const String welcomeBody =
      'Your TRYP account is ready. We are happy to have you onboard.';

  static void showWelcomeNotification({
    required void Function(String title, String body) callback,
  }) {
    try {
      callback(welcomeTitle, welcomeBody);
    } catch (e) {
      debugPrint('Welcome notification callback failed: $e');
    }
  }
}
