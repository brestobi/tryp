import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';

/// Passenger startup screen with a white background, red TRYP logo, and loading bar.
class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Session?> _resolveSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      final current = auth.currentSession;
      if (current != null && !current.isExpired) return current;
      try {
        await auth.onAuthStateChange
            .where((state) =>
                state.event == AuthChangeEvent.signedIn ||
                state.event == AuthChangeEvent.initialSession ||
                state.event == AuthChangeEvent.tokenRefreshed ||
                state.event == AuthChangeEvent.signedOut)
            .first
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
      final resolved = auth.currentSession;
      return resolved != null && !resolved.isExpired ? resolved : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initialize() async {
    final sessionFuture = _resolveSession();
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('Location permission error: $e');
    }
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final session = await sessionFuture;
    if (!mounted) return;
    if (session != null) {
      String? route;
      try {
        route = await googlePostAuthRoute();
      } catch (error) {
        debugPrint('Profile routing error during session restore: $error');
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go(Routes.onboarding);
        return;
      }
      if (!mounted) return;
      if (route != null) {
        context.go(route);
      } else {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go(Routes.onboarding);
      }
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Image.asset(
                  'assets/images/tryp-logo-red.png',
                  width: 170,
                  height: 170,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Loading TRYP',
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: Color(0xFFF6D9DB),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31B23)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
