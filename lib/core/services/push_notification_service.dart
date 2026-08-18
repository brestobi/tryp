import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tryp/config/environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Normalizes the Firebase Web Push public key before it reaches the
/// browser SDK, which decodes it as base64url.
String? normalizeFirebaseWebVapidKey(String rawKey) {
  var key = rawKey.trim();
  if (key.length >= 2 &&
      ((key.startsWith('"') && key.endsWith('"')) ||
          (key.startsWith("'") && key.endsWith("'")))) {
    key = key.substring(1, key.length - 1).trim();
  }

  key = key.replaceAll(RegExp(r'\s+'), '');
  if (key.isEmpty) return null;

  // Accept standard base64 input too, then pass the unpadded URL-safe form
  // expected by Firebase Messaging.
  key = key.replaceAll('+', '-').replaceAll('/', '_');
  key = key.replaceFirst(RegExp(r'=+$'), '');
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key)) return null;

  try {
    final padding = (4 - key.length % 4) % 4;
    final paddedKey = key.padRight(key.length + padding, '=');
    final decoded = base64Url.decode(paddedKey);
    // A Web Push P-256 public key is an uncompressed 65-byte point.
    if (decoded.length != 65 || decoded.first != 4) return null;
  } on FormatException {
    return null;
  }

  return key;
}

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
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

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

    await _localNotifications.initialize(initSettings);

    if (!kIsWeb && Platform.isAndroid) {
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

    final settings = kIsWeb
        ? await _messaging.getNotificationSettings()
        : await _messaging.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
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
        if (!kIsWeb) unawaited(_registerTokenWithSupabase());
      }
    });

    // Covers a session restored before the auth listener was attached. Browser
    // push waits for the explicit permission button in the notifications UI.
    if (!kIsWeb) await _registerTokenWithSupabase();

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
      if (kIsWeb) {
        final vapidKey = normalizeFirebaseWebVapidKey(
          Environment.firebaseWebVapidKey,
        );
        if (vapidKey == null) {
          debugPrint(
            '⚠️ Firebase Web VAPID key is missing or invalid. '
            'Use the public key from Firebase Console → Project settings → '
            'Cloud Messaging → Web Push certificates.',
          );
          return null;
        }
        return await _messaging.getToken(vapidKey: vapidKey);
      }
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

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('👆 Notification tapped: route=${data['route']} data=$data');
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
