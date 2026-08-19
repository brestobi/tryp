import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/platform/device_support.dart';

class TRYPApp extends ConsumerStatefulWidget {
  /// Tests can omit the guard because they mount the widget before Supabase
  /// initialization. Production passes the initialized Supabase-backed guard.
  final PassengerRouteGuard? routeGuard;

  const TRYPApp({super.key, this.routeGuard});

  @override
  ConsumerState<TRYPApp> createState() => _TRYPAppState();
}

class _TRYPAppState extends ConsumerState<TRYPApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(routeGuard: widget.routeGuard);
  }

  @override
  void dispose() {
    _router.dispose();
    widget.routeGuard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && !isMobileWebDevice) {
      return const UnsupportedDesktopApp();
    }

    return MaterialApp.router(
      title: 'TRYP',
      theme: TRYPTheme.lightTheme,
      darkTheme: TRYPTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class UnsupportedDesktopApp extends StatelessWidget {
  const UnsupportedDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRYP',
      theme: TRYPTheme.lightTheme,
      darkTheme: TRYPTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const UnsupportedDesktopScreen(),
    );
  }
}

class UnsupportedDesktopScreen extends StatelessWidget {
  const UnsupportedDesktopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_android_rounded,
                    color: Color(0xFFE31B23),
                    size: 72,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mobile device required',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The TRYP passenger app is currently available on mobile devices only. Please open it on your phone or tablet to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
