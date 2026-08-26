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

  static const String _defaultSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _defaultMapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
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
        // Runtime `.env` loading is supported through Flutter assets. Release
        // builds should provide values with `--dart-define`.
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
    return _runtimeValues[key] ?? defaultValue;
  }

  static bool _resolveBool(String key, bool defaultValue) {
    final raw = _runtimeValues[key];
    if (raw == null) return defaultValue;
    return raw.toLowerCase() == 'true';
  }

  static String get supabaseUrl =>
      _resolve('SUPABASE_URL', _defaultSupabaseUrl);

  /// Supabase publishable key. `SUPABASE_ANON_KEY` remains supported for
  /// existing deployments and local `.env` files.
  static String get supabaseAnonKey {
    final publishableKey =
        _runtimeValues['SUPABASE_PUBLISHABLE_KEY'] ??
        _defaultSupabasePublishableKey;
    if (publishableKey.trim().isNotEmpty) {
      return publishableKey.trim();
    }
    return _resolve('SUPABASE_ANON_KEY', _defaultSupabaseAnonKey);
  }

  static String get mapboxAccessToken =>
      _resolve('MAPBOX_ACCESS_TOKEN', _defaultMapboxAccessToken);

  static bool get isProduction =>
      _resolveBool('IS_PRODUCTION', _defaultIsProduction);

  static bool get isStaging => _resolveBool('IS_STAGING', _defaultIsStaging);

  static String get paystackPublicKey => _resolve('PAYSTACK_PUBLIC_KEY', '');

  static String get paystackCallbackUrl =>
      _resolve('PAYSTACK_CALLBACK_URL', 'https://standard.paystack.co/close');
}
