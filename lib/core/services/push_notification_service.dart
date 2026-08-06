import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tryp_notifications',
    'TRYP Notifications',
    description: 'TRYP ride and account notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'TRYP';
    final body = message.notification?.body ?? 'You have a new update';

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'] ?? '/home',
    );
  }

  /// Initialize Firebase Messaging, request permissions, and register token
  Future<void> initialize() async {
    await _initializeLocalNotifications();

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
    FirebaseMessaging.onMessage.listen((message) async {
      await _showLocalNotification(message);
      _handleForegroundMessage(message);
    });

    // Handle notification tap when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen for Supabase Auth state changes to automatically register FCM token on sign-in
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('🔑 Supabase session active (${data.event.name}), registering FCM push token...');
        _registerTokenWithSupabase();
      }
    });

    // Register the FCM token with Supabase if user is already logged in
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
        debugPrint('📱 FCM Token acquired: $token');
        await _saveTokenToSupabase(token);
      } else {
        debugPrint('⚠️ No FCM token was returned for this device.');
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
