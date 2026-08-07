import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/app.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/config/environment.dart';
import 'package:tryp_driver/core/services/push_notification_service.dart';
import 'package:tryp_driver/firebase_options.dart';

void main() async {
  _runBootstrap(AppVariant.driver);
}

Future<void> _runBootstrap(AppVariant variant) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables first
    await Environment.load();

    // Global Error Widget builder to show on-screen logs when crashes occur
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'App Render Error',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      details.exceptionAsString(),
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      details.stack?.toString() ?? '',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError caught: ${details.exception}\n${details.stack}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Platform Error caught: $error\n$stack');
      return true;
    };

    try {
      // 1. Initialize Supabase
      await Supabase.initialize(
        url: Environment.supabaseUrl,
        publishableKey: Environment.supabaseAnonKey,
      );

      // 2. Initialize Firebase Messaging for push notifications
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final pushService = PushNotificationService();
        await pushService.initialize();
      } catch (e) {
        debugPrint('⚠️ Firebase/FCM initialization warning (push notifications disabled): $e');
      }

      runApp(
        ProviderScope(
          child: TRYPApp(variant: variant),
        ),
      );
    } catch (error, stack) {
      debugPrint('Initialization error: $error\n$stack');
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Initialization Error',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          'Error: $error\n\n$stack',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }, (error, stack) {
    debugPrint('Uncaught zoned error: $error\n$stack');
  });
}
