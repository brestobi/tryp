import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler — MUST be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 [FCM Background] ${message.notification?.title}: ${message.notification?.body}');
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize Firebase Messaging, request permissions, and register token
  Future<void> initialize() async {
    // Request notification permissions (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ Push notifications permission denied by user.');
      return;
    }

    debugPrint('✅ Push notification status: ${settings.authorizationStatus}');

    // Set up background handler (must be top-level)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Register the FCM token with Supabase
    await _registerTokenWithSupabase();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed, updating Supabase...');
      await _saveTokenToSupabase(newToken);
    });
  }

  /// Explicitly request push notification permissions from user
  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('🔔 Requested notification permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerTokenWithSupabase();
    }
    return settings;
  }

  /// Check current notification permission status
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get current FCM Push Token
  Future<String?> getPushToken() async {
    try {
      if (Platform.isAndroid) {
        return await _messaging.getToken();
      } else if (Platform.isIOS) {
        await _messaging.getAPNSToken();
        return await _messaging.getToken();
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching push token: $e');
    }
    return null;
  }

  /// Get the current FCM token and save it to Supabase profiles table
  Future<void> _registerTokenWithSupabase() async {
    try {
      String? token;
      if (Platform.isAndroid) {
        token = await _messaging.getToken();
      } else if (Platform.isIOS) {
        // For iOS, get APNs token first
        await _messaging.getAPNSToken();
        token = await _messaging.getToken();
      }

      if (token != null) {
        debugPrint('📱 FCM Token: ${token.substring(0, 20)}...');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  /// Saves FCM token to the `profiles` table in Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot save FCM token — user not logged in.');
        return;
      }

      await supabase.from('profiles').upsert({
        'id': user.id,
        'push_token': token,
        'push_token_updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM token saved to Supabase for user ${user.id}');
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Supabase: $e');
    }
  }

  /// Handle messages when app is in the foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 [FCM Foreground] ${message.notification?.title}: ${message.notification?.body}');
    // In-app notifications are shown via the NotificationService (Riverpod)
    // The notification bell badge will be incremented automatically
    // Additional in-app snackbar/dialog handling can go here
  }

  /// Handle when user taps a notification
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final route = data['route'] as String?;
    debugPrint('👆 Notification tapped: route=$route data=$data');
    // Navigation is handled by the app's router based on `route` data
    // You can use a global navigation key to push routes here
  }

  /// Delete the FCM token from Supabase when user logs out
  Future<void> removeToken() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({
          'push_token': null,
          'push_token_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
      await _messaging.deleteToken();
      debugPrint('🗑️ FCM token removed from Supabase');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
