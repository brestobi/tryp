import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

/// Environment configuration for TRYP
class Environment {
  static const String _defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String _defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  static const String _defaultMapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebMessagingSenderId =
      String.fromEnvironment(
        'FIREBASE_WEB_MESSAGING_SENDER_ID',
        defaultValue: '',
      );

  static const String _defaultFirebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
    defaultValue: '',
  );

  static const String _defaultFirebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue: '',
  );

  static const bool _defaultIsProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: false,
  );

  static const bool _defaultIsStaging = bool.fromEnvironment(
    'IS_STAGING',
    defaultValue: false,
  );

  static final Map<String, String> _runtimeValues = {};

  static Future<void> load({String filePath = '.env'}) async {
    try {
      String content = '';
      try {
        content = await rootBundle.loadString(filePath);
      } catch (_) {
        final file = File(filePath);
        if (file.existsSync()) {
          content = await file.readAsString();
        }
      }

      if (content.isEmpty) return;

      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final split = trimmed.split('=');
        if (split.length < 2) continue;

        final key = split.first.trim();
        var value = split.sublist(1).join('=').trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }

        _runtimeValues[key] = value;
      }
    } catch (_) {
      // Ignore failures; fall back to compile-time or OS environment values.
    }
  }

  static String _resolve(String key, String defaultValue) {
    final runtimeValue = _runtimeValues[key];
    if (runtimeValue != null) return runtimeValue;
    if (!kIsWeb) return Platform.environment[key] ?? defaultValue;
    return defaultValue;
  }

  static bool _resolveBool(String key, bool defaultValue) {
    final raw =
        _runtimeValues[key] ?? (kIsWeb ? null : Platform.environment[key]);
    if (raw == null) return defaultValue;
    return raw.toLowerCase() == 'true';
  }

  static String get supabaseUrl =>
      _resolve('SUPABASE_URL', _defaultSupabaseUrl);

  static String get supabaseAnonKey =>
      _resolve('SUPABASE_ANON_KEY', _defaultSupabaseAnonKey);

  static String get mapboxAccessToken =>
      _resolve('MAPBOX_ACCESS_TOKEN', _defaultMapboxAccessToken);

  static String get firebaseWebApiKey =>
      _resolve('FIREBASE_WEB_API_KEY', _defaultFirebaseWebApiKey);

  static String get firebaseWebAuthDomain =>
      _resolve('FIREBASE_WEB_AUTH_DOMAIN', _defaultFirebaseWebAuthDomain);

  static String get firebaseWebProjectId =>
      _resolve('FIREBASE_WEB_PROJECT_ID', _defaultFirebaseWebProjectId);

  static String get firebaseWebStorageBucket =>
      _resolve('FIREBASE_WEB_STORAGE_BUCKET', _defaultFirebaseWebStorageBucket);

  static String get firebaseWebMessagingSenderId => _resolve(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    _defaultFirebaseWebMessagingSenderId,
  );

  static String get firebaseWebAppId =>
      _resolve('FIREBASE_WEB_APP_ID', _defaultFirebaseWebAppId);

  static String get firebaseWebMeasurementId =>
      _resolve('FIREBASE_WEB_MEASUREMENT_ID', _defaultFirebaseWebMeasurementId);

  static String get firebaseWebVapidKey =>
      _resolve('FIREBASE_WEB_VAPID_KEY', _defaultFirebaseWebVapidKey);

  static bool get isProduction =>
      _resolveBool('IS_PRODUCTION', _defaultIsProduction);

  static bool get isStaging => _resolveBool('IS_STAGING', _defaultIsStaging);

  static String get paystackPublicKey => _resolve('PAYSTACK_PUBLIC_KEY', '');

  static String get paystackCallbackUrl =>
      _resolve('PAYSTACK_CALLBACK_URL', 'https://standard.paystack.co/close');
}
