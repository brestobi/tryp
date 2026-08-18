import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

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
