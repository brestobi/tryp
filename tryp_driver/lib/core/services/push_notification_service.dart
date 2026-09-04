import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '📬 [FCM Background] ${message.notification?.title}: ${message.notification?.body}',
  );
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tryp_notifications',
    'TRYP Notifications',
    description: 'TRYP ride and account notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _initialized = false;
  String? _pendingRoute;
  void Function(String route)? _onNotificationTap;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('tryp_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _navigateFromNotification(route);
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  String _removeNotificationEmoji(String text) {
    return text
        .replaceAll('🚘', '')
        .replaceAll('🚙', '')
        .replaceAll('🚗', '')
        .replaceAll('📌', '')
        .replaceAll('🟢', '')
        .replaceAll('🔴', '')
        .replaceAll('🏁', '')
        .replaceAll('⚠️', '')
        .replaceAll('⚠', '')
        .replaceAll('🎉', '')
        .replaceAll('✅', '')
        .replaceAll('❌', '')
        .replaceAll('📸', '')
        .replaceAll('⭐', '')
        .replaceAll('🚕', '')
        .replaceAll('🚖', '')
        .trim();
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = _removeNotificationEmoji(
      message.notification?.title ?? 'TRYP',
    );
    final body = _removeNotificationEmoji(
      message.notification?.body ?? 'You have a new update',
    );

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
          color: const Color(0xFF0B5D2A),
          icon: 'tryp_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'] ?? '/notifications',
    );
  }

  /// Initialize Firebase Messaging, request permissions, and register the token.
  /// This method is safe to call more than once and can retry after failure.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _initializeInternal();
      _initialized = true;
    } catch (e) {
      _initialized = false;
      debugPrint('❌ Push notification initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _initializeInternal() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    try {
      await _initializeLocalNotifications();
    } catch (e) {
      // Local display setup must not prevent FCM token registration.
      debugPrint('⚠️ Local notification setup warning: $e');
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    debugPrint('✅ Push notification status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ Push notifications permission denied by user.');
    }

    FirebaseMessaging.onMessage.listen((message) async {
      try {
        await _showLocalNotification(message);
      } catch (e) {
        debugPrint('⚠️ Foreground notification display failed: $e');
      }
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        debugPrint(
          '🔑 Supabase session active (${event.name}), registering FCM push token...',
        );
        unawaited(_registerTokenWithSupabase());
      }
    });

    // Covers a session restored before the auth listener was attached.
    await _registerTokenWithSupabase();

    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed, updating Supabase...');
      await _saveTokenToSupabase(newToken);
    });
  }

  /// Explicitly request push notification permissions from the user.
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
    debugPrint(
      '🔔 Requested notification permission: ${settings.authorizationStatus}',
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerTokenWithSupabase();
    }
    return settings;
  }

  /// Check current notification permission status.
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get the current FCM push token.
  Future<String?> getPushToken() async {
    try {
      if (Platform.isAndroid) return await _messaging.getToken();
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⚠️ APNs token is not available yet.');
          return null;
        }
        return await _messaging.getToken();
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching push token: $e');
    }
    return null;
  }

  Future<void> _registerTokenWithSupabase() async {
    try {
      final token = await getPushToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No FCM token was returned for this device.');
        return;
      }

      debugPrint('📱 FCM Token acquired.');
      await _saveTokenToSupabase(token);
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot save FCM token — user not logged in.');
        return;
      }

      await supabase
          .from('profiles')
          .update({
            'push_token': token,
            'push_token_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      debugPrint('✅ FCM token saved to Supabase for user ${user.id}');
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Supabase: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '📩 [FCM Foreground] ${message.notification?.title}: ${message.notification?.body}',
    );
  }

  /// Attach navigation after the Flutter router has been created.
  /// Taps received during bootstrap are queued until this handler is available.
  void setNotificationTapHandler(void Function(String route) handler) {
    _onNotificationTap = handler;
    final pendingRoute = _pendingRoute;
    _pendingRoute = null;
    if (pendingRoute != null) handler(pendingRoute);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final route = data['route']?.toString();
    debugPrint('Notification tapped: route=$route');
    if (route != null) _navigateFromNotification(route);
  }

  void _navigateFromNotification(String route) {
    const allowedRoutes = {
      '/notifications',
      '/driver/home',
      '/driver/active-trip',
      '/driver/trip-history',
      '/driver/wallet',
      '/driver/documents',
      '/driver/onboarding',
    };
    if (!allowedRoutes.contains(route)) return;

    final handler = _onNotificationTap;
    if (handler == null) {
      _pendingRoute = route;
      return;
    }
    handler(route);
  }

  /// Delete the FCM token from Supabase when the user logs out.
  Future<void> removeToken() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase
            .from('profiles')
            .update({
              'push_token': null,
              'push_token_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }
      await _messaging.deleteToken();
      debugPrint('🗑️ FCM token removed from Supabase');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(),
);
