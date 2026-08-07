import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/auth_deep_link_service.dart';

class TRYPApp extends ConsumerStatefulWidget {
  final AppVariant variant;

  const TRYPApp({super.key, required this.variant});

  @override
  ConsumerState<TRYPApp> createState() => _TRYPAppState();
}

class _TRYPAppState extends ConsumerState<TRYPApp> {
  late final DriverRouteGuard _routeGuard;
  late final GoRouter _router;
  late final AuthDeepLinkService _authDeepLinkService;

  @override
  void initState() {
    super.initState();
    _routeGuard = DriverRouteGuard(expectedRole: widget.variant.expectedRole);
    _router = buildRouter(widget.variant, routeGuard: _routeGuard);
    _authDeepLinkService = AuthDeepLinkService();
    unawaited(_authDeepLinkService.initialize());
  }

  @override
  void dispose() {
    _authDeepLinkService.dispose();
    _router.dispose();
    _routeGuard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: widget.variant.displayName,
      theme: TRYPTheme.lightTheme,
      darkTheme: TRYPTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
